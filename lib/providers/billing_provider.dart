import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/shop_settings.dart';
import '../services/storage_service.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';

class BillingProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final PdfService _pdfService = PdfService();
  final ExcelService _excelService = ExcelService();
  
  ShopSettings _settings = ShopSettings(shopName: 'My Shop', sellerGst: '');
  List<Product> _products = [];
  List<Customer> _customers = [];
  
  String _customerName = '';
  String _customerAddress = '';
  String _buyerGst = '';
  double _gstPercentage = 18.0;
  List<InvoiceItem> _invoiceItems = [];
  DateTime _invoiceDate = DateTime.now();
  
  ShopSettings get settings => _settings;
  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<InvoiceItem> get invoiceItems => _invoiceItems;
  DateTime get invoiceDate => _invoiceDate;
  double get gstPercentage => _gstPercentage;
  String get customerName => _customerName;
  String get customerAddress => _customerAddress;
  String get buyerGst => _buyerGst;
  
  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  BillingProvider() {
    _loadData();
  }
  
  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();
    
    final loadedSettings = await _storageService.loadSettings();
    if (loadedSettings != null) {
      _settings = loadedSettings;
    }
    
    final loadedProducts = await _storageService.loadProducts();
    _products = loadedProducts;
    
    final loadedCustomers = await _storageService.loadCustomers();
    _customers = loadedCustomers;
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> updateSettings(ShopSettings newSettings) async {
    _settings = newSettings;
    await _storageService.saveSettings(newSettings);
    notifyListeners();
  }
  
  Future<void> addProduct(Product product) async {
    _products.add(product);
    await _storageService.saveProducts(_products);
    notifyListeners();
  }
  
  Future<void> updateProduct(int index, Product product) async {
    _products[index] = product;
    await _storageService.saveProducts(_products);
    notifyListeners();
  }
  
  Future<void> deleteProduct(int index) async {
    _products.removeAt(index);
    await _storageService.saveProducts(_products);
    notifyListeners();
  }
  
  Future<void> addCustomer(Customer customer) async {
    _customers.add(customer);
    await _storageService.saveCustomers(_customers);
    notifyListeners();
  }
  
  Future<void> updateCustomer(int index, Customer customer) async {
    _customers[index] = customer;
    await _storageService.saveCustomers(_customers);
    notifyListeners();
  }
  
  Future<void> deleteCustomer(int index) async {
    _customers.removeAt(index);
    await _storageService.saveCustomers(_customers);
    notifyListeners();
  }
  
  void setCustomerDetails(String name, String address, String gst) {
    _customerName = name;
    _customerAddress = address;
    _buyerGst = gst;
    notifyListeners();
  }
  
  void setInvoiceDate(DateTime date) {
    _invoiceDate = date;
    notifyListeners();
  }
  
  void setGstPercentage(double percentage) {
    _gstPercentage = percentage;
    notifyListeners();
  }
  
  void addItem(InvoiceItem item) {
    _invoiceItems.add(item);
    notifyListeners();
  }
  
  void removeItem(int index) {
    _invoiceItems.removeAt(index);
    notifyListeners();
  }
  
  void updateItem(int index, InvoiceItem item) {
    _invoiceItems[index] = item;
    notifyListeners();
  }
  
  void clearCurrentBill() {
    _invoiceItems = [];
    _customerName = '';
    _customerAddress = '';
    _buyerGst = '';
    _invoiceDate = DateTime.now();
    notifyListeners();
  }
  
  double get subTotal => _invoiceItems.fold(0, (sum, item) => sum + item.amount);
  double get gstAmount => subTotal * (_gstPercentage / 100);
  double get grandTotal => subTotal + gstAmount;
  
  Future<String> getNextInvoiceNumber() async {
    return 'INV-${(_settings.lastInvoiceNo + 1).toString().padLeft(3, '0')}';
  }
  
  Future<void> saveBill() async {
    final invoiceNoCode = await getNextInvoiceNumber();
    
    final invoice = Invoice(
      invoiceNo: invoiceNoCode,
      date: _invoiceDate,
      customerName: _customerName,
      customerAddress: _customerAddress,
      buyerGst: _buyerGst,
      items: _invoiceItems,
      subTotal: subTotal,
      gstPercentage: _gstPercentage,
      gstAmount: gstAmount,
      grandTotal: grandTotal,
    );
    
    await _storageService.saveInvoiceJson(invoice);
    _settings.lastInvoiceNo++;
    await _storageService.saveSettings(_settings); // Save new invoice number
    
    final pdfBytes = await _pdfService.generateInvoice(invoice, _settings);
    final excelBytes = await _excelService.generateInvoice(invoice, _settings);
    
    final dirPath = await _storageService.getInvoiceFolderPath();
    final pdfFile = File('$dirPath\\invoice_${invoice.invoiceNo}.pdf');
    await pdfFile.writeAsBytes(pdfBytes);
    
    if (excelBytes != null) {
      final excelFile = File('$dirPath\\invoice_${invoice.invoiceNo}.xlsx');
      await excelFile.writeAsBytes(excelBytes);
    }
    
    clearCurrentBill();
    notifyListeners();
  }
  
  Future<Uint8List> generatePreviewPdf() async {
    final invoiceNoCode = await getNextInvoiceNumber();
    final invoice = Invoice(
      invoiceNo: invoiceNoCode,
      date: _invoiceDate,
      customerName: _customerName,
      customerAddress: _customerAddress,
      buyerGst: _buyerGst,
      items: _invoiceItems,
      subTotal: subTotal,
      gstPercentage: _gstPercentage,
      gstAmount: gstAmount,
      grandTotal: grandTotal,
    );
    return await _pdfService.generateInvoice(invoice, _settings);
  }

  Future<List<Invoice>> loadSavedInvoices() async {
    return await _storageService.loadInvoices();
  }

  Future<String> getInvoiceFolderPath() async {
    return await _storageService.getInvoiceFolderPath();
  }
}
