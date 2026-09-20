import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import 'bunk_ledger_screen.dart';
import 'supplier_materials_screen.dart';
import '../widgets/dev_branding_badge.dart';

class SupplierPaymentsScreen extends StatefulWidget {
  const SupplierPaymentsScreen({super.key});

  @override
  State<SupplierPaymentsScreen> createState() => _SupplierPaymentsScreenState();
}

class _SupplierPaymentsScreenState extends State<SupplierPaymentsScreen> {
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search Suppliers...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                style: const TextStyle(color: Colors.black),
                cursorColor: Colors.black,
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              )
            : const Text('SUPPLIER DETAILS'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          const DevBrandingBadge(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSupplierDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          final filteredSuppliers = _searchQuery.isEmpty
              ? data.generalSuppliers
              : data.generalSuppliers
                  .where((s) => s['name'].toString().toLowerCase().contains(_searchQuery) ||
                                (s['contact'] != null && s['contact'].toString().toLowerCase().contains(_searchQuery)) ||
                                (s['material'] != null && s['material'].toString().toLowerCase().contains(_searchQuery)))
                  .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filteredSuppliers.length,
            itemBuilder: (context, index) {
              final supplier = filteredSuppliers[index];
              return Card(
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
                                Text(
                                  supplier['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: JarvisTheme.primary,
                                  ),
                                ),
                                Text(
                                  supplier['material'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: JarvisTheme.textSecondary,
                                  ),
                                ),
                                if (supplier['contact'] != null && supplier['contact'].toString().isNotEmpty)
                                  Text(
                                    supplier['contact'],
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.chevron_right, color: Colors.grey),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'payment') {
                                      _showPaymentDialog(context, supplier);
                                    } else if (value == 'edit') {
                                      _showAddSupplierDialog(context, supplier: supplier);
                                    } else if (value == 'materials') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SupplierMaterialsScreen(
                                            supplierId: supplier['id'],
                                            supplierName: supplier['name'],
                                          ),
                                        ),
                                      );
                                    } else if (value == 'delete') {
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
                                      value: 'materials',
                                      child: Row(
                                        children: [
                                          Icon(Icons.list_alt, size: 18, color: Colors.orange),
                                          SizedBox(width: 8),
                                          Text('Materials / Price List'),
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: JarvisTheme.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfo('Total', supplier['total']),
                              _buildInfo('Paid', supplier['paid'], color: JarvisTheme.statusPaid),
                              _buildInfo('Balance', supplier['balance'], color: JarvisTheme.statusPending),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _showHistoryDialog(context, supplier['id'], supplier['name']);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: JarvisTheme.primary.withValues(alpha: 0.05),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                            ),
                            child: const Text(
                              'VIEW LEDGER',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: JarvisTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfo(String label, String value, {Color? color}) {
    return Column(
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
              onPressed: () {
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

                final provider = Provider.of<DataProvider>(context, listen: false);
                if (contact.isNotEmpty) {
                  final duplicateContact = provider.suppliers.any((s) =>
                      (supplier == null || s['id'].toString() != supplier['id'].toString()) &&
                      s['contact'] != null &&
                      s['contact'].toString().trim() == contact);
                  if (duplicateContact) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('A supplier with contact number "$contact" already exists')),
                    );
                    return;
                  }
                } else {
                  final duplicateName = provider.suppliers.any((s) =>
                      (supplier == null || s['id'].toString() != supplier['id'].toString()) &&
                      s['name'] != null &&
                      s['name'].toString().trim().toLowerCase() == name.toLowerCase());
                  if (duplicateName) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('A supplier with name "$name" already exists')),
                    );
                    return;
                  }
                }

                final newData = {
                  'name': name,
                  'contact': contact,
                  'material': materials,
                };

                if (supplier != null) {
                  provider.updateSupplier(
                    supplier['id'],
                    newData
                  );
                } else {
                  provider.addSupplier({
                    ...newData,
                    'total': '₹0',
                    'paid': '₹0',
                    'balance': '₹0',
                  });
                }
                Navigator.pop(context);
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
        builder: (_) => BunkLedgerScreen(
          supplierId: id,
          supplierName: name,
        ),
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> supplier) {
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
              onPressed: () {
                     final amountValue = double.tryParse(amountController.text) ?? 0;
                     if (amountValue > 0) {
                        Provider.of<DataProvider>(context, listen: false).recordSupplierPayment(
                          supplier['id'], 
                          amountValue, 
                          DateFormat('dd MMM yyyy').format(selectedDate),
                          isDiscount: isDiscount,
                          notes: isDiscount ? 'Discount Allowed' : 'Payment Made',
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDiscount ? 'Discount Recorded' : 'Payment Recorded')));
                     }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }
}

class SupplierDetailScreen extends StatelessWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        // Get latest data for this supplier to ensure updates are reflected
        final currentSupplier = data.suppliers.firstWhere(
          (s) => s['id'] == supplier['id'],
          orElse: () => supplier,
        );

        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: Text(currentSupplier['name']),
          ),
          body: Column(
            children: [
              // Summary Header
              Container(
                padding: const EdgeInsets.all(16),
                color: JarvisTheme.primary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OUTSTANDING', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text(
                          currentSupplier['balance'],
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _showPaymentDialog(context, currentSupplier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JarvisTheme.secondary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('ADD PAYMENT'),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: JarvisTheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Materials', currentSupplier['material']),
                          const Divider(height: 24),
                          if (currentSupplier['contact'] != null && currentSupplier['contact'].toString().isNotEmpty) ...[
                            _buildDetailRow('Contact', currentSupplier['contact']),
                            const Divider(height: 24),
                          ],
                          _buildDetailRow('Total Amount', currentSupplier['total']),
                          const Divider(height: 24),
                          _buildDetailRow('Paid Amount', currentSupplier['paid'], color: JarvisTheme.statusPaid),
                          const Divider(height: 24),
                          _buildDetailRow('Balance Due', currentSupplier['balance'], color: JarvisTheme.statusPending),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No recent payment history',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: JarvisTheme.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color ?? JarvisTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showPaymentDialog(BuildContext context, Map<String, dynamic> supplier) {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    
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
                  labelText: 'Amount to Pay (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description / Notes (Optional)',
                  border: OutlineInputBorder(),
                ),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  _processPayment(context, supplier, amount, DateFormat('dd MMM yyyy').format(selectedDate), notes: descController.text.trim());
                  Navigator.pop(context);
                }
              },
              child: const Text('PAY'),
            ),
          ],
        ),
      ),
    );
  }

  void _processPayment(BuildContext context, Map<String, dynamic> supplier, double amount, String date, {String? notes}) {
    Provider.of<DataProvider>(context, listen: false).recordSupplierPayment(supplier['id'], amount, date, notes: (notes != null && notes.isNotEmpty) ? notes : 'Payment Made');
  }

  TableRow _buildTableRow(List<String> cells, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? JarvisTheme.background : JarvisTheme.surface,
      ),
      children: cells.map((cell) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            cell,
            style: TextStyle(
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }
}
