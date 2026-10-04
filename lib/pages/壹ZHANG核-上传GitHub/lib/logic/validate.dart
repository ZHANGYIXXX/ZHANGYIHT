// 品相校验（仅核桃）
// 拍板结论：仅「全品」与「有修」互斥（全品 = 无修）；
// 「有黄」独立，可与全品或有修任意共存（全品可能有黄、有修也可能有黄）
class Validate {
  // 修正品相：全品与有修冲突时，以全品为准清掉有修
  static ({bool full, bool repaired}) coerce(bool full, bool repaired) {
    if (full && repaired) {
      return (full: true, repaired: false);
    }
    return (full: full, repaired: repaired);
  }
}
