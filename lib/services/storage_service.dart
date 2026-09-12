import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/shop_settings.dart';
import '../models/product.dart';
import '../models/customer.dart';
import '../models/invoice.dart';
import 'package:flutter/material.dart';

class StorageService {
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}\\MyBills';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<File> _getFile(String filename) async {
    final path = await _localPath;
    return File('$path\\$filename');
  }

  Future<void> saveSettings(ShopSettings settings) async {
    final file = await _getFile('settings.json');
    await file.writeAsString(jsonEncode(settings.toJson()));
  }

  Future<ShopSettings?> loadSettings() async {
    try {
      final file = await _getFile('settings.json');
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      return ShopSettings.fromJson(jsonDecode(contents));
    } catch (e) {
      return null;
    }
  }

  Future<void> saveProducts(List<Product> products) async {
    final file = await _getFile('products.json');
    await file.writeAsString(jsonEncode(products.map((e) => e.toJson()).toList()));
  }

  Future<List<Product>> loadProducts() async {
    try {
      final file = await _getFile('products.json');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCustomers(List<Customer> customers) async {
    final file = await _getFile('customers.json');
    await file.writeAsString(jsonEncode(customers.map((e) => e.toJson()).toList()));
  }

  Future<List<Customer>> loadCustomers() async {
    try {
      final file = await _getFile('customers.json');
      if (!await file.exists()) return [];
      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((e) => Customer.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveInvoiceJson(Invoice invoice) async {
     final path = await _localPath;
     final invoiceDir = Directory('$path\\Invoices');
      if (!await invoiceDir.exists()) {
        await invoiceDir.create(recursive: true);
      }
     final file = File('${invoiceDir.path}\\invoice_${invoice.invoiceNo}.json');
     await file.writeAsString(jsonEncode(invoice.toJson()));
  }
  
  Future<String> getInvoiceFolderPath() async {
      final path = await _localPath;
      final invoiceDir = Directory('$path\\Invoices');
      if (!await invoiceDir.exists()) {
        await invoiceDir.create(recursive: true);
      }
      return invoiceDir.path;
  }

  Future<List<Invoice>> loadInvoices() async {
    try {
      final path = await getInvoiceFolderPath();
      final dir = Directory(path);
      if (!await dir.exists()) return [];
      
      final List<Invoice> invoices = [];
      final List<FileSystemEntity> files;
      try {
        files = dir.listSync();
      } catch (e) {
        debugPrint('Error listing files: $e');
        return [];
      }
      
      for (var file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final contents = await file.readAsString();
            invoices.add(Invoice.fromJson(jsonDecode(contents)));
          } catch (e) {
            debugPrint('Error parsing invoice file ${file.path}: $e');
          }
        }
      }
      
      // Sort by invoice number or date (descending)
      invoices.sort((a, b) => b.date.compareTo(a.date));
      return invoices;
    } catch (e) {
      debugPrint('Error loading invoices: $e');
      return [];
    }
  }
}
