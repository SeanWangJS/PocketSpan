/// Represents a user-customizable category tag with paired light/dark colors.
class TagModel {
  final String id;
  final String name;
  final String lightColorHex;
  final String darkColorHex;
  final int sortOrder;

  const TagModel({
    required this.id,
    required this.name,
    required this.lightColorHex,
    required this.darkColorHex,
    this.sortOrder = 0,
  });

  TagModel copyWith({
    String? id,
    String? name,
    String? lightColorHex,
    String? darkColorHex,
    int? sortOrder,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lightColorHex: lightColorHex ?? this.lightColorHex,
      darkColorHex: darkColorHex ?? this.darkColorHex,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'light_color_hex': lightColorHex,
      'dark_color_hex': darkColorHex,
      'sort_order': sortOrder,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'] as String,
      name: map['name'] as String,
      lightColorHex: map['light_color_hex'] as String,
      darkColorHex: map['dark_color_hex'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
