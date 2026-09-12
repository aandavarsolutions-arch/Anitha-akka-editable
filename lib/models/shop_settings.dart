class ShopSettings {
  String shopName;
  String shopAddress;
  String sellerGst;
  String? logoPath;
  int lastInvoiceNo;
  String contactNumbers;
  String declaration;
  ShopSettings({
    required this.shopName,
    this.shopAddress = '',
    required this.sellerGst,
    this.logoPath,
    this.lastInvoiceNo = 0,
    this.contactNumbers = '',
    this.declaration = 'Goods once sold cannot be taken back or exchanged.\nAll claims subject to Palani Jurisdiction.\nOur Responsibility ceases after the goods have been delivered to the carrier',
  });
  Map<String, dynamic> toJson() => {
        'shop_name': shopName,
        'shop_address': shopAddress,
        'seller_gst': sellerGst,
        'logo_path': logoPath,
        'last_invoice_no': lastInvoiceNo,
        'contact_numbers': contactNumbers,
        'declaration': declaration,
      };
  factory ShopSettings.fromJson(Map<String, dynamic> json) => ShopSettings(
        shopName: json['shop_name'] ?? '',
        shopAddress: json['shop_address'] ?? '',
        sellerGst: json['seller_gst'] ?? '',
        logoPath: json['logo_path'],
        lastInvoiceNo: json['last_invoice_no'] ?? 0,
        contactNumbers: json['contact_numbers'] ?? '',
        declaration: json['declaration'] ?? 'Goods once sold cannot be taken back or exchanged.\nAll claims subject to Palani Jurisdiction.\nOur Responsibility ceases after the goods have been delivered to the carrier',
      );
}
