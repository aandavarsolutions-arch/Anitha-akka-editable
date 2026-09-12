import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import 'labour_ledger_screen.dart';

class LabourPaymentsScreen extends StatelessWidget {
  const LabourPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('LABOUR PAYMENTS'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLabourDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: data.allLabour.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final worker = data.allLabour[index];
              return Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                worker['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: JarvisTheme.primary,
                                ),
                              ),
                              Text(
                                worker['site'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: JarvisTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  worker['type'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'payment') {
                                    _showPaymentDialog(context, worker);
                                  } else if (value == 'history') {
                                    _showHistoryDialog(context, worker['id'], worker['name']);
                                  } else if (value == 'edit') {
                                    _showAddLabourDialog(context, worker: worker);
                                  } else if (value == 'delete') {
                                    data.deleteLabour(worker['id']);
                                  }
                                },
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'payment',
                                    child: Row(
                                      children: [
                                        Icon(Icons.payment, size: 18, color: Colors.green),
                                        SizedBox(width: 8),
                                        Text('Add Advance'),
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoColumn('Advance', worker['advance']),
                          _buildInfoColumn('Balance', worker['balance'], color: JarvisTheme.statusPending),
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

  Widget _buildInfoColumn(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            color: JarvisTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? JarvisTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showAddLabourDialog(BuildContext context, {Map<String, dynamic>? worker}) {
    final nameController = TextEditingController(text: worker != null ? worker['name'] : '');
    final siteController = TextEditingController(text: worker != null ? worker['site'] : '');
    final typeController = TextEditingController(text: worker != null ? worker['type'] : 'Daily');
    final advanceController = TextEditingController(text: worker != null ? (worker['advance'] as String).replaceAll('₹', '').replaceAll(',', '') : '');
    final balanceController = TextEditingController(text: worker != null ? (worker['balance'] as String).replaceAll('₹', '').replaceAll(',', '') : '');

    DateTime selectedDate = worker != null 
        ? (worker['date'] != null && worker['date'] != 'Today' ? DateFormat('dd MMM yyyy').parse(worker['date']) : DateTime.now()) 
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(worker != null ? 'Edit Labour' : 'Add Labour'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: siteController,
                  decoration: const InputDecoration(labelText: 'Site'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(labelText: 'Type (Daily/Weekly/Contract)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: advanceController,
                  decoration: const InputDecoration(labelText: 'Advance (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: balanceController,
                  decoration: const InputDecoration(labelText: 'Balance (₹)'),
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
              onPressed: () {
                if (nameController.text.isNotEmpty && siteController.text.isNotEmpty) {
                   final newData = {
                      'name': nameController.text,
                      'site': siteController.text,
                      'type': typeController.text,
                      'advance': '₹${advanceController.text}',
                      'balance': '₹${balanceController.text}',
                      'date': DateFormat('dd MMM yyyy').format(selectedDate),
                    };
                  
                if (worker != null) {
                  Provider.of<DataProvider>(context, listen: false).updateLabour(
                    worker['id'],
                    newData
                  );
                } else {
                  Provider.of<DataProvider>(context, listen: false).addLabour(newData);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    ),
  );
}

  void _showHistoryDialog(BuildContext context, String id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LabourLedgerScreen(
          workerName: name,
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> worker) {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Advance'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                   controller: amountController,
                   decoration: const InputDecoration(labelText: 'Advance Amount (₹)'),
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
                    final amountValue = double.tryParse(amountController.text) ?? 0;
                    if (amountValue > 0) {
                      Provider.of<DataProvider>(context, listen: false).addLabourPayment(
                        worker['id'], 
                        amountValue, 
                        DateFormat('dd MMM yyyy').format(selectedDate)
                      );
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('ADD'),
                )
            ]
          );
        }
      )
    );
  }
}
