#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
打包「上传到 GitHub」专用压缩包。
只放云端编译真正需要的东西，剔除本机专属文件（.dart_tool / build / android / .metadata）。
用法: python tools/pack_upload.py
输出: H:\Desktop\壹ZHANG核\V1\壹ZHANG核-上传GitHub.zip
"""
import os
import zipfile
import time

SRC = r'H:\Desktop\壹ZHANG核\V1\代码'
DST = r'H:\Desktop\壹ZHANG核\V1\壹ZHANG核-上传GitHub.zip'

# 需要打包的目录（相对 SRC）
DIRS = ['lib', 'assets', '.github']
# 需要打包的单文件
FILES = ['pubspec.yaml', 'analysis_options.yaml']
# 目录内排除的后缀/文件名
EXCLUDE_EXT = {'.log', '.tmp'}
EXCLUDE_NAME = {'.DS_Store'}

stamp = time.strftime('%Y-%m-%d %H:%M')
n = 0
with zipfile.ZipFile(DST, 'w', zipfile.ZIP_DEFLATED) as z:
    for d in DIRS:
        base = os.path.join(SRC, d)
        for dp, _, fs in os.walk(base):
            for f in fs:
                if f in EXCLUDE_NAME or os.path.splitext(f)[1] in EXCLUDE_EXT:
                    continue
                p = os.path.join(dp, f)
                rel = os.path.relpath(p, SRC)
                z.write(p, rel.replace('\\', '/'))
                n += 1
    for f in FILES:
        p = os.path.join(SRC, f)
        if os.path.exists(p):
            z.write(p, f)
            n += 1
    # 版本号戳记，便于壹确认是不是最新包
    z.writestr('_打包时间.txt', '打包时间：%s\n共 %d 个文件\n' % (stamp, n))

print('已生成：%s' % DST)
print('文件数：%d' % n)
print('大小：%.1f KB' % (os.path.getsize(DST) / 1024))
print('\n包含清单（顶层）：')
for d in DIRS:
    print('  %s/' % d)
for f in FILES:
    print('  %s' % f)
