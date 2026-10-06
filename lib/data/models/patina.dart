// 走色记录 model（可绑定任意藏品：核桃/手串/…，由 owner_type + owner_id 标识）
// images 用 "|" 拼接存储（≤6 张原图路径），避免引入 json 依赖
class Patina {
  final int? id;
  final String ownerType; // 'walnut' | 'item' | ...
  final int ownerId;
  final String date; // YYYY-MM-DD
  final List<String> images;

  Patina({
    this.id,
    required this.ownerType,
    required this.ownerId,
    required this.date,
    this.images = const [],
  });

  factory Patina.fromMap(Map<String, dynamic> m) {
    final type = (m['owner_type'] as String?) ?? 'walnut';
    final ownerId = (m['owner_id'] as int?) ?? (m['walnut_id'] as int? ?? 0);
    return Patina(
      id: m['id'] as int?,
      ownerType: type,
      ownerId: ownerId,
      date: m['date'] as String,
      images: (m['images'] as String? ?? '').isEmpty
          ? const []
          : (m['images'] as String).split('|'),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'owner_type': ownerType,
        'owner_id': ownerId,
        'date': date,
        'images': images.join('|'),
        // 兼容既有 walnut_id 列 + 其外键级联（删核桃时级联清走色）
        if (ownerType == 'walnut') 'walnut_id': ownerId,
      };
}
