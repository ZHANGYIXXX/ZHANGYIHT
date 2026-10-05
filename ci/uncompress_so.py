#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
强制 APK 内所有 lib/**/*.so 以「不压缩(STORE)」方式重新打包。

背景：
  AGP 9.0 会无视 useLegacyPackaging，把所有原生库按 DEFLATE 压缩进 APK。
  华为 / HarmonyOS 的 linker 经常无法直接加载「压缩」的 .so，导致打开 App 即闪退
  （进程直接死亡、无红屏）。把 .so 改成 STORE（不压缩）后，linker 可直接 mmap 加载，
  规避该问题；对其它机型无副作用（不压缩本来就是旧 Android 的通用默认行为）。

用法：
  python uncompress_so.py <input.apk> [output.apk]
  若省略 output.apk，则原地重写 input.apk（先写临时文件再替换，保证原子性）。
"""
import sys
import os
import zipfile


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: uncompress_so.py <input.apk> [output.apk]", file=sys.stderr)
        return 2

    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src + ".tmp"

    if not os.path.isfile(src):
        print(f"error: input not found: {src}", file=sys.stderr)
        return 1

    with zipfile.ZipFile(src, "r") as zin:
        infos = zin.infolist()
        # APK 体量小（几十 MB），一次性读入内存足够
        blobs = {i.filename: zin.read(i) for i in infos}

    so_count = 0
    with zipfile.ZipFile(dst, "w", compression=zipfile.ZIP_DEFLATED) as zout:
        for info in infos:
            out = zipfile.ZipInfo(info.filename)
            out.date_time = info.date_time
            out.external_attr = info.external_attr
            out.internal_attr = info.internal_attr
            out.create_system = info.create_system
            out.compress_type = (
                zipfile.ZIP_STORED if info.filename.endswith(".so") else info.compress_type
            )
            if info.filename.endswith(".so"):
                so_count += 1
            zout.writestr(out, blobs[info.filename])

    if dst != src:
        os.replace(dst, src)

    print(f"re-packed {len(infos)} entries; forced STORE(uncompressed) on {so_count} .so entries")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
