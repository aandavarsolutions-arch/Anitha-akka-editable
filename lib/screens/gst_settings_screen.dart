import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../models/shop_settings.dart';

class GstSettingsScreen extends StatefulWidget {
  const GstSettingsScreen({super.key});

  @override
  State<GstSettingsScreen> createState() => _GstSettingsScreenState();
}

class _GstSettingsScreenState extends State<GstSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _gstCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _declCtrl;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<BillingProvider>(context, listen: false).settings;
    _nameCtrl = TextEditingController(text: settings.shopName);
    _addrCtrl = TextEditingController(text: settings.shopAddress);
    _gstCtrl = TextEditingController(text: settings.sellerGst);
    _contactCtrl = TextEditingController(text: settings.contactNumbers);
    _declCtrl = TextEditingController(text: settings.declaration);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _gstCtrl.dispose();
    _contactCtrl.dispose();
    _declCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Shop Name', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _addrCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 16),
              TextFormField(controller: _gstCtrl, decoration: const InputDecoration(labelText: 'Seller GSTIN', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Numbers', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextFormField(controller: _declCtrl, decoration: const InputDecoration(labelText: 'Declaration', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () {
                   final newSettings = ShopSettings(
                      shopName: _nameCtrl.text,
                      shopAddress: _addrCtrl.text,
                      sellerGst: _gstCtrl.text,
                      contactNumbers: _contactCtrl.text,
                      declaration: _declCtrl.text,
                      lastInvoiceNo: Provider.of<BillingProvider>(context, listen: false).settings.lastInvoiceNo
                   );
                   Provider.of<BillingProvider>(context, listen: false).updateSettings(newSettings);
                   Navigator.pop(context);
                },
                child: const Text('Save Settings'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
