class Customer {
  String name;
  String address;
  String gst;
  Customer({required this.name, required this.address, required this.gst});
  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'gst': gst,
      };
  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        name: json['name'] ?? '',
        address: json['address'] ?? '',
        gst: json['gst'] ?? '',
      );
}
