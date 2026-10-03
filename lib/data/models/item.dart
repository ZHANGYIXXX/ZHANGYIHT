// 4 类其他统一 model（手串/吊坠/手把件/摆件，用 type 区分）
class Item {
  final int? id;
  final String type; // 手串/吊坠/手把件/摆件
  final String code;
  final String category; // 材质（品类）
  final String variety; // 品种
  final double sizeMm;
  final String strandType; // 串型，仅手串有值
  final double weight;
  final String buyDate; // YYYY-MM-DD
  final String channel;
  final String merchant;
  final double price;
  final String coverPath;
  final String remark;

  Item({
    this.id,
    required this.type,
    required this.code,
    required this.category,
    required this.variety,
    this.sizeMm = 0,
    this.strandType = '',
    this.weight = 0,
    required this.buyDate,
    this.channel = '',
    this.merchant = '',
    this.price = 0,
    this.coverPath = '',
    this.remark = '',
  });

  factory Item.fromMap(Map<String, dynamic> m) => Item(
        id: m['id'] as int?,
        type: m['type'] as String,
        code: m['code'] as String,
        category: m['category'] as String,
        variety: m['variety'] as String,
        sizeMm: (m['size_mm'] as num).toDouble(),
        strandType: m['strand_type'] as String,
        weight: (m['weight'] as num).toDouble(),
        buyDate: m['buy_date'] as String,
        channel: m['channel'] as String,
        merchant: m['merchant'] as String,
        price: (m['price'] as num).toDouble(),
        coverPath: m['cover_path'] as String,
        remark: m['remark'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type,
        'code': code,
        'category': category,
        'variety': variety,
        'size_mm': sizeMm,
        'strand_type': strandType,
        'weight': weight,
        'buy_date': buyDate,
        'channel': channel,
        'merchant': merchant,
        'price': price,
        'cover_path': coverPath,
        'remark': remark,
      };
}
