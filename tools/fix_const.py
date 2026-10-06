#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
去 const 脚本
Tokens 的颜色/阴影/字体已改为运行时可变(static 非 const)，
所有 `const Xxx( ... Tokens.bg ... )` 表达式都会编译失败。
本脚本按括号配对定位每个 `const Ident(` 的作用域，
若作用域内引用了 Tokens 的可变成员，则删除该处 `const ` 关键字。
用法:  python tools/fix_const.py [--apply]
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'lib')

# Tokens 中「运行时可变」的成员（出现在 const 表达式里即非法）
MUTABLE = {
    'bg', 'text', 'muted', 'faint', 'accent', 'accentSoft',
    'ph1', 'ph2', 'textD10', 'mutedD10', 'goodD10', 'badD10', 'accentD10',
    'seal', 'sky', 'gold', 'lightShadow', 'darkShadow',
    'fontCn', 'out', 'outSm', 'inShadow', 'inSm',
}

# 匹配 `const ` 后紧跟标识符 + `(` 或 `[`
CONST_RE = re.compile(r'\bconst\s+(?=[A-Za-z_][A-Za-z0-9_]*\s*[\(\[])')
TOK_RE = re.compile(r'\bTokens\.([A-Za-z0-9_]+)')


def find_scope(s, i):
    """i 指向 '(' 或 '['，返回匹配的 ')' 或 ']' 下标；不配对返回 -1"""
    open_ch = s[i]
    close_ch = ')' if open_ch == '(' else ']'
    depth = 0
    n = len(s)
    while i < n:
        c = s[i]
        if c in "'\"":
            # 跳过字符串字面量
            q = c
            i += 1
            while i < n:
                if s[i] == '\\':
                    i += 2
                    continue
                if s[i] == q:
                    break
                i += 1
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def strip_comments_composite(s):
    """把 // 行注释 和 /* */ 块注释替换为等长空格，避免误判"""
    out = list(s)
    i, n = 0, len(s)
    while i < n:
        if s.startswith('//', i):
            j = s.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
        elif s.startswith('/*', i):
            j = s.find('*/', i)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
        else:
            i += 1
    return ''.join(out)


def process(path, apply=False):
    src = open(path, 'r', encoding='utf-8').read()
    clean = strip_comments_composite(src)
    hits = []
    pos = 0
    while True:
        m = CONST_RE.search(clean, pos)
        if not m:
            break
        # 找到 '(' 或 '['
        j = m.end()
        while j < len(clean) and clean[j].isspace() is False and clean[j] not in '([':
            j += 1
        while j < len(clean) and clean[j].isspace():
            j += 1
        if j >= len(clean) or clean[j] not in '([':
            pos = m.end()
            continue
        # 跳过标识符与泛型
        end = find_scope(clean, j)
        if end < 0:
            pos = m.end()
            continue
        seg = clean[m.start():end + 1]
        used = set(TOK_RE.findall(seg))
        bad = used & MUTABLE
        if bad:
            hits.append((m.start(), m.end(), sorted(bad)))
        pos = m.end()

    if not hits:
        return 0

    # 从后往前替换，避免下标偏移
    new = src
    for (a, b, bad) in reversed(hits):
        new = new[:a] + new[b:]
    if apply:
        open(path, 'w', encoding='utf-8', newline='').write(new)
    return len(hits)


def main():
    apply = '--apply' in sys.argv
    total = 0
    for dirpath, _, files in os.walk(os.path.abspath(ROOT)):
        for f in files:
            if not f.endswith('.dart'):
                continue
            p = os.path.join(dirpath, f)
            n = process(p, apply)
            if n:
                rel = os.path.relpath(p, os.path.abspath(ROOT))
                print(f'{"FIXED" if apply else "TODO "}  {n:3d}  {rel}')
                total += n
    print(f'\n合计 {total} 处' + ('（已写入）' if apply else '（预演，加 --apply 生效）'))


if __name__ == '__main__':
    main()
