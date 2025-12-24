/// Exercise model
class Exercise {
  final String id;
  final String name;
  final bool isTwoSided;

  Exercise({
    required this.id,
    required this.name,
    this.isTwoSided = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'isTwoSided': isTwoSided,
  };

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'] as String,
    name: json['name'] as String,
    isTwoSided: json['isTwoSided'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
