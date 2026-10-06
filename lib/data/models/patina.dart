// 走色记录 model（仅核桃，一对多）
// images 用 "|" 拼接存储（≤6 张原图路径），避免引入 json 依赖
class Patina {
  final int? id;
  final int walnutId;
  final String date; // YYYY-MM-DD
  final List<String> images;

  Patina({
    this.id,
    required this.walnutId,
    required this.date,
    this.images = const [],
  });

  factory Patina.fromMap(Map<String, dynamic> m) => Patina(
        id: m['id'] as int?,
        walnutId: m['walnut_id'] as int,
        date: m['date'] as String,
        images: (m['images'] as String? ?? '').isEmpty
            ? const []
            : (m['images'] as String).split('|'),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'walnut_id': walnutId,
        'date': date,
        'images': images.join('|'),
      };
}
