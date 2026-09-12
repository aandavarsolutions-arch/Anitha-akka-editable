import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../data/data_provider.dart';
import '../theme.dart';
import '../app_config.dart';

class VehicleRegistryScreen extends StatelessWidget {
  const VehicleRegistryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('Vehicle Registry'),
      ),
      floatingActionButton: AppConfig.isReadOnly ? null : FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          final vehicles = data.vehicleRegistry;
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicles in registry. Add one!'));
          }
          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final v = vehicles[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                  title: Text(v['number'] ?? 'Unknown Number', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Builder(
                    builder: (context) {
                      Map<String, dynamic> rates = {};
                      if (v['rates'] != null) {
                         try { rates = Map<String, dynamic>.from(jsonDecode(v['rates'])); } catch (_) {}
                      }
                      if (rates.isEmpty) {
                        if (v['rate_hour']?.isNotEmpty ?? false) rates['Hour'] = v['rate_hour'];
                        if (v['rate_day']?.isNotEmpty ?? false) rates['Day'] = v['rate_day'];
                        if (v['rate_trip']?.isNotEmpty ?? false) rates['Trip'] = v['rate_trip'];
                      }
                      
                      String rateStr = rates.entries.map((e) => '${e.key}: ₹${e.value}').join(' • ');

                      List<String> docParts = [];
                      if (v['insurance_expiry']?.toString().isNotEmpty ?? false) docParts.add('Ins: ${v['insurance_expiry']}');
                      if (v['fc_expiry']?.toString().isNotEmpty ?? false) docParts.add('FC: ${v['fc_expiry']}');
                      if (v['puc_expiry']?.toString().isNotEmpty ?? false) docParts.add('PUC: ${v['puc_expiry']}');
                      String docsStr = docParts.join(' • ');

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v['type'] ?? 'Vehicle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          if (rateStr.isNotEmpty) Text(rateStr, style: const TextStyle(fontSize: 12)),
                          if (docsStr.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(docsStr, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      );
                    }
                  ),
                  trailing: AppConfig.isReadOnly ? null : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () {
                         _confirmDelete(context, v['id']);
                    },
                  ),
                  onTap: AppConfig.isReadOnly ? null : () => _showAddDialog(context, vehicle: v),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: const Text('Are you sure you want to delete this vehicle from registry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Provider.of<DataProvider>(context, listen: false).removeFromRegistry(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, {Map<String, dynamic>? vehicle}) {
    final numberController = TextEditingController(text: vehicle?['number']);
    final typeController = TextEditingController(text: vehicle?['type']);
    
    DateTime? insuranceDate;
    DateTime? fcDate;
    DateTime? pucDate;

    try {
      if (vehicle?['insurance_expiry']?.toString().isNotEmpty ?? false) {
        insuranceDate = DateFormat('dd MMM yyyy').parse(vehicle!['insurance_expiry']);
      }
    } catch (_) {}
    try {
      if (vehicle?['fc_expiry']?.toString().isNotEmpty ?? false) {
        fcDate = DateFormat('dd MMM yyyy').parse(vehicle!['fc_expiry']);
      }
    } catch (_) {}
    try {
      if (vehicle?['puc_expiry']?.toString().isNotEmpty ?? false) {
        pucDate = DateFormat('dd MMM yyyy').parse(vehicle!['puc_expiry']);
      }
    } catch (_) {}
    
    Map<String, dynamic> rates = {};
    if (vehicle != null) {
      if (vehicle['rates'] != null) {
        try { rates = Map<String, dynamic>.from(jsonDecode(vehicle['rates'])); } catch (_) {}
      }
      if (rates.isEmpty) {
         if (vehicle['rate_hour']?.isNotEmpty ?? false) rates['Hour'] = vehicle['rate_hour'];
         if (vehicle['rate_day']?.isNotEmpty ?? false) rates['Day'] = vehicle['rate_day'];
         if (vehicle['rate_trip']?.isNotEmpty ?? false) rates['Trip'] = vehicle['rate_trip'];
      }
    }

    final newRateTypeController = TextEditingController();
    final newRateAmountController = TextEditingController();

    final data = Provider.of<DataProvider>(context, listen: false);

    // Build unique vehicle types list from database registry + default types
    final Set<String> typeSuggestionsSet = {'Lorry', 'JCB', 'Tractor', 'Tipper', 'Hitachi', 'Crane', 'Roller', 'Compressor'};
    for (var v in data.vehicleRegistry) {
      final t = (v['type'] ?? '').toString().trim();
      if (t.isNotEmpty) typeSuggestionsSet.add(t);
    }
    for (var v in data.vehicles) {
      final t = (v['type'] ?? '').toString().trim();
      if (t.isNotEmpty) typeSuggestionsSet.add(t);
    }
    final List<String> allTypeSuggestions = typeSuggestionsSet.toList();

    // Build unique rate types list
    final Set<String> rateTypeSuggestionsSet = {'Load', 'Hour', 'Trip', 'Shift', 'Day', 'KM'};
    for (var v in data.vehicleRegistry) {
      if (v['rates'] != null) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(v['rates']));
          for (var k in m.keys) {
            if (k.trim().isNotEmpty) rateTypeSuggestionsSet.add(k.trim());
          }
        } catch (_) {}
      }
    }
    final List<String> allRateTypeSuggestions = rateTypeSuggestionsSet.toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void addRate() {
            if (newRateTypeController.text.isNotEmpty && newRateAmountController.text.isNotEmpty) {
              setState(() {
                rates[newRateTypeController.text.trim()] = newRateAmountController.text.trim();
                newRateTypeController.clear();
                newRateAmountController.clear();
              });
            }
          }

          void removeRate(String key) {
            setState(() {
              rates.remove(key);
            });
          }

          return AlertDialog(
            title: Text(vehicle == null ? 'Add Vehicle' : 'Edit Vehicle'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: numberController, 
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Number', 
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Vehicle Type Input with Real-time Auto Suggestions
                  TextField(
                    controller: typeController,
                    onChanged: (val) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Type (e.g. Lorry, JCB)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_car, color: JarvisTheme.secondary),
                    ),
                  ),
                  
                  // Auto-Suggestion Chips for Vehicle Type
                  if (typeController.text.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Builder(
                      builder: (context) {
                        final query = typeController.text.trim().toLowerCase();
                        final matches = allTypeSuggestions.where((s) => s.toLowerCase().contains(query) && s.toLowerCase() != query).toList();
                        if (matches.isEmpty) return const SizedBox.shrink();
                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: matches.map((typeOption) {
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  typeController.text = typeOption;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.amber[700]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.auto_awesome, size: 12, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      typeOption,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[900]),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Text('Rates Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  
                  // Add New Rate Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: newRateTypeController,
                              onChanged: (val) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Type (e.g. Load)', isDense: true, border: OutlineInputBorder()),
                            ),
                            if (newRateTypeController.text.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Builder(
                                builder: (context) {
                                  final query = newRateTypeController.text.trim().toLowerCase();
                                  final matches = allRateTypeSuggestions.where((s) => s.toLowerCase().contains(query) && s.toLowerCase() != query).toList();
                                  if (matches.isEmpty) return const SizedBox.shrink();
                                  return Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: matches.map((rateOption) {
                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            newRateTypeController.text = rateOption;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.blue[700]!),
                                          ),
                                          child: Text(
                                            rateOption,
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[900]),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: newRateAmountController,
                          decoration: const InputDecoration(labelText: 'Amount (₹)', isDense: true, border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: JarvisTheme.primary, size: 28),
                        onPressed: addRate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // List of Added Rates
                  if (rates.isEmpty)
                    const Text('No rates added yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: rates.entries.map((e) {
                         return Chip(
                           label: Text('${e.key}: ₹${e.value}'),
                           deleteIcon: const Icon(Icons.close, size: 16),
                           onDeleted: () => removeRate(e.key),
                           backgroundColor: Colors.blue.withValues(alpha: 0.1),
                         );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),
                  const Text('Document Expiry Dates', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 6),

                  // Insurance Expiry Tile
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Insurance End Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      insuranceDate != null ? DateFormat('dd MMM yyyy').format(insuranceDate!) : 'Not set',
                      style: TextStyle(fontWeight: FontWeight.bold, color: insuranceDate != null ? Colors.blue[900] : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (insuranceDate != null)
                          IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => insuranceDate = null)),
                        const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: insuranceDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => insuranceDate = picked);
                    },
                  ),

                  // FC Expiry Tile
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('FC End Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      fcDate != null ? DateFormat('dd MMM yyyy').format(fcDate!) : 'Not set',
                      style: TextStyle(fontWeight: FontWeight.bold, color: fcDate != null ? Colors.blue[900] : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (fcDate != null)
                          IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => fcDate = null)),
                        const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: fcDate ?? DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => fcDate = picked);
                    },
                  ),

                  // PUC Expiry Tile
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('PUC End Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      pucDate != null ? DateFormat('dd MMM yyyy').format(pucDate!) : 'Not set',
                      style: TextStyle(fontWeight: FontWeight.bold, color: pucDate != null ? Colors.blue[900] : Colors.grey),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (pucDate != null)
                          IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => pucDate = null)),
                        const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
                      ],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: pucDate ?? DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => pucDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (numberController.text.isNotEmpty) {
                     final data = Provider.of<DataProvider>(context, listen: false);
                     
                     String defRate = rates.isNotEmpty ? rates.values.first.toString() : '0';
                     String defType = rates.isNotEmpty ? rates.keys.first : 'Hour';
                     
                     final newData = {
                       'number': numberController.text.trim(),
                       'type': typeController.text.trim(),
                       'rates': jsonEncode(rates),
                       'rate': defRate,
                       'rate_type': defType,
                       'insurance_expiry': insuranceDate != null ? DateFormat('dd MMM yyyy').format(insuranceDate!) : '',
                       'fc_expiry': fcDate != null ? DateFormat('dd MMM yyyy').format(fcDate!) : '',
                       'puc_expiry': pucDate != null ? DateFormat('dd MMM yyyy').format(pucDate!) : '',
                     };
                     if (vehicle == null) {
                       data.addToRegistry(newData);
                     } else {
                       data.updateInRegistry(vehicle['id'], newData);
                     }
                     Navigator.pop(context);
                  }
                }, 
                child: const Text('Save')
              ),
            ],
          );
        }
      ),
    );
  }
}
