class InvoiceItem {
  String particulars;
  double rate;
  double amount;
  InvoiceItem({
    required this.particulars,
    required this.rate,
    required this.amount,
  });
  Map<String, dynamic> toJson() => {
        'particulars': particulars,
        'rate': rate,
        'amount': amount,
      };
  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        particulars: json['particulars'],
        rate: (json['rate'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
      );
}

class Invoice {
  String invoiceNo;
  DateTime date;
  String customerName;
  String customerAddress;
  String buyerGst;
  List<InvoiceItem> items;
  double subTotal;
  double gstPercentage;
  double gstAmount;
  double grandTotal;
  
  Invoice({
    required this.invoiceNo,
    required this.date,
    required this.customerName,
    required this.customerAddress,
    required this.buyerGst,
    required this.items,
    required this.subTotal,
    required this.gstPercentage,
    required this.gstAmount,
    required this.grandTotal,
  });

  Map<String, dynamic> toJson() => {
        'invoice_no': invoiceNo,
        'date': date.toIso8601String(),
        'customer_name': customerName,
        'customer_address': customerAddress,
        'buyer_gst': buyerGst,
        'items': items.map((i) => i.toJson()).toList(),
        'sub_total': subTotal,
        'gst_percentage': gstPercentage,
        'gst_amount': gstAmount,
        'grand_total': grandTotal,
      };
      
  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
        invoiceNo: json['invoice_no'],
        date: DateTime.parse(json['date']),
        customerName: json['customer_name'],
        customerAddress: json['customer_address'],
        buyerGst: json['buyer_gst'],
        items: List<InvoiceItem>.from(json['items'].map((x) => InvoiceItem.fromJson(x))),
        subTotal: (json['sub_total'] as num).toDouble(),
        gstPercentage: (json['gst_percentage'] as num).toDouble(),
        gstAmount: (json['gst_amount'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
      );
}
