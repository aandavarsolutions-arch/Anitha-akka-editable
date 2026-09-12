import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../models/customer.dart';

class GstCustomersScreen extends StatelessWidget {
  const GstCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Customers')),
      body: ListView.builder(
         itemCount: provider.customers.length,
         itemBuilder: (context, index) {
            final c = provider.customers[index];
            return ListTile(
              title: Text(c.name),
              subtitle: Text('${c.address}\n${c.gst}'),
              isThreeLine: true,
              onLongPress: () => provider.deleteCustomer(index),
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
    final addrCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: gstCtrl, decoration: const InputDecoration(labelText: 'GSTIN')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
               if (nameCtrl.text.isNotEmpty) {
                 final c = Customer(name: nameCtrl.text, address: addrCtrl.text, gst: gstCtrl.text);
                 Provider.of<BillingProvider>(context, listen: false).addCustomer(c);
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
