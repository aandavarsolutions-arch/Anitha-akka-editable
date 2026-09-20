import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';
import 'supplier_payments_screen.dart';
import '../screens/add_vehicle_payment_screen.dart';
import '../screens/labour_ledger_screen.dart';
import '../screens/other_ledger_screen.dart';
import '../screens/bunk_ledger_screen.dart';
import '../screens/mechanic_ledger_screen.dart';
import '../screens/storage_tank_history_screen.dart';
import '../app_config.dart';

class SiteExpensesScreen extends StatefulWidget {
  final String? category;
  final String? initialVehicle;
  final String? initialSite;
  final bool openDialog;
  
  const SiteExpensesScreen({
    super.key, 
    this.category, 
    this.initialVehicle,
    this.initialSite,
    this.openDialog = false,
  });

  @override
  State<SiteExpensesScreen> createState() => _SiteExpensesScreenState();
}

class _SiteExpensesScreenState extends State<SiteExpensesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedSite;
  String _selectedVehicle = 'All Vehicles';

  DateTimeRange? _selectedDateRange;
  final Set<String> _selectedExpenseIds = {};

  @override
  void initState() {
    super.initState();
    final data = Provider.of<DataProvider>(context, listen: false);
    if (widget.category == 'Vehicle' && widget.initialSite == null) {
      _selectedSite = 'All Sites';
    } else {
      _selectedSite = widget.initialSite ?? (data.activeSites.isNotEmpty ? data.activeSites.first : 'No Active Sites');
    }
    
    if (widget.category == 'Vehicle') {
      _tabController = TabController(length: 3, vsync: this);
      _tabController.addListener(() { 
        if (!_tabController.indexIsChanging) {
          setState(() {
            _selectedExpenseIds.clear();
          });
        }
      });
    } else if (widget.category == null) {
      _tabController = TabController(length: 3, vsync: this);
      _tabController.addListener(() { 
        if (!_tabController.indexIsChanging) {
          setState(() {
            _selectedExpenseIds.clear();
          });
        } 
      });
    }
    
    if (widget.openDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddExpenseDialog(context, initialCategory: widget.category, initialVehicle: widget.initialVehicle, initialSite: widget.initialSite);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      data.fetchFuelTankData();
    });
  }

  @override
  void dispose() {
    if (widget.category == null || widget.category == 'Vehicle') {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: _selectedExpenseIds.isEmpty 
          ? Text(widget.category == 'Vehicle' ? 'MAINTENANCE AND FUEL' : (widget.category != null ? '${widget.category!.toUpperCase()} EXPENSES' : 'SITE EXPENSES'))
          : Text('${_selectedExpenseIds.length} SELECTED'),
        leading: _selectedExpenseIds.isNotEmpty 
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _selectedExpenseIds.clear()),
            )
          : null,
        actions: [
          if (_selectedExpenseIds.isNotEmpty) ...[
             IconButton(
               icon: const Icon(Icons.select_all),
               tooltip: 'Select All Unpaid',
               onPressed: () {
                  final data = Provider.of<DataProvider>(context, listen: false);
                  // Identify which items are visible and unpaid in current tab
                  List<Map<String, dynamic>> items = [];
                  if (widget.category == 'Labour') {
                    items = data.allLabour;
                  } else if (widget.category == 'Other') items = data.allSiteExpenses.where((e) => e['category'] == 'Other').toList();
                  else if (widget.category == null) {
                     if (_tabController.index == 0) {
                       items = data.allLabour;
                     } else if (_tabController.index == 2) items = data.allSiteExpenses.where((e) => e['category'] == 'Other').toList();
                  }

                  setState(() {
                    for (var item in items) {
                      final id = item['id'].toString();
                      bool isPaid = false;
                      if (item['isLabourEntry'] == true) {
                        isPaid = _parseAmount(item['balance']) <= 0;
                      } else {
                        isPaid = item['status'] == StatusType.paid || item['status'] == 'Paid';
                      }
                      if (!isPaid) _selectedExpenseIds.add(id);
                    }
                  });
               },
             ),
             IconButton(
               icon: const Icon(Icons.payment),
               tooltip: 'Pay Selected',
               onPressed: () => _showBulkPayDialog(context),
             ),
          ]
        ],
        bottom: widget.category == 'Vehicle'
          ? TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: JarvisTheme.secondary,
              tabs: const [
                Tab(text: 'EXPENSES'),
                Tab(text: 'BUNKS'),
                Tab(text: 'MECHANICS'),
              ],
            )
          : (widget.category == null ? TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: JarvisTheme.secondary,
              tabs: const [
                Tab(text: 'LABOUR'),
                Tab(text: 'VEHICLE & MATERIAL'),
                Tab(text: 'OTHER'),
              ],
            ) : null),
      ),
      floatingActionButton: AppConfig.isReadOnly ? null : FloatingActionButton(
        onPressed: () {
            if (widget.category == 'Vehicle') {
               if (_tabController.index == 0) {
                 // OPEN VEHICLE ENTRY SCREEN
                 // OPEN OLD EXPENSE DIALOG
                 _showAddExpenseDialog(
                   context, 
                   initialCategory: 'Vehicle', 
                   initialSite: _selectedSite != 'All Sites' ? _selectedSite : null,
                   initialVehicle: _selectedVehicle != 'All Vehicles' ? _selectedVehicle : null,
                 );
               } else if (_tabController.index == 1) {
                 _showAddBunkDialog(context);
               } else {
                 _showAddMechanicDialog(context);
               }
               return;
            }

            String category = widget.category ?? 'Labour';
            if (widget.category == null) {
              if (_tabController.index == 1) {
                 // Vehicle Tab in Main View also opens Vehicle Entry
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => AddVehiclePaymentScreen(
                       isOwn: false,
                       initialSite: _selectedSite != 'All Sites' ? _selectedSite : null,
                     ),
                   ),
                 );
                 return;
              }
              if (_tabController.index == 2) category = 'Other';
            }
            _showAddExpenseDialog(context, initialCategory: category, initialSite: _selectedSite);
        },
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          if (widget.category == 'Vehicle') {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildExpenseViewContent(context, data),
                _buildBunkViewContent(context, data),
                _buildMechanicViewContent(context, data),
              ],
            );
          }
          
          return _buildExpenseViewContent(context, data);
        },
      ),
    );
  }

  // Helper method to show add supplier dialog
  void _showAddSupplierDialog(BuildContext context, {Map<String, dynamic>? supplier}) {
    final nameController = TextEditingController(text: supplier != null ? supplier['name'] : '');
    final contactController = TextEditingController(text: supplier != null ? supplier['contact'] : '');
    
    // Support multiple materials
    List<TextEditingController> materialControllers = [];
    if (supplier != null && supplier['material'] != null) {
      final materials = supplier['material'].toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (materials.isEmpty) {
        materialControllers.add(TextEditingController());
      } else {
        for (var m in materials) {
          materialControllers.add(TextEditingController(text: m));
        }
      }
    } else {
      materialControllers.add(TextEditingController());
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(supplier != null ? 'Edit Supplier' : 'Add Supplier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Supplier Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                const Text('Materials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 8),
                ...materialControllers.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var controller = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Material ${idx + 1}',
                              isDense: true,
                            ),
                          ),
                        ),
                        if (materialControllers.length > 1) 
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() => materialControllers.removeAt(idx));
                            },
                          ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () {
                    setState(() => materialControllers.add(TextEditingController()));
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Another Material', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
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
                final name = nameController.text.trim();
                final contact = contactController.text.trim();
                final materials = materialControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).join(', ');
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter supplier name')),
                  );
                  return;
                }
                if (materials.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter at least one material')),
                  );
                  return;
                }

                final data = Provider.of<DataProvider>(context, listen: false);
                if (contact.isNotEmpty) {
                  final duplicateContact = data.suppliers.any((s) => 
                    s['id'] != supplier?['id'] && 
                    s['contact'] != null &&
                    s['contact'].toString().trim() == contact
                  );
                  if (duplicateContact) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('A supplier with contact number "$contact" already exists'),
                        backgroundColor: Colors.red,
                      )
                    );
                    return;
                  }
                } else {
                  final duplicateName = data.suppliers.any((s) => 
                    s['id'] != supplier?['id'] && 
                    (s['name'] ?? '').toString().trim().toLowerCase() == name.toLowerCase()
                  );
                  if (duplicateName) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('A supplier with name "$name" already exists! Please enter a unique name.'),
                        backgroundColor: Colors.red,
                      )
                    );
                    return;
                  }
                }

                final newData = {
                  'name': name,
                  'contact': contact,
                  'material': materials,
                };

                try {
                  if (supplier != null) {
                    await data.updateSupplier(supplier['id'], newData);
                  } else {
                    await data.addSupplier({
                      ...newData,
                      'total': '₹0',
                      'paid': '₹0',
                      'balance': '₹0',
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show supplier payment dialog
  void _showSupplierPaymentDialog(BuildContext context, Map<String, dynamic> supplier) {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isDiscount = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current Balance: ${supplier['balance']}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
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
              const Divider(),
              SwitchListTile(
                title: const Text('Is this a Discount?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                value: isDiscount,
                activeColor: Colors.orange,
                subtitle: const Text('Discount allowed by Supplier - reduces balance without paying cash', style: TextStyle(fontSize: 11)),
                onChanged: (val) => setState(() => isDiscount = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                   try {
                     await Provider.of<DataProvider>(context, listen: false).recordSupplierPayment(
                        supplier['id'], 
                        amount, 
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        isDiscount: isDiscount,
                        notes: isDiscount ? 'Discount Allowed' : 'Payment Made',
                     );
                     if (context.mounted) {
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDiscount ? 'Discount Recorded' : 'Payment Recorded')));
                     }
                   } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                   }
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show add bunk dialog (fuel supplier)
  void _showAddBunkDialog(BuildContext context) {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Bunk'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Bunk Name *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
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
              final name = nameController.text.trim();
              final contact = contactController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter bunk name')),
                );
                return;
              }
              final data = Provider.of<DataProvider>(context, listen: false);
              if (contact.isNotEmpty) {
                final duplicateContact = data.suppliers.any((s) =>
                  s['contact'] != null && s['contact'].toString().trim() == contact
                );
                if (duplicateContact) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('A bunk/supplier with contact number "$contact" already exists'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } else {
                final duplicateName = data.suppliers.any((s) =>
                  s['name'] != null && s['name'].toString().trim().toLowerCase() == name.toLowerCase()
                );
                if (duplicateName) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('A bunk/supplier with name "$name" already exists! Please enter a unique name.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              data.addSupplier({
                'name': name,
                'contact': contact,
                'material': 'Fuel', // Pre-set material to Fuel for bunks
                'total': '₹0',
                'paid': '₹0',
                'balance': '₹0',
              });
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildBunkViewContent(BuildContext context, DataProvider data) {
    // Filter suppliers to show only fuel-related bunks
    final bunks = data.suppliers.where((s) {
      final material = (s['material'] ?? '').toString().toLowerCase();
      return material.contains('fuel') || material.contains('petrol') || material.contains('diesel');
    }).toList();

    if (bunks.isEmpty) {
      return const Center(
        child: Text(
          'No bunks found.\nAdd fuel suppliers using the + button.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bunks.length,
      itemBuilder: (context, index) {
        final supplier = bunks[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SupplierDetailScreen(supplier: supplier),
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
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
                          Text(supplier['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
                          if (supplier['material'] != null)
                             Text(supplier['material'], style: const TextStyle(fontSize: 12, color: JarvisTheme.textSecondary)),
                        ],
                      ),
                      Row(
                         children: [
                           _buildInfo('Balance', '₹${_parseAmount(supplier['balance']).toInt()}', color: JarvisTheme.statusPending),
                           const SizedBox(width: 8),
                           TextButton(
                             onPressed: () {
                               _showHistoryDialog(context, supplier['id'], supplier['name']);
                             },
                             child: const Text('VIEW LEDGER'),
                           ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'payment') {
                                  _showSupplierPaymentDialog(context, supplier);
                                } else if (value == 'edit') {
                                  _showAddSupplierDialog(context, supplier: supplier);
                                } else if (value == 'delete') {
                                  _confirmAndDeleteSupplier(context, data, supplier);
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(value: 'payment', child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Add Payment')])),
                                const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                              ],
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            ),
                         ],
                      ),
                    ],
                   ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmAndDeleteSupplier(BuildContext context, DataProvider data, Map<String, dynamic> supplier) {
    final sName = supplier['name'] ?? 'Supplier';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('Are you sure you want to delete supplier "$sName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              data.deleteSupplier(supplier['id']);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Supplier "$sName" deleted')),
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageTankCard(BuildContext context, DataProvider outerData) {
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        final double liters = data.mainTankLiters;
        final bool isLow = liters < 100;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          color: isLow ? Colors.red.shade50 : Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isLow ? Colors.red.shade300 : Colors.blue.shade200,
              width: 1.5,
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageTankHistoryScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLow ? Colors.red.shade100 : Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.local_gas_station,
                      color: isLow ? Colors.red.shade700 : Colors.blue.shade800,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🛢️ Bulk Storage Tank',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isLow ? Colors.red.shade900 : Colors.blue.shade900,
                              ),
                            ),
                            if (isLow) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                                child: const Text('LOW STOCK', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${liters.toStringAsFixed(1)} Liters Available',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isLow ? Colors.red.shade900 : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StorageTankHistoryScreen()),
                      );
                    },
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('HISTORY'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isLow ? Colors.red.shade900 : Colors.blue.shade900,
                      side: BorderSide(color: isLow ? Colors.red.shade400 : Colors.blue.shade400),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => showDispenseFuelDialog(context, data),
                    icon: const Icon(Icons.local_gas_station, size: 16),
                    label: const Text('GIVE TO VEHICLE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JarvisTheme.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showIssueFuelDialog(BuildContext context, DataProvider data) {
    showDispenseFuelDialog(context, data);
  }



  void _showHistoryDialog(BuildContext context, String id, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => BunkLedgerScreen(supplierId: id, supplierName: name)));
  }

  void _showMechanicHistoryDialog(BuildContext context, String id, String name) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MechanicLedgerScreen(supplierId: id, supplierName: name)));
  }

  void _showAddMechanicDialog(BuildContext context) {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Mechanic'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Mechanic / Workshop Name *'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
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
              final name = nameController.text.trim();
              final contact = contactController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter mechanic name')),
                );
                return;
              }
              final data = Provider.of<DataProvider>(context, listen: false);
              if (contact.isNotEmpty) {
                final duplicateContact = data.suppliers.any((s) =>
                  s['contact'] != null && s['contact'].toString().trim() == contact
                );
                if (duplicateContact) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('A mechanic/supplier with contact number "$contact" already exists'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              } else {
                final duplicateName = data.suppliers.any((s) =>
                  s['name'] != null && s['name'].toString().trim().toLowerCase() == name.toLowerCase()
                );
                if (duplicateName) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('A mechanic/supplier with name "$name" already exists! Please enter a unique name.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
              }

              data.addSupplier({
                'name': name,
                'contact': contact,
                'material': 'Mechanic',
                'total': '₹0',
                'paid': '₹0',
                'balance': '₹0',
              });
              Navigator.pop(context);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicViewContent(BuildContext context, DataProvider data) {
    final mechanics = data.suppliers.where((s) {
      final material = (s['material'] ?? '').toString().toLowerCase();
      return material.contains('mechanic') || material.contains('workshop') || material.contains('garage');
    }).toList();

    if (mechanics.isEmpty) {
      return const Center(
        child: Text(
          'No mechanics found.\\nAdd mechanics using the + button.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: mechanics.length,
      itemBuilder: (context, index) {
        final supplier = mechanics[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
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
                        Text(supplier['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
                        if (supplier['material'] != null)
                           Text(supplier['material'], style: const TextStyle(fontSize: 12, color: JarvisTheme.textSecondary)),
                      ],
                    ),
                    Row(
                       children: [
                         _buildInfo('Balance', '₹${_parseAmount(supplier['balance']).toInt()}', color: JarvisTheme.statusPending),
                         const SizedBox(width: 8),
                         TextButton(
                           onPressed: () {
                             _showMechanicHistoryDialog(context, supplier['id'], supplier['name']);
                           },
                           child: const Text('VIEW LEDGER'),
                         ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'payment') {
                                _showSupplierPaymentDialog(context, supplier);
                              } else if (value == 'edit') {
                                _showAddSupplierDialog(context, supplier: supplier);
                              } else if (value == 'delete') {
                                _confirmAndDeleteSupplier(context, data, supplier);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(value: 'payment', child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Add Payment')])),
                              const PopupMenuItem<String>(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')])),
                              const PopupMenuItem<String>(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                            ],
                            icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          ),
                       ],
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

  // Helper method for Bunk View
  Widget _buildInfo(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: JarvisTheme.textSecondary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color ?? JarvisTheme.textPrimary)),
      ],
    );
  }

  // Existing Expense Logic wrapped in a method
  Widget _buildExpenseViewContent(BuildContext context, DataProvider data) {
          // Filter Data
          List<Map<String, dynamic>> filteredExpenses = data.allSiteExpenses;
          
          // 1. Filter by Site
          if (_selectedSite != 'All Sites') {
            filteredExpenses = filteredExpenses.where((e) => e['site'] == _selectedSite).toList();
          }

          // 2. Filter by Date Range
          if (_selectedDateRange != null) {
            filteredExpenses = filteredExpenses.where((e) {
               try {
                 DateTime date = DateFormat('dd MMM yyyy').parse(e['date']);
                 return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                        date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
               } catch (e) {
                 return false;
               }
            }).toList();
          } else if (widget.category != 'Vehicle') {
            // Default to Global Selected Date ONLY for Site Expenses, 
            // but show ALL history for Maintenance & Fuel Dashboard by default.
            filteredExpenses = filteredExpenses.where((e) {
              return e['date'] == data.formattedSelectedDate || (e['date'] == 'Today' && data.formattedSelectedDate == DateFormat('dd MMM yyyy').format(DateTime.now()));
            }).toList();
          }

          // Prepare Unified Lists for tabs
          List<Map<String, dynamic>> labourItems = [];
          List<Map<String, dynamic>> vehicleMaterialItems = [];
          List<Map<String, dynamic>> otherItems = [];

          // 1. From site_expenses (filtered)
          for (var e in filteredExpenses) {
            String cat = e['category'] ?? 'Other';
            if (cat == 'Labour') {
              labourItems.add(e);
            } else if (cat == 'Vehicle' || cat == 'Material') {
              final title = (e['title'] ?? '').toString().toLowerCase();
              bool isFuelOrMaintenance = title.contains('fuel') || title.contains('maintenance') || title.contains('repair');
              
              if (widget.category == null && isFuelOrMaintenance) {
                // EXCLUDE FROM GENERAL VIEW
              } else {
                vehicleMaterialItems.add(e);
              }
            } else {
              otherItems.add(e);
            }
          }

          // 2. Merge Vehicle Entries into Vehicle & Material tab
          List<Map<String, dynamic>> vehicleEntries = data.allVehicles;
          if (widget.category == 'Vehicle') {
             // EXCLUDE OWN VEHICLE RENTAL ENTRIES
             // AND ONLY SHOW FUEL/MECHANIC ENTRIES (exclude Steel, Cement, etc.)
             final allowedKeywords = ['fuel', 'diesel', 'petrol', 'mechanic', 'workshop', 'service', 'repair', 'maintenance', 'oil', 'grease', 'tyre', 'spare'];
             
             vehicleEntries = vehicleEntries.where((e) {
                final isOwn = e['isOwn'] == true || e['isOwn'] == 1;
                final matAmt = _parseAmount(e['material_amount']);
                if (isOwn || matAmt <= 0) return false;
                
                final materialName = (e['material_name'] ?? '').toString().toLowerCase();
                final supplierName = (e['supplier'] ?? '').toString().toLowerCase();
                
                // Check if any keyword matches the material name
                bool isFuelOrMechanic = allowedKeywords.any((keyword) => materialName.contains(keyword));
                
                // Also check if the supplier is a known bunk or mechanic by look up
                if (!isFuelOrMechanic) {
                   final supplier = data.suppliers.firstWhere((s) => s['name'] == supplierName, orElse: () => {});
                   if (supplier.isNotEmpty) {
                      final supMat = (supplier['material'] ?? '').toString().toLowerCase();
                      isFuelOrMechanic = allowedKeywords.any((keyword) => supMat.contains(keyword));
                   }
                }
                
                return isFuelOrMechanic;
             }).toList();
          }
          if (_selectedSite != 'All Sites') vehicleEntries = vehicleEntries.where((e) => e['site'] == _selectedSite).toList();
          if (_selectedVehicle != 'All Vehicles') vehicleEntries = vehicleEntries.where((e) => e['number'] == _selectedVehicle).toList();
          if (_selectedDateRange != null) {
            vehicleEntries = vehicleEntries.where((e) {
              try {
                DateTime date = DateFormat('dd MMM yyyy').parse(e['date']);
                return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                       date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
              } catch (_) { return false; }
            }).toList();
          } else if (widget.category != 'Vehicle') {
            vehicleEntries = vehicleEntries.where((e) => e['date'] == data.formattedSelectedDate).toList();
          }
          vehicleMaterialItems.addAll(vehicleEntries.map((v) => {...v, 'isVehicleEntry': true}));

          // 3. Labour transactions are already in labourItems from filteredExpenses (site_expenses)
          // We don't merge the master labour table here to avoid double-counting balances.
          // Master workers and their total owed are managed in the Reports/Ledger.
          List<Map<String, dynamic>> labourTableEntries = [];
          labourItems.addAll(labourTableEntries.map((l) => {...l, 'isLabourEntry': true}));

          if (widget.category == 'Vehicle' && _selectedVehicle != 'All Vehicles') {
             vehicleMaterialItems = vehicleMaterialItems.where((e) => e['vehicle_no'] == _selectedVehicle).toList();
          }

          // Calculate visible total for current tab
          double visibleTotal = 0;
          List<Map<String, dynamic>> currentTabItems = [];
          
          if (widget.category != null) {
            // Fixed Category View
            if (widget.category == 'Labour') {
              currentTabItems = labourItems;
            } else if (widget.category == 'Vehicle' || widget.category == 'Material') {
              currentTabItems = vehicleMaterialItems;
            } else {
              currentTabItems = otherItems;
            }
          } else {
            // Main Multi-tab View
            int currentTabIndex = _tabController.index;
            if (currentTabIndex == 0) {
              currentTabItems = labourItems;
            } else if (currentTabIndex == 1) {
              currentTabItems = vehicleMaterialItems;
            } else {
              currentTabItems = otherItems;
            }
          }

          for (var item in currentTabItems) {
            final supplier = (item['supplier'] ?? '').toString().trim();
            final title = (item['title'] ?? '').toString().trim();
            bool isInternalIssue = supplier == 'Storage Tank' || 
                                   title.contains('Tank Dispense') || 
                                   item['is_internal_issue'] == 1 || 
                                   item['is_internal_issue'] == '1';
            if (isInternalIssue) continue;

            if (item['isVehicleEntry'] == true) {
              visibleTotal += _parseAmount(item['total']);
            } else if (item['isLabourEntry'] == true) {
              visibleTotal += _parseAmount(item['advance']) + _parseAmount(item['balance']);
            } else {
              visibleTotal += _parseAmount(item['amount']);
            }
          }

          return Column(
            children: [
              if (widget.category == 'Vehicle')
                _buildStorageTankCard(context, data),
              // Filters
              Container(
                padding: const EdgeInsets.all(12),
                color: JarvisTheme.surface,
                child: Row(
                  children: [
                    Expanded(
                      child: widget.category == 'Vehicle' 
                      ? Builder(
                          builder: (context) {
                             final vehicles = ['All Vehicles', ...data.vehicleRegistry.map((e) => e['number'] as String? ?? '').where((s) => s.isNotEmpty).toSet()];
                             final safeValue = vehicles.contains(_selectedVehicle) ? _selectedVehicle : 'All Vehicles';
                             return DropdownButtonFormField<String>(
                                initialValue: safeValue,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  labelText: 'Filter by Vehicle',
                                ),
                                items: vehicles.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                onChanged: (val) => setState(() => _selectedVehicle = val!),
                             );
                          }
                        )
                      : DropdownButtonFormField<String>(
                        initialValue: _selectedSite,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          labelText: 'Filter by Site',
                        ),
                        items: () {
                           final sites = ['All Sites', ...data.activeSites];
                           if (_selectedSite != 'No Active Sites' && !sites.contains(_selectedSite)) {
                              sites.add(_selectedSite);
                           }
                           return sites.toSet().toList().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList();
                        }(),
                        onChanged: (val) => setState(() => _selectedSite = val!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDateRange != null)
                      IconButton(
                        onPressed: () => setState(() =>_selectedDateRange = null),
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Clear Date Range',
                      ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDateRange: _selectedDateRange,
                        );
                        if (picked != null) {
                          setState(() => _selectedDateRange = picked);
                        }
                      },
                      icon: Icon(
                        Icons.date_range,
                        size: 18,
                        color: _selectedDateRange != null ? JarvisTheme.secondary : Colors.white,
                      ),
                      label: Text(
                        _selectedDateRange != null 
                          ? '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM').format(_selectedDateRange!.end)}'
                          : 'Select Date Range',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedDateRange != null ? JarvisTheme.secondary : Colors.white,
                        foregroundColor: _selectedDateRange != null ? Colors.black : JarvisTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: BorderSide(color: _selectedDateRange != null ? JarvisTheme.secondary : Colors.grey.shade300),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
              
              // List
              Expanded(
                child: widget.category != null
                    ? _buildUnifiedExpenseList(currentTabItems, data)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUnifiedExpenseList(labourItems, data),
                          _buildUnifiedExpenseList(vehicleMaterialItems, data),
                          _buildUnifiedExpenseList(otherItems, data),
                        ],
                      ),
              ),

              // Total Sticky Bottom
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 80, 16), // Added right padding for FAB
                decoration: BoxDecoration(
                  color: JarvisTheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL EXPENSE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${visibleTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedExpenseIds.isNotEmpty)
                       ElevatedButton.icon(
                         onPressed: () => _showBulkPayDialog(context),
                         icon: const Icon(Icons.payment, size: 16),
                         label: Text('PAY ${_selectedExpenseIds.length}'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green,
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(horizontal: 12),
                         ),
                       ),
                  ],
                ),
              ),
            ],
          );
  }

  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is! String) return 0.0;
    String clean = amount.replaceAll('₹', '').replaceAll(',', '').trim();
    return double.tryParse(clean) ?? 0.0;
  }


  Widget _buildUnifiedExpenseList(List<Map<String, dynamic>> items, DataProvider data) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No entries found', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    // Sort items by date (descending)
    items.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date'] ?? '01 Jan 2000');
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date'] ?? '01 Jan 2000');
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });

    final suppliers = items
        .where((i) => i['supplier'] != null && i['supplier'].toString().isNotEmpty)
        .map((i) => i['supplier'].toString().trim())
        .toSet()
        .toList();

    return FutureBuilder<Map<String, Set<String>>>(
      future: () async {
        Map<String, Set<String>> results = {};
        for (var s in suppliers) {
          results[s] = await data.getSupplierUnpaidIds(s);
        }
        return results;
      }(),
      builder: (context, snapshot) {
        final unpaidMap = snapshot.data ?? {};
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting && suppliers.isNotEmpty;

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final String id = item['id'].toString();
                final bool isSelected = _selectedExpenseIds.contains(id);
                final String supplier = item['supplier']?.toString().trim() ?? '';
                final bool isOwn = item['isOwn'] == true || item['isOwn'] == 1;

                Widget card;

                if (item['isVehicleEntry'] == true) {
                  bool isPaidV = false;
                  if (supplier.isNotEmpty && unpaidMap.containsKey(supplier)) {
                    isPaidV = !unpaidMap[supplier]!.contains(item['id'].toString());
                  } else if (isOwn) {
                    isPaidV = item['status'] == StatusType.paid || item['status'] == 'Paid';
                  } else {
                    isPaidV = item['status'] == StatusType.paid || item['status'] == 'Paid';
                  }

                  card = Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                        child: Icon(isOwn ? Icons.local_shipping : Icons.time_to_leave, color: Colors.blue),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['number'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item['total'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: JarvisTheme.primary)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (_parseAmount(item['rent_amount']) > 0)
                            Text('${item['rate_type']} Basis: ${item['duration']} @ ₹${item['rate']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          if (item['material_name'] != null && item['material_name'].isNotEmpty)
                            Text('Material: ${item['material_name']} (${item['quantity']} ${item['unit']}) - ${item['supplier'] ?? ''}', 
                                 style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(item['date'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              const Spacer(),
                              StatusChip(
                                type: isPaidV ? StatusType.paid : StatusType.pending,
                                label: isPaidV ? 'PAID' : 'PENDING',
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: isOwn, vehicle: item)),
                        );
                      },
                    ),
                  );
                } else if (item['isLabourEntry'] == true) {
                  double labTotal = _parseAmount(item['advance']) + _parseAmount(item['balance']);
                  card = Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.person, color: Colors.green),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('₹${labTotal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Type: ${item['type']} | Advance: ${item['advance']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('Balance: ${item['balance']}', style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              StatusChip(
                                type: _parseAmount(item['balance']) <= 0 ? StatusType.paid : StatusType.pending,
                                label: _parseAmount(item['balance']) <= 0 ? 'CLEARED' : 'OWED',
                              ),
                            ],
                          ),
                        ],
                      ),
                          trailing: (AppConfig.isReadOnly || _selectedExpenseIds.isNotEmpty)
                          ? (AppConfig.isReadOnly ? null : Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedExpenseIds.add(id);
                                  } else {
                                    _selectedExpenseIds.remove(id);
                                  }
                                });
                              },
                            ))
                          : PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'pay') {
                                   _showLabourPaymentDialog(context, item);
                                } else if (value == 'history') {
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => LabourLedgerScreen(workerName: item['name'])));
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Add Payment')])),
                                const PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 18, color: Colors.blue), SizedBox(width: 8), Text('History')])),
                              ],
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            ),
                    ),
                  );
                } else {
                  // 3. STANDARD EXPENSE STYLE
                  bool isPaidE = false;
                  if (supplier.isNotEmpty && unpaidMap.containsKey(supplier)) {
                    isPaidE = !unpaidMap[supplier]!.contains(item['id'].toString());
                  } else {
                    isPaidE = item['status'] == StatusType.paid || item['status'] == 'Paid';
                  }

                  final String eTitleRaw = item['title'] ?? 'Untitled Expense';
                  final String eTitle = eTitleRaw.trim().replaceAll(RegExp(r':\s*$'), '');
                  String ePrefix = '';
                  if (eTitleRaw.contains(':')) {
                    ePrefix = eTitleRaw.split(':')[0].trim();
                  }

                  card = Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(eTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(item['date'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                if (item['vehicle_no'] != null && item['category'] == 'Vehicle')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(item['vehicle_no'], style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                          if (supplier.isNotEmpty)
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ePrefix.toLowerCase() == 'fuel' ? 'Bunk' : 'Supplier', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  Text(supplier, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                ],
                              ),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(item['amount'] ?? '₹0', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              StatusChip(
                                type: isPaidE ? StatusType.paid : StatusType.pending,
                                label: isPaidE ? 'PAID' : 'PENDING',
                              ),
                            ],
                          ),
                          if (!AppConfig.isReadOnly)
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final String expId = (item['id'] ?? '').toString();
                                  final String supplier = (item['supplier'] ?? '').toString().trim();
                                  final String title = (item['title'] ?? '').toString().trim();
                                  bool isTankDispense = expId.startsWith('EXP_TANK_') || 
                                                        supplier == 'Storage Tank' || 
                                                        title.contains('Tank Dispense') ||
                                                        item['is_internal_issue'] == 1 ||
                                                        item['is_internal_issue'] == '1';

                                  if (isTankDispense) {
                                    showDispenseFuelDialog(context, data, existingExpense: item);
                                  } else {
                                    _showAddExpenseDialog(context, expense: item);
                                  }
                                } else if (value == 'pay') {
                                  _showAddPaymentDialog(context, item);
                                } else if (value == 'ledger') {
                                  if (item['category'] == 'Labour') {
                                     Navigator.push(context, MaterialPageRoute(builder: (_) => LabourLedgerScreen(workerName: item['title'] ?? 'AA')));
                                  } else {
                                     Navigator.push(context, MaterialPageRoute(builder: (_) => OtherLedgerScreen(title: item['title'] ?? 'Other')));
                                  }
                                } else if (value == 'delete') {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text('Are you sure you want to delete this expense?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    final itemId = (item['id'] ?? '').toString();
                                    if (item['isVehicleEntry'] == true) {
                                      await data.deleteVehicle(itemId);
                                    } else {
                                      await data.deleteExpense(itemId);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Expense deleted successfully')),
                                      );
                                    }
                                  }
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isPaidE) const PopupMenuItem(value: 'pay', child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Add Payment')])),
                                if (item['category'] == 'Labour') const PopupMenuItem(value: 'ledger', child: Row(children: [Icon(Icons.history, size: 18, color: Colors.blue), SizedBox(width: 8), Text('View Ledger')])),
                                if (item['category'] == 'Other') const PopupMenuItem(value: 'ledger', child: Row(children: [Icon(Icons.history, size: 18, color: Colors.blue), SizedBox(width: 8), Text('View Ledger')])),
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.orange), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                              ],
                              icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                final bool canSelect = item['isLabourEntry'] == true || (item['category'] == 'Labour' || item['category'] == 'Other');
                if (!canSelect) return card;

                return GestureDetector(
                  onLongPress: () {
                    setState(() {
                      if (isSelected) {
                        _selectedExpenseIds.remove(id);
                      } else {
                        _selectedExpenseIds.add(id);
                      }
                    });
                  },
                  child: Stack(
                    children: [
                      card,
                      if (_selectedExpenseIds.isNotEmpty)
                        Positioned(
                          top: 5,
                          right: 5,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedExpenseIds.add(id);
                                } else {
                                  _selectedExpenseIds.remove(id);
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            if (isLoading)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showAddPaymentDialog(BuildContext context, Map<String, dynamic> expense) {
    final amountController = TextEditingController();
    double total = _parseAmount(expense['amount']);
    double paid = _parseAmount(expense['paid']);
    double pending = total - paid;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total: ₹${total.toInt()}  Paid: ₹${paid.toInt()}'),
              const SizedBox(height: 8),
              Text('Pending Balance: ₹${pending.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Payment Amount (₹)', isDense: true, border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                double? payAmt = double.tryParse(amountController.text);
                if (payAmt != null && payAmt > 0) {
                  if (payAmt > pending) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount cannot exceed pending balance!')));
                    return;
                  }
                  
                  await Provider.of<DataProvider>(context, listen: false).addExpensePayment(expense['id'], {
                    'amount': '₹${payAmt.toInt()}',
                    'date': DateFormat('dd MMM yyyy').format(selectedDate),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('PAY'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLabourPaymentDialog(BuildContext context, Map<String, dynamic> labour) {
    final amountController = TextEditingController();
    double balance = _parseAmount(labour['balance']);
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Pay ${labour['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Outstanding Balance: ₹${balance.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Payment Amount (₹)', isDense: true, border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                double? payAmt = double.tryParse(amountController.text);
                if (payAmt != null && payAmt > 0) {
                  await Provider.of<DataProvider>(context, listen: false).addLabourPayment(
                    labour['id'], 
                    payAmt, 
                    DateFormat('dd MMM yyyy').format(selectedDate),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('PAY'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkPayDialog(BuildContext context) {
    final amountController = TextEditingController();
    final data = Provider.of<DataProvider>(context, listen: false);
    double totalSelected = 0;
    
    // Calculate total from selected IDs
    for (var id in _selectedExpenseIds) {
       // Search in all categories
       var item = data.siteExpenses.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
       if (item.isEmpty) {
          item = data.allLabour.firstWhere((l) => l['id'].toString() == id, orElse: () => {});
       }
       
       if (item.isNotEmpty) {
          if (item['isLabourEntry'] == true) {
             totalSelected += _parseAmount(item['balance']);
          } else {
             totalSelected += _parseAmount(item['amount']) - _parseAmount(item['paid']);
          }
       }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ${_selectedExpenseIds.length} Selected Items'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total Outstanding: ₹${totalSelected.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            const Text('This will mark all selected items as PAID.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              for (var id in _selectedExpenseIds) {
                 var item = data.siteExpenses.firstWhere((e) => e['id'].toString() == id, orElse: () => {});
                 if (item.isEmpty) {
                    item = data.allLabour.firstWhere((l) => l['id'].toString() == id, orElse: () => {});
                 }
                 
                 if (item.isNotEmpty) {
                    if (item['isLabourEntry'] == true) {
                       await data.addLabourPayment(
                         item['id'], 
                         _parseAmount(item['balance']), 
                         DateFormat('dd MMM yyyy').format(DateTime.now()),
                       );
                    } else {
                       double pending = _parseAmount(item['amount']) - _parseAmount(item['paid']);
                       await data.addExpensePayment(item['id'], {
                          'amount': '₹${pending.toInt()}',
                          'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
                       });
                    }
                 }
              }
              setState(() => _selectedExpenseIds.clear());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('PAY ALL SELECTED'),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, {Map<String, dynamic>? expense, String? initialCategory, String? initialVehicle, String? initialSite}) {
    final titleController = TextEditingController(text: expense != null ? expense['title'] : '');
    final supplierController = TextEditingController(text: expense != null ? (expense['supplier'] ?? '') : '');
    final totalAmountController = TextEditingController(text: expense != null ? (expense['amount'] as String).replaceAll('₹', '').replaceAll(',', '') : '');
    final paidAmountController = TextEditingController(text: expense != null ? (expense['paid'] as String).replaceAll('₹', '').replaceAll(',', '') : '');
    final manualVehicleController = TextEditingController(text: expense != null ? (expense['vehicle_no'] ?? '') : (initialVehicle ?? ''));
    final expenseTypeController = TextEditingController(text: expense != null ? (expense['title']?.toString().split(':')[0] ?? 'Fuel') : 'Fuel');
    final descriptionController = TextEditingController(text: expense != null ? (expense['material_name'] ?? '') : '');
    final quantityController = TextEditingController(text: expense != null ? (expense['quantity'] ?? '') : '');
    final rateController = TextEditingController(
      text: expense != null && expense['rate'] != null 
          ? expense['rate'].toString() 
          : (expense != null && double.tryParse(expense['quantity'] ?? '') != null && double.tryParse((expense['amount'] as String).replaceAll('₹', '').replaceAll(',', '')) != null && (double.tryParse(expense['quantity'] ?? '') ?? 0) > 0
              ? ((double.tryParse((expense['amount'] as String).replaceAll('₹', '').replaceAll(',', ''))! / double.parse(expense['quantity'])).toStringAsFixed(2))
              : '')
    );

    String selectedCategory = initialCategory ?? (expense != null ? (expense['category'] ?? 'Labour') : 'Labour');
    String selectedSite = initialSite ?? (expense != null ? (expense['site'] ?? _selectedSite) : (_selectedSite != 'All Sites' ? _selectedSite : ''));
    String? selectedVehicleId;
    DateTime selectedDate = expense != null ? DateFormat('dd MMM yyyy').parse(expense['date']) : DateTime.now();
    bool titleError = false;
    bool amountError = false;

    final focusNodeTitle = FocusNode();
    final focusNodeSupplier = FocusNode();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
          title: Text(expense != null ? 'Edit Expense' : 'Add Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedCategory != 'Vehicle') ...[
                  if (selectedCategory == 'Labour' || selectedCategory == 'Other') 
                    Consumer<DataProvider>(
                      builder: (context, data, child) {
                         // Get dynamic options based on category
                         final Set<String> uniqueOptions = {};
                         if (selectedCategory == 'Labour') {
                            uniqueOptions.addAll(data.allLabour.map((l) => l['name'].toString()));
                            uniqueOptions.addAll(data.allSiteExpenses
                                .where((e) => e['category'] == 'Labour')
                                .map((e) => e['title'].toString()));
                         } else if (selectedCategory == 'Other') {
                            uniqueOptions.addAll(data.allSiteExpenses
                                .where((e) => e['category'] == 'Other')
                                .map((e) => e['title'].toString()));
                         }
                         
                         final List<String> options = uniqueOptions.where((s) => s.isNotEmpty).toList();
                         options.sort();

                         return Autocomplete<String>(
                            textEditingController: titleController,
                            focusNode: focusNodeTitle,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                               if (textEditingValue.text == '') return const Iterable<String>.empty();
                               return options.where((String option) {
                                 return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                               });
                            },
                            onSelected: (String selection) {
                               titleController.text = selection;
                            },
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                               return TextField(
                                 controller: controller,
                                 focusNode: focusNode,
                                 decoration: InputDecoration(
                                   labelText: selectedCategory == 'Labour' ? 'Worker Name' : 'Title',
                                   errorText: titleError ? 'Required' : null,
                                   suffixIcon: options.isNotEmpty ? PopupMenuButton<String>(
                                     icon: const Icon(Icons.arrow_drop_down),
                                     onSelected: (String value) {
                                       controller.text = value;
                                       titleController.text = value;
                                     },
                                     itemBuilder: (BuildContext context) {
                                       return options.map((String choice) {
                                         return PopupMenuItem<String>(
                                           value: choice,
                                           child: Text(choice),
                                         );
                                       }).toList();
                                     },
                                   ) : null,
                                 ),
                               );
                            },
                         );
                      },
                    ),
                  if (selectedCategory == 'Other') ...[
                     const SizedBox(height: 12),
                     TextField(
                       controller: descriptionController,
                       decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                       maxLines: 2,
                     ),
                  ],

                  if (selectedCategory == 'Material')
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Material Name',
                        errorText: titleError ? 'Required' : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  if (selectedCategory == 'Labour') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Work Description (e.g. Digging / Centering)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
                if (selectedCategory == 'Material') ...[
                  const SizedBox(height: 12),
                  Consumer<DataProvider>(
                    builder: (context, data, child) {
                      final suppliers = data.generalSuppliers.map((s) => s['name'].toString()).toSet().toList();
                      return Autocomplete<String>(
                        textEditingController: supplierController,
                        focusNode: focusNodeSupplier,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                           if (textEditingValue.text == '') return const Iterable<String>.empty();
                           return suppliers.where((String option) {
                             return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                           });
                        },
                        onSelected: (String selection) {
                           supplierController.text = selection; 
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                           return TextField(
                             controller: controller,
                             focusNode: focusNode,
                             decoration: const InputDecoration(labelText: 'Supplier Name (Optional)'),
                           );
                        },
                      );
                    },
                  ),
                ],
                if (selectedCategory == 'Vehicle') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ['Fuel', 'Maintenance', 'Repair', 'Other'].contains(expenseTypeController.text) ? expenseTypeController.text : 'Fuel',
                    decoration: const InputDecoration(labelText: 'Expense Type', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
                    items: ['Fuel', 'Maintenance', 'Repair', 'Other']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        expenseTypeController.text = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  // Bunk / Mechanic Name
                  if (expenseTypeController.text == 'Fuel')
                    Consumer<DataProvider>(
                      builder: (context, data, child) {
                        // Get bunks (fuel suppliers)
                        final bunks = data.suppliers.where((s) {
                          final material = (s['material'] ?? '').toString().toLowerCase();
                          return material.contains('fuel') || material.contains('petrol') || material.contains('diesel');
                        }).map((s) => s['name'].toString()).toList();

                        // Add "Other" option for manual entry
                        final bunkOptions = ['Other', ...bunks];
                        
                        // Check if current text is a known bunk or 'Other', otherwise it implies custom entry (so we select 'Other')
                        String currentValue = bunkOptions.contains(supplierController.text) 
                            ? supplierController.text 
                            : 'Other';
                         
                        // If completely empty initially, default to first bunk or Other
                        if (supplierController.text.isEmpty && currentValue == 'Other' && bunks.isNotEmpty) {
                             currentValue = bunks.first;
                             // Defer update
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (supplierController.text.isEmpty) supplierController.text = currentValue;
                             });
                        }

                        return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             DropdownButtonFormField<String>(
                                initialValue: currentValue,
                                decoration: const InputDecoration(
                                  labelText: 'Select Bunk',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  isDense: true,
                                ),
                                items: bunkOptions.map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                )).toList(),
                                onChanged: (val) {
                                  setState(() {
                                     // If switching to Other, clear controller so user can type. 
                                     // If switching to a Bunk, set controller to that bunk.
                                     if (val == 'Other') {
                                        supplierController.clear();
                                     } else {
                                        supplierController.text = val!;
                                     }
                                  });
                                },
                              ),
                              if (currentValue == 'Other') ...[
                                 const SizedBox(height: 8),
                                 TextField(
                                    controller: supplierController,
                                    decoration: const InputDecoration(
                                       labelText: 'Enter Bunk Name',
                                       contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                       isDense: true,
                                    ),
                                 )
                              ]
                           ]
                        );
                      },
                    )
                  else if (expenseTypeController.text == 'Repair' || expenseTypeController.text == 'Maintenance')
                    Consumer<DataProvider>(
                      builder: (context, data, child) {
                        // Get mechanics
                        final mechanics = data.suppliers.where((s) {
                          final material = (s['material'] ?? '').toString().toLowerCase();
                          return material.contains('mechanic') || material.contains('workshop') || material.contains('garage');
                        }).map((s) => s['name'].toString()).toList();

                        // Add "Other" option for manual entry
                        final mechanicOptions = ['Other', ...mechanics];
                        
                        // Check if current text is known or 'Other' (custom -> Other)
                        String currentValue = mechanicOptions.contains(supplierController.text) 
                            ? supplierController.text 
                            : 'Other';

                        return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             DropdownButtonFormField<String>(
                                initialValue: currentValue,
                                decoration: const InputDecoration(
                                  labelText: 'Select Mechanic',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  isDense: true,
                                ),
                                items: mechanicOptions.map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                )).toList(),
                                onChanged: (val) {
                                  setState(() {
                                     // If switching to Other, clear controller so user can type. 
                                     // If switching to a mechanic, set controller to that.
                                     if (val == 'Other') {
                                        supplierController.clear();
                                     } else {
                                        supplierController.text = val!;
                                     }
                                  });
                                },
                              ),
                              if (currentValue == 'Other') ...[
                                 const SizedBox(height: 8),
                                 TextField(
                                    controller: supplierController,
                                    decoration: const InputDecoration(
                                       labelText: 'Enter Mechanic/Workshop Name',
                                       contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                       isDense: true,
                                    ),
                                 )
                              ]
                           ]
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Expense Description',
                      errorText: titleError ? 'Required' : null,
                       contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                       isDense: true
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<DataProvider>(
                    builder: (context, data, child) {
                      final registry = data.vehicleRegistry;
                       
                      // Initialize selectedVehicleId if editing
                      if (expense != null && selectedVehicleId == null && expense['vehicle_no'] != null) {
                         try {
                           final v = registry.firstWhere((e) => e['number'] == expense['vehicle_no']);
                           selectedVehicleId = v['id'];
                         } catch (_) {}
                      }

                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Target Vehicle / Storage', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
                        initialValue: selectedVehicleId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Manual Entry')),
                          const DropdownMenuItem(value: 'TANK_BULK_FUEL', child: Text('🛢️ Storage Tank (Bulk Fuel)')),
                          ...registry.map((v) => DropdownMenuItem(value: v['id'], child: Text('${v['number']} (${v['type']})')))
                        ],
                            onChanged: (val) {
                              setState(() {
                                selectedVehicleId = val;
                                // clear manual text if selecting a registry vehicle
                                if (val != null) {
                                   manualVehicleController.clear();
                                }
                              });
                            },
                      );
                    },
                  ),
                   if (selectedVehicleId == null) ...[
                      const SizedBox(height: 12),
                      TextField(
                         controller: manualVehicleController,
                         decoration: const InputDecoration(labelText: 'Vehicle Number (Manual)', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true),
                      ),
                   ],
                   if (expenseTypeController.text == 'Fuel' || selectedVehicleId == 'TANK_BULK_FUEL') ...[
                      const SizedBox(height: 12),
                      TextField(
                         controller: rateController,
                         decoration: const InputDecoration(
                           labelText: 'Rate per Liter (₹/L)', 
                           hintText: 'e.g. 94.50', 
                           contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                           isDense: true
                         ),
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         onChanged: (val) {
                           final r = double.tryParse(val);
                           final q = double.tryParse(quantityController.text);
                           final amt = double.tryParse(totalAmountController.text);
                           if (r != null && r > 0) {
                             if (q != null && q > 0) {
                               final calculatedAmt = (q * r).toStringAsFixed(2);
                               final cleanAmt = calculatedAmt.endsWith('.00') ? calculatedAmt.substring(0, calculatedAmt.length - 3) : calculatedAmt;
                               if (totalAmountController.text != cleanAmt) {
                                 totalAmountController.text = cleanAmt;
                               }
                             } else if (amt != null && amt > 0) {
                               final calculatedQty = (amt / r).toStringAsFixed(2);
                               final cleanQty = calculatedQty.endsWith('.00') ? calculatedQty.substring(0, calculatedQty.length - 3) : calculatedQty;
                               if (quantityController.text != cleanQty) {
                                 quantityController.text = cleanQty;
                               }
                             }
                           }
                         },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                         controller: quantityController,
                         decoration: const InputDecoration(
                           labelText: 'Fuel Purchased Liters (L)', 
                           hintText: 'e.g. 2000 Liters for Tank or 50 Liters for Vehicle', 
                           contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                           isDense: true
                         ),
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                         onChanged: (val) {
                           final q = double.tryParse(val);
                           final r = double.tryParse(rateController.text);
                           if (q != null && r != null && r > 0) {
                             final calculatedAmt = (q * r).toStringAsFixed(2);
                             final cleanAmt = calculatedAmt.endsWith('.00') ? calculatedAmt.substring(0, calculatedAmt.length - 3) : calculatedAmt;
                             if (totalAmountController.text != cleanAmt) {
                               totalAmountController.text = cleanAmt;
                             }
                           }
                         },
                      ),
                   ]
                ],
                // ... (Material logic remains filtered out by if) ...
                TextField(
                  controller: totalAmountController,
                  decoration: InputDecoration(
                    labelText: 'Total Amount (₹)',
                    errorText: amountError ? 'Enter a valid amount' : null,
                     contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                     isDense: true
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final amt = double.tryParse(val);
                    final r = double.tryParse(rateController.text);
                    final q = double.tryParse(quantityController.text);

                    if (amt != null && amt > 0) {
                      if (r != null && r > 0) {
                        final calculatedQty = (amt / r).toStringAsFixed(2);
                        final cleanQty = calculatedQty.endsWith('.00') ? calculatedQty.substring(0, calculatedQty.length - 3) : calculatedQty;
                        if (quantityController.text != cleanQty) {
                          quantityController.text = cleanQty;
                        }
                      } else if (q != null && q > 0) {
                        final calculatedRate = (amt / q).toStringAsFixed(2);
                        final cleanRate = calculatedRate.endsWith('.00') ? calculatedRate.substring(0, calculatedRate.length - 3) : calculatedRate;
                        if (rateController.text != cleanRate) {
                          rateController.text = cleanRate;
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: paidAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Paid Amount (₹)',
                    hintText: 'Leave same as total if fully paid',
                     contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), 
                     isDense: true
                  ),
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
                setState(() {
                  // Title is not required for Vehicle category (it's auto-generated)
                  titleError = selectedCategory != 'Vehicle' && titleController.text.isEmpty;
                  amountError = totalAmountController.text.isEmpty || double.tryParse(totalAmountController.text) == null;
                });

                if (!titleError && !amountError) {
                  try {
                    String paidVal = paidAmountController.text.isEmpty ? '0' : paidAmountController.text;
                    
                    // Vehicle Logic
                    String? vehicleNo;
                    String finalTitle = titleController.text;
                    String? finalSupplier = supplierController.text;

                    if (selectedCategory == 'Vehicle') {
                       if (selectedVehicleId == 'TANK_BULK_FUEL') {
                          vehicleNo = 'Storage Tank';
                          if (finalTitle.trim().isEmpty || finalTitle == 'Fuel: ') {
                             finalTitle = 'Bulk Diesel Storage Tank Purchase';
                          }
                       } else if (selectedVehicleId != null) {
                          final data = Provider.of<DataProvider>(context, listen: false);
                          final reg = data.vehicleRegistry.firstWhere((e) => e['id'] == selectedVehicleId);
                          vehicleNo = reg['number'];
                       } else {
                          vehicleNo = manualVehicleController.text;
                       }
                       
                       if (vehicleNo == null || vehicleNo.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Vehicle Number / Target')));
                          return;
                       }

                       // Prepend Type to Title if not present
                       if (!finalTitle.startsWith('${expenseTypeController.text}: ')) {
                          finalTitle = '${expenseTypeController.text}: $finalTitle';
                       }
                    }

                    bool isTank = selectedVehicleId == 'TANK_BULK_FUEL' || 
                                  (vehicleNo != null && vehicleNo.toLowerCase().contains('tank'));

                    if (isTank) {
                       vehicleNo = 'Storage Tank';
                    }

                    final lVal = double.tryParse(quantityController.text) ?? 0.0;

                    if (isTank && lVal <= 0) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Please enter Purchased Liters for Storage Tank!'))
                       );
                       return;
                    }

                    final newData = <String, dynamic>{
                       'title': finalTitle,
                       'category': selectedCategory,
                       'site': (selectedCategory == 'Vehicle' && (selectedSite == 'All Sites' || selectedSite == 'No Active Sites')) ? null : selectedSite,
                       'amount': '₹${totalAmountController.text}',
                       'paid': '₹$paidVal',
                       'date': DateFormat('dd MMM yyyy').format(selectedDate),
                       'supplier': finalSupplier,
                       'vehicle_no': vehicleNo,
                       'quantity': lVal > 0 ? lVal.toString() : null,
                       'unit': lVal > 0 ? 'Liters' : null,
                       'liters': lVal > 0 ? lVal.toString() : null,
                       'rate': rateController.text.isNotEmpty ? rateController.text : null,
                       // Store description in material_name for Other category
                       'material_name': selectedCategory == 'Other' ? descriptionController.text : (selectedCategory == 'Labour' ? descriptionController.text : (selectedCategory == 'Material' ? titleController.text : null)),
                    };

                    if (expense != null) {
                      await Provider.of<DataProvider>(context, listen: false).updateExpense(
                        expense['id'],
                        newData
                      );
                    } else {
                      await Provider.of<DataProvider>(context, listen: false).addExpense(newData);
                    }

                    if (isTank) {
                       if (lVal > 0) {
                          await Provider.of<DataProvider>(context, listen: false).addBulkTankFuel(lVal);
                       }
                       await Provider.of<DataProvider>(context, listen: false).fetchFuelTankData();
                    }
                    if (context.mounted) {
                       Navigator.pop(context);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Saved Successfully')));
                    }

                  } catch (e) {
                    if (context.mounted) {
                      showDialog(
                        context: context, 
                        builder: (ctx) => AlertDialog(
                          title: const Text('Error Saving'),
                          content: Text(e.toString()),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                        )
                      );
                    }
                  }
                } else {
                   String msg = amountError ? "Please enter a valid amount" : "Please fill all required fields";
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
        },
      ),
    );
  }
}

void showDispenseFuelDialog(
  BuildContext context,
  DataProvider data, {
  Map<String, dynamic>? existingExpense,
  Map<String, dynamic>? existingIssue,
}) {
  final registry = data.vehicleRegistry;

  // Extract unique Vehicle Types from registry
  final Set<String> vehicleTypes = {'All Types'};
  for (var v in registry) {
    if (v['type'] != null && v['type'].toString().trim().isNotEmpty) {
      vehicleTypes.add(v['type'].toString().trim());
    }
  }
  List<String> typeList = vehicleTypes.toList();
  String selectedFilterType = 'All Types';

  List<Map<String, dynamic>> getFilteredVehicles(String typeFilter) {
    if (typeFilter == 'All Types') return registry;
    return registry.where((v) => (v['type'] ?? '').toString().trim() == typeFilter).toList();
  }

  final bool isEdit = existingExpense != null || existingIssue != null;
  dynamic issueId;
  double oldLiters = 0.0;
  String? initVehNumber;
  String? initNotes;
  DateTime initDate = DateTime.now();

  if (existingExpense != null) {
    issueId = existingExpense['id'];
    oldLiters = double.tryParse(existingExpense['liters']?.toString() ?? existingExpense['quantity']?.toString() ?? '0') ?? 0.0;
    if (oldLiters <= 0) {
      final match = RegExp(r'\((\d+(?:\.\d+)?)\s*L').firstMatch(existingExpense['title'] ?? '');
      if (match != null) {
        oldLiters = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      }
    }
    initVehNumber = (existingExpense['vehicle_no'] ?? '').toString().trim();
    initNotes = (existingExpense['material_name'] ?? existingExpense['notes'] ?? '').toString().trim();
    if (initNotes == 'Tank Fuel Issue') initNotes = '';
    if (existingExpense['date'] != null) {
      try {
        initDate = DateFormat('dd MMM yyyy').parse(existingExpense['date']);
      } catch (_) {}
    }
  } else if (existingIssue != null) {
    issueId = existingIssue['id'];
    oldLiters = (existingIssue['liters'] as num?)?.toDouble() ?? 0.0;
    initVehNumber = (existingIssue['vehicle_number'] ?? '').toString().trim();
    initNotes = (existingIssue['notes'] ?? '').toString().trim();
    if (existingIssue['date'] != null) {
      try {
        initDate = DateFormat('dd MMM yyyy').parse(existingIssue['date']);
      } catch (_) {}
    }
  }

  var availableVehicles = getFilteredVehicles(selectedFilterType);
  String? selectedVehNumber = (initVehNumber != null && initVehNumber.isNotEmpty)
      ? initVehNumber
      : (availableVehicles.isNotEmpty ? availableVehicles.first['number'] as String? : null);

  if (selectedVehNumber != null) {
    final matchingVeh = registry.firstWhere((v) => v['number'] == selectedVehNumber, orElse: () => {});
    if (matchingVeh.isNotEmpty && matchingVeh['type'] != null) {
      final vType = matchingVeh['type'].toString().trim();
      if (typeList.contains(vType)) {
        selectedFilterType = vType;
        availableVehicles = getFilteredVehicles(selectedFilterType);
      }
    }
  }

  String selectedVehType = availableVehicles.isNotEmpty ? (availableVehicles.first['type'] as String? ?? 'Lorry') : 'Lorry';

  final litersController = TextEditingController(text: isEdit && oldLiters > 0 ? (oldLiters % 1 == 0 ? oldLiters.toInt().toString() : oldLiters.toString()) : '');
  final notesController = TextEditingController(text: initNotes ?? '');
  DateTime issueDate = initDate;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final currentFilteredVehicles = getFilteredVehicles(selectedFilterType);
        if (selectedVehNumber != null && !currentFilteredVehicles.any((v) => v['number'] == selectedVehNumber)) {
          selectedVehNumber = currentFilteredVehicles.isNotEmpty ? currentFilteredVehicles.first['number'] as String? : null;
          if (currentFilteredVehicles.isNotEmpty) {
            selectedVehType = currentFilteredVehicles.first['type'] ?? 'Lorry';
          }
        }

        final double effectiveStock = data.mainTankLiters + oldLiters;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.local_gas_station, color: JarvisTheme.secondary),
              const SizedBox(width: 8),
              Text(isEdit ? 'Edit Tank Fuel Issue' : 'Dispense Fuel to Vehicle', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: JarvisTheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tank Balance:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('${effectiveStock.toStringAsFixed(1)} Liters', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: JarvisTheme.secondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 1. Filter by Vehicle Type
                DropdownButtonFormField<String>(
                  value: selectedFilterType,
                  decoration: const InputDecoration(labelText: 'Select Vehicle Type', border: OutlineInputBorder(), isDense: true),
                  items: typeList.map((t) => DropdownMenuItem<String>(
                    value: t,
                    child: Text(t == 'All Types' ? '🚗 All Vehicle Types' : '🚚 $t'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedFilterType = val;
                        final filtered = getFilteredVehicles(val);
                        selectedVehNumber = filtered.isNotEmpty ? filtered.first['number'] as String? : null;
                        if (filtered.isNotEmpty) {
                          selectedVehType = filtered.first['type'] ?? 'Lorry';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                // 2. Filtered Target Vehicle Number Dropdown
                DropdownButtonFormField<String>(
                  value: selectedVehNumber,
                  decoration: const InputDecoration(labelText: 'Select Target Vehicle Number *', border: OutlineInputBorder(), isDense: true),
                  items: currentFilteredVehicles.map((v) => DropdownMenuItem<String>(
                    value: v['number'],
                    child: Text('${v['number']} (${v['type']})'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedVehNumber = val;
                        final veh = currentFilteredVehicles.firstWhere((v) => v['number'] == val, orElse: () => {});
                        selectedVehType = veh['type'] ?? 'Lorry';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: litersController,
                  decoration: const InputDecoration(labelText: 'Liters Issued *', border: OutlineInputBorder(), isDense: true, suffixText: 'L'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: !isEdit,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Description / Notes (Optional)', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${DateFormat('dd MMM yyyy').format(issueDate)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: issueDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => issueDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.secondary, foregroundColor: Colors.black),
              onPressed: () async {
                final litersVal = double.tryParse(litersController.text);
                if (litersVal == null || litersVal <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid liters')));
                  return;
                }
                if (litersVal > effectiveStock) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insufficient Tank Stock! Available: ${effectiveStock.toStringAsFixed(1)} L')));
                  return;
                }
                if (selectedVehNumber == null || selectedVehNumber!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a target vehicle')));
                  return;
                }

                try {
                  bool success = false;
                  if (isEdit && issueId != null) {
                    success = await data.updateFuelIssue(
                      issueId: issueId,
                      date: DateFormat('dd MMM yyyy').format(issueDate),
                      vehicleNumber: selectedVehNumber!,
                      vehicleType: selectedVehType,
                      liters: litersVal,
                      notes: notesController.text,
                    );
                  } else {
                    success = await data.issueFuelToVehicle(
                      date: DateFormat('dd MMM yyyy').format(issueDate),
                      vehicleNumber: selectedVehNumber!,
                      vehicleType: selectedVehType,
                      liters: litersVal,
                      notes: notesController.text,
                    );
                  }

                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(isEdit ? 'Updated fuel issue for $selectedVehNumber' : 'Issued $litersVal L to $selectedVehNumber'))
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to save fuel issue. Check tank balance.'))
                      );
                    }
                  }
                } catch (err) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $err'))
                    );
                  }
                }
              },
              child: Text(isEdit ? 'SAVE' : 'ISSUE FUEL'),
            ),
          ],
        );
      },
    ),
  );
}

