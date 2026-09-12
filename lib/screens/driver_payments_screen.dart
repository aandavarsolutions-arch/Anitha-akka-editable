import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';

class DriverPaymentsScreen extends StatefulWidget {
  const DriverPaymentsScreen({super.key});

  @override
  State<DriverPaymentsScreen> createState() => _DriverPaymentsScreenState();
}

class _DriverPaymentsScreenState extends State<DriverPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('DRIVER PAYMENTS'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: JarvisTheme.secondary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'TRIP'),
            Tab(text: 'DAILY'),
            Tab(text: 'MONTHLY'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          String type = 'Trip';
          if (_tabController.index == 1) type = 'Daily';
          if (_tabController.index == 2) type = 'Monthly';
          _showAddDriverDialog(context, initialType: type);
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildDriverList(data.allDrivers, 'Trip', data),
              _buildDriverList(data.allDrivers, 'Daily', data),
              _buildDriverList(data.allDrivers, 'Monthly', data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverList(List<Map<String, dynamic>> allDrivers, String type, DataProvider data) {
    final drivers = allDrivers.where((d) => d['type'] == type).toList();
    
    if (drivers.isEmpty) {
        return const Center(child: Text('No records found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: JarvisTheme.primary,
                      ),
                    ),
                    Text(
                      driver['vehicle'],
                      style: const TextStyle(
                        fontSize: 12,
                        color: JarvisTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          driver['earnings'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: JarvisTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'SALARY',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                     PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'payment') {
                          _showPaymentDialog(context, driver);
                        } else if (value == 'history') {
                          _showHistoryDialog(context, driver['id']);
                        } else if (value == 'edit') {
                          _showAddDriverDialog(context, driver: driver);
                        } else if (value == 'delete') {
                          data.deleteDriver(driver['id']);
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
          ),
        );
      },
    );
  }

  void _showAddDriverDialog(BuildContext context, {Map<String, dynamic>? driver, String? initialType}) {
    final nameController = TextEditingController(text: driver != null ? driver['name'] : '');
    final vehicleController = TextEditingController(text: driver != null ? driver['vehicle'] : '');
    final amountController = TextEditingController(text: driver != null ? (driver['earnings'] as String).replaceAll('₹', '').replaceAll(',', '') : '');
    String selectedType = driver != null ? driver['type'] : (initialType ?? 'Trip');

    DateTime selectedDate = driver != null 
        ? (driver['date'] != null && driver['date'] != 'Today' ? DateFormat('dd MMM yyyy').parse(driver['date']) : DateTime.now()) 
        : DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(driver != null ? 'Edit Driver Payment' : 'Add Driver Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Driver Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleController,
                  decoration: const InputDecoration(labelText: 'Vehicle Info'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Salary Amount (₹)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType.isNotEmpty 
                      ? (selectedType[0].toUpperCase() + selectedType.substring(1).toLowerCase())
                      : 'Trip',
                  decoration: const InputDecoration(labelText: 'Payment Type'),
                  items: ['Trip', 'Daily', 'Monthly']
                      .map((t) => t[0].toUpperCase() + t.substring(1).toLowerCase())
                      .toSet() 
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedType = val!;
                    });
                  },
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
                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                   final newData = {
                      'name': nameController.text,
                      'vehicle': vehicleController.text,
                      'type': selectedType,
                      'earnings': '₹${amountController.text}',
                      'status': StatusType.pending, // Default to pending
                      'date': DateFormat('dd MMM yyyy').format(selectedDate),
                   };

                  if (driver != null) {
                    Provider.of<DataProvider>(context, listen: false).updateDriver(
                      driver['id'],
                      newData
                    );
                  } else {
                    Provider.of<DataProvider>(context, listen: false).addDriver(newData);
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

  void _showHistoryDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Payment History'),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: Provider.of<DataProvider>(context, listen: false).getDriverPayments(id),
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

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> driver) {
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
                if (amountController.text.isNotEmpty) {
                    double add = double.tryParse(amountController.text) ?? 0.0;
                    
                    if (add > 0) {
                      Provider.of<DataProvider>(context, listen: false).addDriverPayment(
                         driver['id'], 
                         add, 
                         selectedDate
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment Added Successfully')),
                      );
                    }
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
