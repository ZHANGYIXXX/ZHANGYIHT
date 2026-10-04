// 核桃主表 model
class Walnut {
  final int? id;
  final String code;
  final String name;
  final String category; // 大品类
  final String variety; // 具体品种
  final double price;
  final double lBian;
  final double lDu;
  final double lGao;
  final double rBian;
  final double rDu;
  final double rGao;
  final double weight;
  final String buyDate; // YYYY-MM-DD
  final String channel;
  final String merchant;
  final bool full;
  final bool repaired;
  final bool yellow;
  final String remark;
  final String coverPath;

  Walnut({
    this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.variety,
    this.price = 0,
    this.lBian = 0,
    this.lDu = 0,
    this.lGao = 0,
    this.rBian = 0,
    this.rDu = 0,
    this.rGao = 0,
    this.weight = 0,
    required this.buyDate,
    this.channel = '',
    this.merchant = '',
    this.full = false,
    this.repaired = false,
    this.yellow = false,
    this.remark = '',
    this.coverPath = '',
  });

  factory Walnut.fromMap(Map<String, dynamic> m) => Walnut(
        id: m['id'] as int?,
        code: m['code'] as String,
        name: m['name'] as String,
        category: m['category'] as String,
        variety: m['variety'] as String,
        price: (m['price'] as num).toDouble(),
        lBian: (m['l_bian'] as num).toDouble(),
        lDu: (m['l_du'] as num).toDouble(),
        lGao: (m['l_gao'] as num).toDouble(),
        rBian: (m['r_bian'] as num).toDouble(),
        rDu: (m['r_du'] as num).toDouble(),
        rGao: (m['r_gao'] as num).toDouble(),
        weight: (m['weight'] as num).toDouble(),
        buyDate: m['buy_date'] as String,
        channel: m['channel'] as String,
        merchant: m['merchant'] as String,
        full: (m['full'] as int) == 1,
        repaired: (m['repaired'] as int) == 1,
        yellow: (m['yellow'] as int) == 1,
        remark: m['remark'] as String,
        coverPath: m['cover_path'] as String,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'code': code,
        'name': name,
        'category': category,
        'variety': variety,
        'price': price,
        'l_bian': lBian,
        'l_du': lDu,
        'l_gao': lGao,
        'r_bian': rBian,
        'r_du': rDu,
        'r_gao': rGao,
        'weight': weight,
        'buy_date': buyDate,
        'channel': channel,
        'merchant': merchant,
        'full': full ? 1 : 0,
        'repaired': repaired ? 1 : 0,
        'yellow': yellow ? 1 : 0,
        'remark': remark,
        'cover_path': coverPath,
      };
}
