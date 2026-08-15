class CategoryModel {
  final int id;
  final String name;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }
}
