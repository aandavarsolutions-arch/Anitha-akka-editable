class Product {
  String name;
  double rate;
  Product({required this.name, required this.rate});
  Map<String, dynamic> toJson() => {
        'name': name,
        'rate': rate,
      };
  factory Product.fromJson(Map<String, dynamic> json) => Product(
        name: json['name'] ?? '',
        rate: (json['rate'] ?? 0.0).toDouble(),
      );
}
