import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../models/product.dart';

class GstProductsScreen extends StatelessWidget {
  const GstProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Products')),
      body: ListView.builder(
         itemCount: provider.products.length,
         itemBuilder: (context, index) {
            final p = provider.products[index];
            return ListTile(
              title: Text(p.name),
              trailing: Text('₹${p.rate}'),
              onLongPress: () => provider.deleteProduct(index),
            );
         },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Product Name')),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rate'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
               if (nameCtrl.text.isNotEmpty && rateCtrl.text.isNotEmpty) {
                 final p = Product(name: nameCtrl.text, rate: double.tryParse(rateCtrl.text) ?? 0);
                 Provider.of<BillingProvider>(context, listen: false).addProduct(p);
                 Navigator.pop(ctx);
               }
            },
            child: const Text('ADD'),
          )
        ],
      ),
    );
  }
}
