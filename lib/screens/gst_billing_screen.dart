import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/billing_provider.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../models/customer.dart';
import 'gst_settings_screen.dart';
import 'gst_history_screen.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';

class GstBillingScreen extends StatefulWidget {
  const GstBillingScreen({super.key});

  @override
  State<GstBillingScreen> createState() => _GstBillingScreenState();
}

class _GstBillingScreenState extends State<GstBillingScreen> {
  final _productConfigController = TextEditingController(); // Search/Product Name
  final _qtyController = TextEditingController(text: '1');
  final _rateController = TextEditingController();
  
  // Header Controllers
  final _customerSearchController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerGstController = TextEditingController();
  final _customerFocusNode = FocusNode();
  final _productFocusNode = FocusNode();

  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    // Re-initialize details from provider if needed, or clear.
    // Usually we want fresh bill on entry? Provider logic handles this or we call clear.
  }
  
  void _addItem(BillingProvider provider) {
      if (_productConfigController.text.isEmpty || _rateController.text.isEmpty) return;
      
      final qty = double.tryParse(_qtyController.text) ?? 1;
      final rate = double.tryParse(_rateController.text) ?? 0;
      final amount = qty * rate; // Simple calculation, storing as line item. 
      // Wait, InvoiceItem has particulars, rate, amount. Qty isn't in InvoiceItem?
      // User provided model: particulars, rate, amount. 
      // So 'Particulars' should probably be "Name x Qty"? or just Name?
      // Standard billing usually has Qty. 
      // Following USER PROVIDED MODEL strictly: 
      /*
      class InvoiceItem {
        String particulars;
        double rate;
        double amount;
      }
      */
      // So I will format particulars as "${Name} x ${Qty}".
      
      final item = InvoiceItem(
        particulars: '${_productConfigController.text} ${qty > 1 ? " x $qty" : ""}',
        rate: rate, // Rate per unit? or Total Rate? 
        // If rate is per unit, and amount is total...
        // Let's assume Rate is Unit Rate.
        amount: amount, 
      );
      
      provider.addItem(item);
      
      // Clear inputs
      _productConfigController.clear();
      _qtyController.text = '1';
      _rateController.clear();
      _selectedProduct = null;
      setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BillingProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('GST Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GstSettingsScreen())),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(child: Center(child: Text("GST Menu", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))),
            ListTile(
               leading: const Icon(Icons.history),
               title: const Text('Billing History'),
               onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const GstHistoryScreen())); },
            ),
            const Divider(),
            ListTile(
               leading: const Icon(Icons.home),
               title: const Text('Back to Dashboard'),
               onTap: () { Navigator.pop(context); Navigator.pop(context); },
            ),
            ListTile(
               leading: const Icon(Icons.business),
               title: const Text('Main Menu (Site Management)'),
               onTap: () { 
                 Navigator.pop(context);
                 Navigator.pushAndRemoveUntil(
                   context, 
                   MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                   (route) => false,
                 );
               },
            ),
            ListTile(
               leading: const Icon(Icons.logout),
               title: const Text('Logout'),
               onTap: () { 
                 Navigator.pop(context);
                 Navigator.pushAndRemoveUntil(
                   context, 
                   MaterialPageRoute(builder: (_) => const LoginScreen()),
                   (route) => false,
                 );
               },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
           // 1. Customer Section
           Container(
             padding: const EdgeInsets.all(12),
             color: Colors.blue.shade50,
             child: Column(
               children: [
                 Row(
                   children: [
                     Expanded(
                       child: Autocomplete<Customer>(
                         focusNode: _customerFocusNode,
                         textEditingController: _customerSearchController,
                         optionsBuilder: (text) => provider.customers.where((c) => c.name.toLowerCase().contains(text.text.toLowerCase())),
                         displayStringForOption: (c) => c.name,
                         onSelected: (c) {
                            _customerSearchController.text = c.name;
                            _customerAddressController.text = c.address;
                            _customerGstController.text = c.gst;
                            provider.setCustomerDetails(c.name, c.address, c.gst);
                         },
                         fieldViewBuilder: (context, controller, focus, submitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: const InputDecoration(labelText: 'Customer Name', border: OutlineInputBorder(), isDense: true),
                              onChanged: (val) {
                                provider.setCustomerDetails(val, _customerAddressController.text, _customerGstController.text);
                              },
                            );
                         },
                       ),
                     ),
                     const SizedBox(width: 10),
                     SizedBox(
                       width: 120,
                       child: TextField(
                         controller: _customerGstController,
                         decoration: const InputDecoration(labelText: 'Buyer GST', border: OutlineInputBorder(), isDense: true),
                         onChanged: (val) => provider.setCustomerDetails(_customerSearchController.text, _customerAddressController.text, val),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 TextField(
                    controller: _customerAddressController,
                    decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder(), isDense: true),
                    onChanged: (val) => provider.setCustomerDetails(_customerSearchController.text, val, _customerGstController.text),
                 ),
               ],
             ),
           ),
           
           // 2. Product Entry
           Padding(
             padding: const EdgeInsets.all(8.0),
             child: Row(
               children: [
                 Expanded(
                    flex: 3,
                    child: Autocomplete<Product>(
                         optionsBuilder: (text) => provider.products.where((p) => p.name.toLowerCase().contains(text.text.toLowerCase())),
                         displayStringForOption: (p) => p.name,
                         onSelected: (p) {
                            _selectedProduct = p;
                            _productConfigController.text = p.name;
                            _rateController.text = p.rate.toStringAsFixed(2);
                         },
                         fieldViewBuilder: (context, controller, focus, submitted) {
                            return TextField(
                              controller: controller,
                              focusNode: focus,
                              decoration: const InputDecoration(labelText: 'Product / Particulars', border: OutlineInputBorder()),
                              onChanged: (val) => _productConfigController.text = val,
                            );
                         },
                       ),
                 ),
                 const SizedBox(width: 8),
                 Expanded(flex: 1, child: TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty', border: OutlineInputBorder()))),
                 const SizedBox(width: 8),
                 Expanded(flex: 1, child: TextField(controller: _rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate', border: OutlineInputBorder()))),
                 const SizedBox(width: 8),
                 IconButton(
                   icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                   onPressed: () => _addItem(provider),
                 )
               ],
             ),
           ),
           
           // 3. Item List
           Expanded(
             child: ListView.builder(
               itemCount: provider.invoiceItems.length,
               itemBuilder: (context, index) {
                 final item = provider.invoiceItems[index];
                 return ListTile(
                   title: Text(item.particulars),
                   subtitle: Text('Rate: ${item.rate} | Amount: ${item.amount}'),
                   trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => provider.removeItem(index)),
                 );
               },
             ),
           ),
           
           // 4. Totals Footer
           Container(
             padding: const EdgeInsets.all(16),
             color: Colors.grey.shade100,
             child: Column(
               children: [
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Sub Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(provider.subTotal.toStringAsFixed(2)),
                 ]),
                 const SizedBox(height: 4),
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(
                      children: [
                        const Text('GST '),
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: TextEditingController(text: provider.gstPercentage.toString())
                              ..selection = TextSelection.fromPosition(TextPosition(offset: provider.gstPercentage.toString().length)),
                            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.zero, suffixText: '%'),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                               final newGst = double.tryParse(val) ?? 0.0;
                               if (newGst != provider.gstPercentage) {
                                 provider.setGstPercentage(newGst);
                               }
                            },
                          ),
                        ),
                        const Text(':'),
                      ],
                    ),
                    Text(provider.gstAmount.toStringAsFixed(2)),
                 ]),
                 const Divider(),
                 Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('GRAND TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(provider.grandTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                 ]),
                 const SizedBox(height: 16),
                 SizedBox(
                   width: double.infinity,
                   height: 50,
                   child: ElevatedButton.icon(
                     onPressed: () async {
                       await provider.saveBill();
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice Saved & Generated')));
                     }, 
                     icon: const Icon(Icons.save), 
                     label: const Text('SAVE & PRINT INVOICE')
                   ),
                 )
               ],
             ),
           )
        ],
      ),
    );
  }
}
