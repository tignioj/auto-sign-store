#!/usr/bin/env python3
"""Generate an AltStore / SideStore source from the exact release IPA."""

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import plistlib
import re
import zipfile


def version_key(version):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError(f"Expected a stable X.Y.Z version, got {version!r}")
    return tuple(int(part) for part in version.split("."))


def generate_source(ipa, repository, tag, date, notes="", previous=None):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must be owner/name")
    published = datetime.fromisoformat(date.replace("Z", "+00:00"))
    if published.tzinfo is None:
        raise ValueError("Release date must include a timezone")
    with zipfile.ZipFile(ipa) as archive:
        if archive.testzip() is not None:
            raise ValueError("IPA is corrupt")
        names = archive.namelist()
        plists = [name for name in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(plists) != 1:
            raise ValueError("IPA must contain exactly one Payload/*.app/Info.plist")
        if any(name.endswith("/embedded.mobileprovision") for name in names):
            raise ValueError("Release IPA must not contain a private provisioning profile")
        info = plistlib.loads(archive.read(plists[0]))
        executable = info.get("CFBundleExecutable", "")
        if not executable or str(Path(plists[0]).parent / executable) not in names:
            raise ValueError("IPA is missing its application executable")
    if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
        raise ValueError("IPA must be an iOS device build, not a simulator build")
    if info.get("AutoSignStoreClient") is not True:
        raise ValueError("IPA is not an AutoSign Store client")
    for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion"):
        if not isinstance(info.get(key), str) or not info[key].strip() or "$" in info[key]:
            raise ValueError(f"IPA is missing a resolved {key}")
    version = info["CFBundleShortVersionString"]
    version_key(version)
    if tag != f"v{version}":
        raise ValueError(f"Tag {tag!r} does not match IPA version v{version}")
    if not info["CFBundleVersion"].isdigit():
        raise ValueError("Build version must be an integer")

    versions = []
    if previous is not None:
        apps = previous["apps"]
        if len(apps) != 1 or apps[0]["bundleIdentifier"] != info["CFBundleIdentifier"]:
            raise ValueError("Previous source has a different app or Bundle ID")
        versions = [item for item in apps[0]["versions"] if item["version"] != version]
    versions.append({
        "version": version,
        "buildVersion": info["CFBundleVersion"],
        "date": published.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "localizedDescription": notes.strip() or f"AutoSign Store {version}",
        "downloadURL": f"https://github.com/{repository}/releases/download/{tag}/{ipa.name}",
        "size": ipa.stat().st_size,
        "minOSVersion": info["MinimumOSVersion"],
    })
    # AltStore and AutoSign treat the first entry as latest. An older tag finishing
    # later, or an old workflow rerun, must never downgrade that entry.
    versions.sort(key=lambda item: (version_key(item["version"]), int(item["buildVersion"])), reverse=True)
    icon_url = f"https://raw.githubusercontent.com/{repository}/source/icon.png"
    return {
        "name": "AutoSign Store",
        "subtitle": "通过 AutoSign Mac 安装和刷新应用",
        "iconURL": icon_url,
        "website": f"https://github.com/{repository}",
        "tintColor": "#147061",
        "featuredApps": [info["CFBundleIdentifier"]],
        "apps": [{
            "name": info.get("CFBundleDisplayName", "AutoSign Store"),
            "bundleIdentifier": info["CFBundleIdentifier"],
            "developerName": repository.split("/")[0],
            "localizedDescription": "原生 iPhone / iPad 客户端，连接同一 Wi-Fi 中的 AutoSign Mac，查看应用签名到期时间，逐个或批量续签，包括 Store 自身。需要 Mac 运行 AutoSign。",
            "iconURL": icon_url,
            "tintColor": "#147061",
            "category": "utilities",
            "appPermissions": {
                "entitlements": [],
                "privacy": {key: value for key, value in info.items() if key.startswith("NS") and key.endswith("UsageDescription")},
            },
            "versions": versions,
        }],
        "news": [],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ipa", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--date", default=datetime.now(timezone.utc).isoformat())
    parser.add_argument("--notes-file", type=Path)
    parser.add_argument("--previous-source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    previous = json.loads(args.previous_source.read_text()) if args.previous_source else None
    notes = args.notes_file.read_text() if args.notes_file else ""
    catalog = generate_source(args.ipa, args.repository, args.tag, args.date, notes, previous)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix(".json.tmp")
    temporary.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    temporary.replace(args.output)
    print(f"Generated {args.output}")


if __name__ == "__main__":
    main()
