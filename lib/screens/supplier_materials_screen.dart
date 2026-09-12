import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import 'package:intl/intl.dart';

class SupplierMaterialsScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierMaterialsScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  _SupplierMaterialsScreenState createState() => _SupplierMaterialsScreenState();
}

class _SupplierMaterialsScreenState extends State<SupplierMaterialsScreen> {
  Future<List<Map<String, dynamic>>>? _materialsFuture;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  void _loadMaterials() {
    setState(() {
      _materialsFuture = Provider.of<DataProvider>(context, listen: false)
          .getSupplierMaterials(widget.supplierId);
    });
  }

  void _showAddEditDialog([Map<String, dynamic>? material]) {
    final nameController = TextEditingController(text: material?['material_name'] ?? '');
    final buyPriceController = TextEditingController(text: material?['buy_price']?.replaceAll('₹', '') ?? '');
    final unitController = TextEditingController(text: material?['unit'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material == null ? 'Add Material' : 'Edit Material'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Material Name (e.g., Cement)'),
              ),
              TextField(
                controller: buyPriceController,
                decoration: const InputDecoration(labelText: 'Buy Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit (e.g., Bag, Load)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              final data = {
                'supplier_id': widget.supplierId,
                'material_name': nameController.text,
                'buy_price': buyPriceController.text.isNotEmpty ? '₹${buyPriceController.text}' : '',
                'sell_price': '',
                'unit': unitController.text,
                'date': DateFormat('dd MMM yyyy').format(DateTime.now()),
              };

              if (material == null) {
                await Provider.of<DataProvider>(context, listen: false).addSupplierMaterial(data);
              } else {
                await Provider.of<DataProvider>(context, listen: false).updateSupplierMaterial(material['id'], data);
              }

              if (context.mounted) Navigator.pop(context);
              _loadMaterials();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteMaterial(String id, String materialName) {
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
        content: Text('Are you sure you want to delete material "$materialName"?'),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<DataProvider>(context, listen: false).deleteSupplierMaterial(id);
              _loadMaterials();
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supplierName} - Price List'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _materialsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No materials found. Add one!'));
          }

          final materials = snapshot.data!;

          return ListView.builder(
            itemCount: materials.length,
            itemBuilder: (context, index) {
              final mat = materials[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    mat['material_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Unit: ${mat['unit'] ?? '-'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buy: ${mat['buy_price']}',
                        style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddEditDialog(mat);
                          } else if (value == 'delete') {
                            _deleteMaterial(mat['id'], mat['material_name'] ?? 'Material');
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
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

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
