#!/usr/bin/env python3
"""校验构建产出的 MovieClaw Flutter APK 并生成伴随下载元数据 (.json)。

参考 MovieClaw 主仓 apps/android/scripts/build-release-metadata.py 设计：
- 通过 aapt2 校验 applicationId、非 debuggable、versionName/versionCode、minSdkVersion；
- 通过 zipfile 校验产物 ABI 与关键原生库（libflutter.so / libmpv.so）；
- 通过 apksigner 校验 APK 签名完整性并提取证书 SHA-256 指纹；
- 输出同名 .json 元数据供发布清单与校验使用。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path


def describe(
    apk: Path,
    aapt2: str,
    apksigner: str,
    *,
    expected_app_id: str = "io.movieclaw.mc_flutter",
    require_release_cert: bool = False,
) -> dict:
    badging = subprocess.check_output(
        [aapt2, "dump", "badging", str(apk)],
        text=True,
    )
    package_match = re.search(r"^package: (.+)$", badging, re.MULTILINE)
    if not package_match:
        raise ValueError(f"无法读取 APK 包信息: {apk.name}")

    fields = dict(re.findall(r"(\w+)='([^']*)'", package_match[1]))
    app_id = fields.get("name", "")
    if app_id != expected_app_id:
        raise ValueError(f"applicationId 不匹配：期望 {expected_app_id}，实际 {app_id}")
    if "application-debuggable" in badging:
        raise ValueError(f"APK 带有 application-debuggable 标记，禁止作为 Release 产物: {apk.name}")

    version_name = fields.get("versionName", "")
    version_code = fields.get("versionCode", "")
    if not version_name:
        raise ValueError("APK 缺少 versionName")
    if not version_code.isdigit() or not (1 <= int(version_code) <= 2100000000):
        raise ValueError(f"APK versionCode 非法: {version_code}")

    sdk_match = re.search(r"^(?:minSdkVersion|sdkVersion):'(\d+)'", badging, re.MULTILINE)
    if sdk_match is None:
        raise ValueError("APK 缺少 minSdkVersion")

    with zipfile.ZipFile(apk) as archive:
        so_entries = [n for n in archive.namelist() if n.startswith("lib/") and n.endswith(".so")]
    abis = sorted({n.split("/")[1] for n in so_entries if len(n.split("/")) >= 3})
    if not abis:
        raise ValueError(f"APK 缺少原生库 (lib/<abi>/*.so): {apk.name}")

    so_names = {Path(n).name for n in so_entries}
    for req in ("libflutter.so", "libmpv.so"):
        if req not in so_names:
            raise ValueError(
                f"APK 缺少核心原生库 {req}: {apk.name}（实际包含: {sorted(so_names)}）"
            )

    signature = subprocess.check_output(
        [apksigner, "verify", "--verbose", "--print-certs", str(apk)],
        text=True,
    )
    cert_match = re.search(
        r"(?:Signer #1|V[234] Signer):? certificate SHA-256 digest: ([0-9a-fA-F]{64})",
        signature,
    )
    if cert_match is None:
        raise ValueError(f"无法解析 APK 签名证书指纹: {apk.name}")

    is_debug_cert = "CN=Android Debug" in signature
    if require_release_cert and is_debug_cert:
        raise ValueError(f"启用了严格正式签名校验，但 APK 使用的是 Android Debug 证书: {apk.name}")

    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()

    return {
        "product": "android-flutter",
        "applicationId": app_id,
        "version": version_name,
        "build": version_code,
        "abis": abis,
        "minimumSdk": int(sdk_match[1]),
        "asset": apk.name,
        "size": apk.stat().st_size,
        "sha256": digest,
        "signedRelease": not is_debug_cert,
        "certificateSha256": cert_match[1].lower(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apks", nargs="+", type=Path, help="要校验的 APK 路径")
    parser.add_argument("--aapt2", required=True)
    parser.add_argument("--apksigner", required=True)
    parser.add_argument("--require-release-cert", action="store_true")
    args = parser.parse_args()

    for apk in args.apks:
        if not apk.is_file():
            print(f"::error::APK 文件不存在: {apk}", file=sys.stderr)
            return 1
        meta = describe(
            apk,
            args.aapt2,
            args.apksigner,
            require_release_cert=args.require_release_cert,
        )
        apk.with_suffix(".json").write_text(
            json.dumps(meta, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        sign_label = "正式签名" if meta["signedRelease"] else "Debug 兜底签名"
        size_mb = meta["size"] / (1024 * 1024)
        print(
            f"✓ {apk.name} | v{meta['version']} ({meta['build']}) | "
            f"ABI={','.join(meta['abis'])} | {size_mb:.1f} MB | {sign_label} | "
            f"sha256={meta['sha256'][:12]}…"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
