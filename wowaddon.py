#!/usr/bin/env python3
"""Package and install the current WoW addon checkout."""

from __future__ import annotations

import argparse
import re
import shutil
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath


VERSION_PATTERN = re.compile(r'^\s*local\s+version\s*=\s*"([^"]+)"\s*(?:--.*)?$')
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


class PackageError(RuntimeError):
    """Raised for user-facing packaging failures."""


def repo_root() -> Path:
    return Path(__file__).resolve().parent


def addon_name(root: Path) -> str:
    return root.name


def read_version(root: Path) -> str:
    core_path = root / "src" / "Core.lua"
    if not core_path.is_file():
        raise PackageError("Cannot read version: src/Core.lua is missing.")

    for line in core_path.read_text(encoding="utf-8").splitlines():
        match = VERSION_PATTERN.match(line)
        if match:
            version = match.group(1).strip()
            if not version:
                raise PackageError("Cannot read version: src/Core.lua has an empty version string.")
            if re.search(r'[<>:"/\\|?*\x00-\x1f]', version):
                raise PackageError(f"Cannot use version in filename: {version!r}.")
            return version

    raise PackageError('Cannot read version: expected a line like local version = "2026.6.0" in src/Core.lua.')


def validate_inputs(root: Path) -> list[Path]:
    missing = []
    for directory in ("src", "lib"):
        if not (root / directory).is_dir():
            missing.append(directory + "/")

    toc_files = sorted(root.glob("*.toc"))
    if not toc_files:
        missing.append("*.toc")

    if missing:
        raise PackageError("Missing required package input: " + ", ".join(missing) + ".")

    return toc_files


def package_items(root: Path) -> list[Path]:
    toc_files = validate_inputs(root)
    return [root / "src", root / "lib", *toc_files]


def make_writable_and_retry(function, path: str, exc_info) -> None:
    target = Path(path)
    target.chmod(stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
    function(path)


def remove_tree(path: Path) -> None:
    shutil.rmtree(path, onerror=make_writable_and_retry)


def copy_file(source: Path | str, destination: Path | str) -> str:
    destination_path = Path(destination)
    shutil.copyfile(source, destination_path)
    destination_path.chmod(stat.S_IREAD | stat.S_IWRITE)
    return str(destination_path)


def copy_package(root: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)

    for item in package_items(root):
        target = destination / item.name
        if item.is_dir():
            shutil.copytree(item, target, copy_function=copy_file)
        else:
            copy_file(item, target)


def install(args: argparse.Namespace) -> int:
    root = repo_root()
    dst = Path(args.dst).expanduser().resolve()
    if not dst.is_dir():
        raise PackageError(f"Install destination does not exist or is not a directory: {dst}")

    target = dst / addon_name(root)
    resolved_target_parent = target.parent.resolve()
    if resolved_target_parent != dst:
        raise PackageError(f"Refusing to install outside destination directory: {target}")

    validate_inputs(root)

    try:
        if target.exists():
            remove_tree(target)
        copy_package(root, target)
    except OSError as error:
        raise PackageError(f"Install failed: {error}") from error

    print(f"Installed {addon_name(root)} to {target}")
    return 0


def iter_package_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for item in package_items(root):
        if item.is_dir():
            files.extend(path for path in item.rglob("*") if path.is_file())
        else:
            files.append(item)

    return sorted(files, key=lambda path: path.relative_to(root).as_posix().lower())


def write_zip_entry(zip_file: zipfile.ZipFile, source: Path, archive_path: PurePosixPath) -> None:
    zip_info = zipfile.ZipInfo(str(archive_path), ZIP_TIMESTAMP)
    zip_info.compress_type = zipfile.ZIP_DEFLATED
    zip_info.external_attr = 0o644 << 16
    zip_file.writestr(zip_info, source.read_bytes())


def zip_release(args: argparse.Namespace) -> int:
    root = repo_root()
    name = addon_name(root)
    version = read_version(root)
    validate_inputs(root)

    out_dir = Path(args.out).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    zip_path = out_dir / f"{name}-{version}.zip"
    try:
        with zipfile.ZipFile(zip_path, "w") as zip_file:
            for source in iter_package_files(root):
                relative_path = source.relative_to(root)
                archive_path = PurePosixPath(name) / PurePosixPath(relative_path.as_posix())
                write_zip_entry(zip_file, source, archive_path)
    except OSError as error:
        raise PackageError(f"Zip failed: {error}") from error

    print(f"Created {zip_path}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Install or zip this WoW addon.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_parser = subparsers.add_parser("install", help="copy addon runtime files to a WoW AddOns directory")
    install_parser.add_argument("--dst", required=True, help="WoW Interface\\AddOns directory")
    install_parser.set_defaults(func=install)

    zip_parser = subparsers.add_parser("zip", help="create a release zip")
    zip_parser.add_argument("--out", default="dist", help="output directory for the zip file")
    zip_parser.set_defaults(func=zip_release)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        return args.func(args)
    except PackageError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
