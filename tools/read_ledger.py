#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""读取核桃台账 xlsx，输出结构概览（不修改源文件）。"""
import openpyxl

P = r'H:\Desktop\核桃记录台账-汇总\核桃记录台账-汇总.xlsx'
wb = openpyxl.load_workbook(P, data_only=True)
print('工作表：', wb.sheetnames)

for ws in wb.worksheets:
    print('\n' + '=' * 60)
    print('表：%s  尺寸=%s' % (ws.title, ws.dimensions))
    print('最大行=%d 最大列=%d' % (ws.max_row, ws.max_column))
    rows = list(ws.iter_rows(min_row=1, max_row=min(ws.max_row, 8), values_only=True))
    for i, r in enumerate(rows, 1):
        cells = ['' if c is None else str(c) for c in r]
        # 只打印非空
        print('  第%d行: %s' % (i, ' | '.join(cells)[:300]))
