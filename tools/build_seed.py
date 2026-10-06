#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从「核桃记录台账-汇总.xlsx」的「汇总数据」表提取核桃档案，
生成 App 预置种子数据 assets/seed/walnuts.json（只读源表，不修改）。

列映射（照源表表头）：
A序号 B编号 C品种 D左边宽 E左肚宽 F左桩高 G右边宽 H右肚宽 I右桩高
J重量 K入手价格 L入手渠道(实为商家) M入手日期 N品相 O类型(有黄) P备注(实为入手平台)
"""
import json
import os
import re
import openpyxl

SRC = r'H:\Desktop\核桃记录台账-汇总\核桃记录台账-汇总.xlsx'
DST = r'H:\Desktop\壹ZHANG核\V1\代码\assets\seed\walnuts.json'

# App 内置的大品类→品种（与 lib/data/models/enums.dart 保持一致）
WALNUT_VARIETIES = {
    '狮子头': ['四座楼', '南疆石', '白狮子头', '红狮子头', '苹果园', '磨盘', '满天星',
             '盘龙纹', '水龙纹', '矮密', '宫灯', '元宝', '蛤蟆头', '平谷方块', '大粗筋',
             '老款闷尖', '平顶'],
    '虎头': ['麦穗虎头', '堂上虎头', '狮虎兽'],
    '官帽': ['王勇官帽', '麒麟纹官帽', '扁肚官帽'],
    '公子帽': ['崔凯公子帽', '蓟县公子帽', '杨家坪公子帽', '老款公子帽'],
    '鸡心': ['普通鸡心', '桃心鸡心', '矮桩鸡心'],
    '秋子': ['普通秋子', '灯笼秋子', '白菜秋子', '瓜条秋子'],
    '铁核桃': ['老铁核桃', '元宝铁核桃', '疙瘩铁核桃'],
    '异形核桃': ['三棱', '四棱', '鹰嘴', '葫芦', '花生', '连体', '半壁', '眼镜蛇'],
}
# 品种名 → 大品类（反查，仅当台账品种名与内置列表完全一致时才归位，不臆造）
V2C = {v: c for c, vs in WALNUT_VARIETIES.items() for v in vs}

# App 内置入手平台（lib/data/models/enums.dart channels）
CHANNELS = ['抖音', '现场', '微信', '咸鱼', '代购', '其他']


def norm_date(s):
    """2025年12月28日 / 2025-12-28 → 2025-12-28"""
    if s is None:
        return ''
    t = str(s).strip()
    m = re.match(r'^(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})', t)
    if m:
        return '%s-%02d-%02d' % (m.group(1), int(m.group(2)), int(m.group(3)))
    return t


def num(v):
    if v is None or v == '':
        return 0.0
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def main():
    wb = openpyxl.load_workbook(SRC, data_only=True)
    ws = wb['汇总数据']
    rows = list(ws.iter_rows(min_row=4, values_only=True))

    out = []
    skipped = []
    for i, r in enumerate(rows, start=4):
        name = (r[2] or '').strip() if len(r) > 2 else ''
        if not name:
            continue
        # 归位规则（保守，绝不猜）：
        # 1) 台账品种名与内置品种「完全一致」→ 归入对应大品类
        # 2) 去掉括号修饰后完全一致（如「南疆石（三角）」→「南疆石」）→ 归位
        # 两条都不中 → 留空，等壹在 App 里自己补选
        base = re.sub(r'[（(].*?[)）]', '', name).strip()
        if name in V2C:
            category, variety = V2C[name], name
        elif base and base in V2C:
            category, variety = V2C[base], base
        else:
            category, variety = '', ''

        channel_raw = (r[15] or '').strip() if len(r) > 15 else ''  # P 备注列
        channel = channel_raw if channel_raw in CHANNELS else (
            '其他' if channel_raw else '')

        out.append({
            'name': name,
            'category': category,
            'variety': variety,
            'lBian': num(r[3]), 'lDu': num(r[4]), 'lGao': num(r[5]),
            'rBian': num(r[6]), 'rDu': num(r[7]), 'rGao': num(r[8]),
            'weight': num(r[9]),
            'price': num(r[10]),
            'merchant': (r[11] or '').strip() if len(r) > 11 else '',
            'buyDate': norm_date(r[12]),
            'full': '全品' in str(r[13] or ''),
            'repaired': '有修' in str(r[13] or ''),
            'yellow': '有黄' in str(r[14] or ''),
            'channel': channel,
        })

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    with open(DST, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)

    print('共导出 %d 条 -> %s' % (len(out), DST))
    print('\n前 8 条预览：')
    for w in out[:8]:
        print('  %-14s 品类=%-6s 左%.1f/%.1f/%.1f 右%.1f/%.1f/%.1f 重%.1f 价%.0f 商家=%s 平台=%s 日期=%s 品相=%s%s' % (
            w['name'], w['category'] or '（待定）',
            w['lBian'], w['lDu'], w['lGao'], w['rBian'], w['rDu'], w['rGao'],
            w['weight'], w['price'], w['merchant'], w['channel'], w['buyDate'],
            '全品' if w['full'] else ('有修' if w['repaired'] else '-'),
            ' 有黄' if w['yellow'] else ''))
    no_cat = [w['name'] for w in out if not w['category']]
    print('\n未能自动归到大品类的（需壹在 App 里补选，共 %d 条）：' % len(no_cat))
    print('  ' + '、'.join(no_cat))


if __name__ == '__main__':
    main()
