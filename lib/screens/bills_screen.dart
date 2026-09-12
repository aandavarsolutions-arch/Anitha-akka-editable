import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('BILLS & ESTIMATES'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBillDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.bills.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final bill = data.bills[index];
              
              // Calc amounts
              double parse(dynamic val) {
                if (val == null) return 0.0;
                String s = val.toString().replaceAll('₹', '').replaceAll(',', '');
                return double.tryParse(s) ?? 0.0;
              }
              double total = parse(bill['amount']);
              double paid = parse(bill['paid']);
              double balance = total - paid;
              if (balance < 0) balance = 0;

              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            bill['id'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: JarvisTheme.primary,
                              fontSize: 12, // Slightly smaller ID
                            ),
                          ),
                          Row(
                            children: [
                              StatusChip(
                                label: bill['status'] == StatusType.paid 
                                    ? 'PAID' 
                                    : bill['status'] == StatusType.partial ? 'PARTIAL' : 'PENDING',
                                type: bill['status'],
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'payment') {
                                    _showPaymentDialog(context, bill);
                                  } else if (value == 'history') {
                                     _showHistoryDialog(context, bill['id']);
                                  } else if (value == 'edit') {
                                    _showAddBillDialog(context, bill: bill);
                                  } else if (value == 'delete') {
                                    data.deleteBill(bill['id']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'payment',
                                    child: Row(
                                      children: [
                                        Icon(Icons.payment, size: 18, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Add Payment'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'history',
                                    child: Row(
                                      children: [
                                        Icon(Icons.history, size: 18, color: Colors.purple),
                                        SizedBox(width: 8),
                                        Text('History'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        bill['site'],
                        style: const TextStyle(
                          fontSize: 18, // Prominent Site Name
                          fontWeight: FontWeight.bold,
                          color: JarvisTheme.textPrimary,
                        ),
                      ),
                      Text(
                        bill['date'],
                        style: const TextStyle(
                          color: JarvisTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDetailColumn('Total', '₹${total.toStringAsFixed(0)}', Colors.black87),
                          _buildDetailColumn('Paid', '₹${paid.toStringAsFixed(0)}', Colors.green),
                          _buildDetailColumn('Balance', '₹${balance.toStringAsFixed(0)}', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDetailColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold, 
            color: color
          ),
        ),
      ],
    );
  }

  void _showAddBillDialog(BuildContext context, {Map<String, dynamic>? bill}) {
    final siteController = TextEditingController(text: bill != null ? bill['site'] : '');
    final amountController = TextEditingController(text: bill != null ? (bill['amount'] as String).replaceAll('₹', '').replaceAll(',', '') : '');
    final paidController = TextEditingController(text: bill != null && bill['paid'] != null ? (bill['paid'] as String).replaceAll('₹', '').replaceAll(',', '') : '');

    DateTime selectedDate = bill != null 
        ? (bill['date'] != null && bill['date'] != 'Today' ? DateFormat('dd MMM yyyy').parse(bill['date']) : DateTime.now()) 
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
          title: Text(bill != null ? 'Edit Bill' : 'New Bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: siteController,
                  decoration: const InputDecoration(labelText: 'Site Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Total Bill Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidController,
                  decoration: const InputDecoration(labelText: 'Paid Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (siteController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  // Default paid to 0 if empty
                  if (paidController.text.isEmpty) paidController.text = '0';
                  
                  try {
                    if (bill != null) {
                       await Provider.of<DataProvider>(context, listen: false).updateBill(
                         bill['id'],
                         {
                           'site': siteController.text,
                           'amount': '₹${amountController.text}',
                           'paid': '₹${paidController.text}',
                           'date': DateFormat('dd MMM yyyy').format(selectedDate),
                         }
                       );
                    } else {
                      await Provider.of<DataProvider>(context, listen: false).addBill({
                        'site': siteController.text,
                        'amount': '₹${amountController.text}',
                        'paid': '₹${paidController.text}',
                        'date': DateFormat('dd MMM yyyy').format(selectedDate),
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
        }
      ),
    );
  }
  void _showHistoryDialog(BuildContext context, String billId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Payment History'),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: Provider.of<DataProvider>(context, listen: false).getBillPayments(billId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No payment history found.'),
                );
              }
              final history = snapshot.data!.reversed.toList();
              
              return SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = history[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['amount'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(item['date']),
                      leading: const Icon(Icons.payment, color: Colors.green),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> bill) {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                   controller: amountController,
                   decoration: const InputDecoration(labelText: 'Amount to Pay (₹)'),
                   keyboardType: TextInputType.number,
                   autofocus: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                       child: Text(
                         'Date: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                         style: const TextStyle(fontWeight: FontWeight.bold),
                       )
                     ),
                     IconButton(
                       icon: const Icon(Icons.calendar_today),
                       onPressed: () async {
                          final picked = await showDatePicker(
                            context: context, 
                            initialDate: selectedDate,
                            firstDate: DateTime(2020), 
                            lastDate: DateTime(2030)
                          );
                          if(picked != null) setState(() => selectedDate = picked);
                       }
                     )
                  ]
                )
              ],
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
               ElevatedButton(
                 onPressed: () {
                    double current = 0.0;
                    if (bill['paid'] != null) {
                       String s = bill['paid'].toString().replaceAll('₹', '').replaceAll(',', '');
                       current = double.tryParse(s) ?? 0.0;
                    }
                    double add = double.tryParse(amountController.text) ?? 0.0;
                    
                    if (add > 0) {
                      double newTotal = current + add;
                      
                      Provider.of<DataProvider>(context, listen: false).updateBill(
                         bill['id'],
                         {
                           'paid': '₹${newTotal.toStringAsFixed(0)}',
                           // We must maintain the original bill date if we don't want to change it?
                           // Actually current updateBill logic uses 'date' for the Payment Log date.
                           // And updates the bill's date too.
                           // Send 'date' as Payment Date.
                           'date': DateFormat('dd MMM yyyy').format(selectedDate),
                         }
                      );
                    }
                    Navigator.pop(context);
                 },
                 child: const Text('PAY'),
               )
            ]
          );
        }
      )
    );
  }
}
