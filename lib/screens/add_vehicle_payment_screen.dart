import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';
import 'dart:convert';

class AddVehiclePaymentScreen extends StatefulWidget {
  final bool isOwn;
  final Map<String, dynamic>? vehicle;
  final String? initialCustomer;
  final String? initialSite;
  final String? initialVehicleNo; // New Parameter
  final Map<String, dynamic>? defaults;

  const AddVehiclePaymentScreen({super.key, required this.isOwn, this.vehicle, this.initialCustomer, this.initialSite, this.initialVehicleNo, this.defaults});

  @override
  State<AddVehiclePaymentScreen> createState() => _AddVehiclePaymentScreenState();
}

class _AddVehiclePaymentScreenState extends State<AddVehiclePaymentScreen> {
  // ... (controllers defined above, no change)
  late TextEditingController numberController;
  late TextEditingController typeController;
  late TextEditingController billNoController;
  late TextEditingController totalController;
  late TextEditingController battaController;
  late TextEditingController paidController;
  late TextEditingController durationController;
  late TextEditingController rateController;
  late TextEditingController grandTotalController;
  bool _isUpdatingInternally = false;

  String? selectedRegistryId;
  String currentRateType = 'Hour';
  DateTime selectedDate = DateTime.now();
  String? selectedSite;
  String? selectedCustomer;
  List<String> availableRateTypes = [];
  final FocusNode numberFocusNode = FocusNode();
  final FocusNode typeFocusNode = FocusNode();
  final FocusNode customerFocusNode = FocusNode();
  final FocusNode driverFocusNode = FocusNode();
  final FocusNode supplierFocusNode = FocusNode();
  final FocusNode materialFocusNode = FocusNode();
  final TextEditingController customerController = TextEditingController();
  final TextEditingController supplierController = TextEditingController();
  late TextEditingController driverController;

  // ... (rest of fields)
  String? selectedSupplier;
  final TextEditingController materialNameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController materialAmountController = TextEditingController();
  final TextEditingController materialPriceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController(); // NEW
  String currentUnit = 'Ltr';
  
  List<Map<String, dynamic>> _supplierMaterials = [];
  Map<String, dynamic>? _selectedMaterialItem;
  double? currentBuyPrice;
  bool _isEditing = false;
  String? _editingId;
  bool _isOwnSite = false; // Toggle state for Own Site vs Customer (Req 3)
  bool _isAmountManuallyEdited = false;
  int _resetCounter = 0;

  void _resetFormForNewEntry() {
    setState(() {
      _resetCounter++;
      _isEditing = false;
      _editingId = null;
      _isAmountManuallyEdited = false;

      numberController.clear();
      typeController.clear();
      billNoController.clear();
      durationController.clear();
      rateController.clear();
      battaController.clear();
      totalController.clear();
      paidController.clear();
      driverController.clear();
      descriptionController.clear();
      supplierController.clear();
      materialNameController.clear();
      quantityController.clear();
      materialPriceController.clear();
      materialAmountController.clear();
      grandTotalController.clear();

      selectedSupplier = null;
      _selectedMaterialItem = null;
      _supplierMaterials = [];
      selectedRegistryId = null;
      vehicleRates = {};
      availableRateTypes = [];
      currentRateType = 'Day';

      selectedCustomer = widget.initialCustomer;
      customerController.text = selectedCustomer ?? '';
      selectedSite = widget.initialSite;
    });
  }

  @override
  void initState() {
    super.initState();
    // Controllers init
    final v = widget.vehicle;
    if (v != null) {
      _isEditing = true;
      _editingId = v['id'];
      _isAmountManuallyEdited = true;
    }

    numberController = TextEditingController(text: v != null ? v['number'] : (widget.initialVehicleNo ?? ''));
    typeController = TextEditingController(text: v != null ? v['type'] : '');
    billNoController = TextEditingController(text: v != null ? (v['bill_no'] ?? v['bill_number'] ?? '').toString() : '');
    double initialRentAmt = _parseAmount(v?['rent_amount']);
    double initialBattaAmt = _parseAmount(v?['batta'] ?? v?['batta_amount']);
    double initialVehicleTotal = 0.0;
    if (v != null) {
      if (initialRentAmt > 0 || initialBattaAmt > 0) {
        initialVehicleTotal = initialRentAmt + initialBattaAmt;
      } else {
        initialVehicleTotal = _parseAmount(v['total']) - _parseAmount(v['material_amount']);
      }
    }
    totalController = TextEditingController(text: v != null ? (initialVehicleTotal > 0 ? initialVehicleTotal.toStringAsFixed(0) : '') : '');
    
    battaController = TextEditingController(text: v != null ? (v['batta'] ?? v['batta_amount'] ?? '').toString().replaceAll('₹', '').replaceAll(',', '') : '');
    paidController = TextEditingController(text: v != null ? (v['paid']?.toString() ?? '').replaceAll('₹', '').replaceAll(',', '') : '');
    driverController = TextEditingController(text: v != null ? (v['driver'] ?? '').toString() : '');
    durationController = TextEditingController(); 
    rateController = TextEditingController(); 
    grandTotalController = TextEditingController();

    // TOTALS SYNC LISTENERS
    totalController.addListener(_onHireChargeChanged);
    battaController.addListener(_onHireChargeChanged);
    materialAmountController.addListener(_onMaterialAmountChanged);
    grandTotalController.addListener(_onGrandTotalChanged);

    // Initial calculation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncGrandTotal();
    });

    if (v != null) {
       // Restore Rate/Duration if stored? 
       // Currently your code calculated total but didn't explicitly store rate/duration in top level map if they were transient. 
       // But let's assume valid data for now.
       durationController.text = v['duration'] ?? '';
       rateController.text = v['rate'] ?? '';
       String rt = v['rate_type'] ?? 'Day';
       currentRateType = rt.isNotEmpty ? (rt[0].toUpperCase() + rt.substring(1).toLowerCase()) : 'Day';
       
       if (v['date'] != null && v['date'] != 'Today') {
        try {
          selectedDate = DateFormat('dd MMM yyyy').parse(v['date']);
        } catch (_) {}
      }
       selectedSite = (v['site'] != null && v['site'].toString().trim().isNotEmpty) ? v['site'] : null;
      selectedCustomer = (v['customer'] != null && v['customer'].toString().trim().isNotEmpty) ? v['customer'] : null;
    } else {
       if (widget.initialCustomer != null) selectedCustomer = widget.initialCustomer;
       if (widget.initialSite != null) selectedSite = widget.initialSite;
       
       // If opened from site context with no customer, pre-fill site name in Customer/Site Name field
       if (widget.initialSite != null && widget.initialCustomer == null && !widget.isOwn) {
         selectedCustomer = widget.initialSite;
       }
       
       if (widget.initialVehicleNo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
             _autoSelectVehicle(widget.initialVehicleNo!);
          });
       }
    }
    
    if (widget.defaults != null && v == null) {
      if (widget.defaults!['number'] != null) numberController.text = widget.defaults!['number'];
      if (widget.defaults!['type'] != null) typeController.text = widget.defaults!['type'];
      if (widget.defaults!['rate'] != null) rateController.text = widget.defaults!['rate'];
      if (widget.defaults!['rate_type'] != null) {
          String rt = widget.defaults!['rate_type'];
          currentRateType = rt[0].toUpperCase() + rt.substring(1).toLowerCase();
      }
    }

    if (v != null) {
       materialNameController.text = v['material_name'] ?? '';
       quantityController.text = v['quantity'] ?? '';
       materialAmountController.text = v['material_amount'] ?? '';
       if (v['unit'] != null) currentUnit = v['unit'];
       
       if (v['supplier'] != null && v['supplier'].toString().trim().isNotEmpty) {
          final supStr = v['supplier'].toString().trim();
          selectedSupplier = supStr;
          supplierController.text = supStr;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
             final data = Provider.of<DataProvider>(context, listen: false);
             _loadSupplierMaterials(supStr);
             final matching = data.suppliers.firstWhere(
                (s) => s['name'].toString().trim().toLowerCase() == supStr.toLowerCase(),
                orElse: () => {},
             );
             if (matching.isNotEmpty) {
                setState(() {
                   selectedSupplier = matching['name'].toString();
                   supplierController.text = matching['name'].toString();
                });
             } else {
                setState(() {
                   selectedSupplier = supStr;
                   supplierController.text = supStr;
                });
             }
             if (materialNameController.text.isNotEmpty) {
                _fetchMaterialBuyPrice(supStr, materialNameController.text);
             }
          });
       }
       
       // Restore Unit Price
       double qty = double.tryParse(v['quantity'] ?? '0') ?? 0;
       double amt = double.tryParse(v['material_amount'] ?? '0') ?? 0;
       if (qty > 0 && amt > 0) {
         materialPriceController.text = (amt / qty).toStringAsFixed(2);
       }

       // Restore Buy Price
       if (v['buy_price'] != null) {
         currentBuyPrice = _parseAmount(v['buy_price']);
       }
    }

    if (v != null) {
      if (v['manual_desc'] != null) descriptionController.text = v['manual_desc'];
    }

    customerController.text = selectedCustomer ?? '';
    if (v != null) {
       if (v['isOwnSite'] != null) {
          _isOwnSite = (v['isOwnSite'] == 1 || v['isOwnSite'] == true);
       } else {
          _isOwnSite = (selectedCustomer == null || selectedCustomer!.isEmpty);
       }
    } else {
       _isOwnSite = false;
    }

    // Fix selectedRegistryId in Edit Mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (v != null) {
          final data = Provider.of<DataProvider>(context, listen: false);
          try {
             final reg = data.vehicleRegistry.firstWhere((r) => r['number'] == v['number']);
             setState(() {
                selectedRegistryId = reg['id'];
             });
          } catch (_) {}
       }
    });
  }

  @override
  void dispose() {
    // REMOVE SYNC LISTENERS
    totalController.removeListener(_onHireChargeChanged);
    battaController.removeListener(_onHireChargeChanged);
    materialAmountController.removeListener(_onMaterialAmountChanged);
    grandTotalController.removeListener(_onGrandTotalChanged);

    numberFocusNode.dispose();
    typeFocusNode.dispose();
    customerFocusNode.dispose();
    driverFocusNode.dispose();
    supplierFocusNode.dispose();
    materialFocusNode.dispose();
    numberController.dispose();
    typeController.dispose();
    billNoController.dispose();
    driverController.dispose();
    supplierController.dispose();
    totalController.dispose();
    battaController.dispose();
    paidController.dispose();
    durationController.dispose();
    rateController.dispose();
    grandTotalController.dispose();
    materialNameController.dispose();
    quantityController.dispose();
    materialAmountController.dispose();
    materialPriceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Map<String, dynamic> vehicleRates = {};

  String? _getRateForType(String type) {
    for (var entry in vehicleRates.entries) {
      if (entry.key.trim().toLowerCase() == type.trim().toLowerCase()) {
        return entry.value?.toString();
      }
    }
    return null;
  }

  void _checkAndAutoSelectVehicle(String inputNumber) {
    final clean = inputNumber.trim().toLowerCase();
    if (clean.isEmpty) return;

    final data = Provider.of<DataProvider>(context, listen: false);
    try {
      final matching = data.vehicleRegistry.firstWhere(
        (v) => (v['number'] ?? '').toString().trim().toLowerCase() == clean,
      );
      if (selectedRegistryId != matching['id']) {
        _autoSelectVehicle(matching['number'].toString());
      }
    } catch (_) {
      if (selectedRegistryId != null) {
        setState(() {
          selectedRegistryId = null;
        });
      }
    }
  }

  void _autoSelectVehicle(String number, {bool isManualSelection = false}) {
     final data = Provider.of<DataProvider>(context, listen: false);
     try {
       final reg = data.vehicleRegistry.firstWhere(
         (v) => (v['number'] ?? '').toString().trim().toLowerCase() == number.trim().toLowerCase(),
       );
       setState(() {
         selectedRegistryId = reg['id'];
         numberController.text = reg['number'];
         typeController.text = reg['type'];
         // Auto-load rates
         Map<String, dynamic> rates = {};
         if (reg['rates'] != null) {
           try { rates = jsonDecode(reg['rates']); } catch (_) {}
         }
         if (rates.isEmpty) {
            if (reg['rate_hour']?.isNotEmpty ?? false) rates['Hour'] = reg['rate_hour'];
            if (reg['rate_day']?.isNotEmpty ?? false) rates['Day'] = reg['rate_day'];
            if (reg['rate_trip']?.isNotEmpty ?? false) rates['Trip'] = reg['rate_trip'];
         }

         vehicleRates = rates; // Store for switching

         if (rates.isNotEmpty) {
            availableRateTypes = rates.keys.toList();
            if (isManualSelection || (!_isEditing && rateController.text.isEmpty)) {
              String firstKey = rates.keys.first;
              currentRateType = firstKey[0].toUpperCase() + firstKey.substring(1).toLowerCase();
              rateController.text = rates[firstKey].toString();
              _calculateTotal();
            }
         } else {
            availableRateTypes = []; // Reset to show all defaults if no config
            if (isManualSelection || !_isEditing) {
              currentRateType = 'Day';
            }
            vehicleRates = {};
         }
       });
     } catch (_) {
       // Vehicle not in registry, just set text
       numberController.text = number;
       setState(() {
          availableRateTypes = [];
          vehicleRates = {};
       });
     }
  }

  void _updatePriceSelection() {
     if (_selectedMaterialItem != null) {
        final item = _selectedMaterialItem!;
        setState(() {
           if (_isOwnSite || !widget.isOwn) {
              materialPriceController.text = item['buy_price']?.toString() ?? '0';
           } else {
              if (item['sell_price'] != null && _parseAmount(item['sell_price']) > 0) {
                 materialPriceController.text = item['sell_price'].toString();
              } else {
                 materialPriceController.text = item['buy_price']?.toString() ?? '0';
              }
           }
           _calculateFromPrice();
        });
     }
  }

  Future<void> _fetchMaterialBuyPrice(String? supplierName, String materialName) async {
    if (supplierName == null || supplierName.trim().isEmpty || materialName.trim().isEmpty) return;
    try {
      final data = Provider.of<DataProvider>(context, listen: false);
      final sMap = data.suppliers.firstWhere(
        (s) => (s['name'] ?? '').toString().trim().toLowerCase() == supplierName.trim().toLowerCase(),
        orElse: () => {},
      );
      if (sMap.isNotEmpty && sMap['id'] != null) {
        final materials = await data.getSupplierMaterials(sMap['id'].toString());
        final mat = materials.firstWhere(
          (m) => (m['material_name'] ?? '').toString().trim().toLowerCase() == materialName.trim().toLowerCase(),
          orElse: () => {},
        );
        if (mat.isNotEmpty && mat['buy_price'] != null) {
          double bp = _parseAmount(mat['buy_price']);
          if (bp > 0) {
            setState(() {
              currentBuyPrice = bp;
              if (mat['unit'] != null && mat['unit'].toString().isNotEmpty) {
                currentUnit = mat['unit'].toString();
              }
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSupplierMaterials(String? supplierName) async {
    if (supplierName == null || supplierName.trim().isEmpty) {
      if (mounted && _supplierMaterials.isNotEmpty) {
        setState(() {
          _supplierMaterials = [];
        });
      }
      return;
    }

    try {
      final data = Provider.of<DataProvider>(context, listen: false);
      final cleanName = supplierName.trim().toLowerCase();

      final sMap = data.suppliers.firstWhere(
        (s) => (s['name'] ?? '').toString().trim().toLowerCase() == cleanName,
        orElse: () => {},
      );

      List<Map<String, dynamic>> dbMaterials = [];
      if (sMap.isNotEmpty && sMap['id'] != null) {
        dbMaterials = await data.getSupplierMaterials(sMap['id'].toString());
      }

      if (mounted) {
        setState(() {
          _supplierMaterials = dbMaterials;
        });
      }
    } catch (_) {}
  }

  void _onSupplierOrMaterialChanged() {
    _loadSupplierMaterials(selectedSupplier);
    if (selectedSupplier != null && materialNameController.text.isNotEmpty) {
      _fetchMaterialBuyPrice(selectedSupplier, materialNameController.text);
    }
  }

  void _calculateTotal() {
    if (_isAmountManuallyEdited) {
      _syncGrandTotal();
      return;
    }
    final duration = double.tryParse(durationController.text) ?? 1.0;
    final rate = double.tryParse(rateController.text) ?? 0.0;
    final batta = double.tryParse(battaController.text) ?? 0.0;
    final rentPlusBatta = (duration * rate) + batta;
    setState(() {
      totalController.text = rentPlusBatta > 0 ? rentPlusBatta.toStringAsFixed(0) : '0';
    });
    _syncGrandTotal();
  }

  void _onAmountEdited() {
    if (!_isAmountManuallyEdited) {
      setState(() {
        _isAmountManuallyEdited = true;
      });
    }
    final duration = double.tryParse(durationController.text) ?? 1.0;
    final amount = double.tryParse(totalController.text) ?? 0.0;
    final batta = double.tryParse(battaController.text) ?? 0.0;
    if (duration > 0 && amount >= batta) {
      final newRate = (amount - batta) / duration;
      rateController.text = newRate > 0 ? newRate.toStringAsFixed(0) : '0';
    }
    _syncGrandTotal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'EDIT VEHICLE / MATERIAL' : 'ADD VEHICLE / MATERIAL'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteEntry,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // ROW 1: Date & Customer Name
                    Row(
                      children: [
                        // Date Picker Button
                        Expanded(
                          flex: 1,
                          child: InkWell(
                            onTap: () async {
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
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: JarvisTheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd MMM yyyy').format(selectedDate),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Customer Name Autocomplete
                        Expanded(
                          flex: 2,
                          child: Consumer<DataProvider>(
                            builder: (context, data, _) {
                              return Autocomplete<Map<String, dynamic>>(
                                focusNode: customerFocusNode,
                                textEditingController: customerController,
                                displayStringForOption: (option) => option['name'].toString(),
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) {
                                    return const Iterable<Map<String, dynamic>>.empty();
                                  }
                                  final input = textEditingValue.text.toLowerCase();
                                  return data.customers.where((c) {
                                    final name = (c['name'] ?? '').toString().toLowerCase();
                                    final phone = (c['phone'] ?? '').toString().toLowerCase();
                                    return name.contains(input) || phone.contains(input);
                                  });
                                },
                                onSelected: (Map<String, dynamic> selection) {
                                  setState(() {
                                    selectedCustomer = selection['name'].toString();
                                    customerController.text = selection['name'].toString();
                                    _updatePriceSelection();
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Customer Name',
                                      hintText: 'Type or select customer',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: Icon(Icons.person, size: 18),
                                    ),
                                    onChanged: (val) {
                                      selectedCustomer = val;
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8.0,
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      child: Container(
                                        width: (MediaQuery.of(context).size.width - 40) * 0.65,
                                        constraints: const BoxConstraints(maxHeight: 250),
                                        child: ListView.separated(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            final name = (option['name'] ?? '').toString();
                                            final phone = (option['phone'] ?? '').toString().trim();
                                            final place = (option['location'] ?? option['place'] ?? option['address'] ?? option['site'] ?? '').toString().trim();

                                            return ListTile(
                                              dense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: Colors.amber.shade100,
                                                child: Icon(Icons.person, size: 18, color: Colors.amber.shade800),
                                              ),
                                              title: Text(
                                                name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                              ),
                                              subtitle: (phone.isNotEmpty || place.isNotEmpty)
                                                  ? Padding(
                                                      padding: const EdgeInsets.only(top: 2),
                                                      child: Row(
                                                        children: [
                                                          if (phone.isNotEmpty) ...[
                                                            const Icon(Icons.phone, size: 12, color: Colors.pink),
                                                            const SizedBox(width: 3),
                                                            Text(phone, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                          ],
                                                          if (phone.isNotEmpty && place.isNotEmpty)
                                                            Text(' | ', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                                          if (place.isNotEmpty) ...[
                                                            const Icon(Icons.location_on, size: 12, color: Colors.pink),
                                                            const SizedBox(width: 3),
                                                            Text(place, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                                          ],
                                                        ],
                                                      ),
                                                    )
                                                  : null,
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ROW 2: [ V-Type ] | [ V-Num ] | [ Bill No ]
                    Row(
                      children: [
                        // V-Type
                        Expanded(
                          flex: 1,
                          child: Consumer<DataProvider>(
                            builder: (context, data, child) {
                              final existingTypes = data.vehicleRegistry
                                  .map((v) => (v['type'] ?? '').toString().trim())
                                  .where((t) => t.isNotEmpty)
                                  .toSet()
                                  .toList();
                              final allTypes = existingTypes.isNotEmpty
                                  ? existingTypes
                                  : ['Lorry', 'JCB', 'Tractor', 'Hitachi', 'Tipper'];

                              return Autocomplete<String>(
                                key: ValueKey('vtype_$_resetCounter'),
                                textEditingController: typeController,
                                focusNode: typeFocusNode,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return allTypes;
                                  return allTypes.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) {
                                  setState(() {
                                    typeController.text = selection;
                                    if (numberController.text.isNotEmpty) {
                                      final data = Provider.of<DataProvider>(context, listen: false);
                                      final reg = data.vehicleRegistry.firstWhere(
                                        (v) => (v['number'] ?? '').toString().trim().toLowerCase() == numberController.text.trim().toLowerCase(),
                                        orElse: () => {},
                                      );
                                      if (reg.isNotEmpty && (reg['type'] ?? '').toString().trim().toLowerCase() != selection.trim().toLowerCase()) {
                                        numberController.clear();
                                        selectedRegistryId = null;
                                      } else {
                                        _checkAndAutoSelectVehicle(numberController.text);
                                      }
                                    }
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'V-Type *',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      if (numberController.text.isNotEmpty) {
                                        _checkAndAutoSelectVehicle(numberController.text);
                                      }
                                      setState(() {});
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8.0,
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: (MediaQuery.of(context).size.width - 40) / 3,
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              dense: true,
                                              title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // V-Num
                        Expanded(
                          flex: 1,
                          child: Consumer<DataProvider>(
                            builder: (context, data, child) {
                              final Set<String> numbersSeen = {};
                              final List<Map<String, dynamic>> allAvailableVehicles = [];

                              for (var vr in data.vehicleRegistry) {
                                final numStr = (vr['number'] ?? '').toString().trim();
                                if (numStr.isNotEmpty && !numbersSeen.contains(numStr.toLowerCase())) {
                                  numbersSeen.add(numStr.toLowerCase());
                                  allAvailableVehicles.add({
                                    'number': numStr,
                                    'type': (vr['type'] ?? '').toString().trim(),
                                  });
                                }
                              }

                              return Autocomplete<Map<String, dynamic>>(
                                textEditingController: numberController,
                                focusNode: numberFocusNode,
                                displayStringForOption: (option) => option['number'].toString(),
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  final selectedType = typeController.text.trim().toLowerCase();
                                  Iterable<Map<String, dynamic>> matchingVehicles = allAvailableVehicles;

                                  if (selectedType.isNotEmpty) {
                                    matchingVehicles = allAvailableVehicles.where((vehicle) {
                                      final vType = (vehicle['type'] ?? '').toString().toLowerCase().trim();
                                      if (vType.isEmpty) return false;
                                      return vType == selectedType;
                                    });
                                  }

                                  if (textEditingValue.text.isEmpty) return matchingVehicles;
                                  final input = textEditingValue.text.toLowerCase().trim();
                                  return matchingVehicles.where((vehicle) {
                                    final numStr = (vehicle['number'] ?? '').toString().toLowerCase();
                                    return numStr.contains(input);
                                  });
                                },
                                onSelected: (Map<String, dynamic> selection) {
                                  setState(() {
                                    numberController.text = selection['number'].toString();
                                    if (selection['type'] != null && selection['type'].toString().isNotEmpty) {
                                      typeController.text = selection['type'].toString();
                                    }
                                    _autoSelectVehicle(selection['number'].toString(), isManualSelection: true);
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'V-Num *',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      _checkAndAutoSelectVehicle(val);
                                      setState(() {});
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8.0,
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: (MediaQuery.of(context).size.width - 40) / 3,
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          shrinkWrap: true,
                                          itemCount: options.length,
                                          itemBuilder: (BuildContext context, int index) {
                                            final option = options.elementAt(index);
                                            return ListTile(
                                              dense: true,
                                              title: Text('${option['number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              onTap: () => onSelected(option),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Bill No
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: billNoController,
                            decoration: const InputDecoration(
                              labelText: 'Bill No',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ROW 3: [ R-Type ] | [ Qunt ] | [ Rate ] | [ Bata ]
                    Row(
                      children: [
                        // R-Type
                        Expanded(
                          flex: 1,
                          child: Consumer<DataProvider>(
                            builder: (context, data, _) {
                              List<String> activeRateTypes = [];
                              final cleanNum = numberController.text.trim().toLowerCase();
                              final cleanType = typeController.text.trim().toLowerCase();

                              // 1. If V-Num is typed/selected, strictly match V-Num in Vehicle Registry
                              if (cleanNum.isNotEmpty) {
                                try {
                                  final matching = data.vehicleRegistry.firstWhere(
                                    (v) => (v['number'] ?? '').toString().trim().toLowerCase() == cleanNum,
                                  );
                                  Map<String, dynamic> rates = {};
                                  if (matching['rates'] != null) {
                                    try { rates = Map<String, dynamic>.from(jsonDecode(matching['rates'])); } catch (_) {}
                                  }
                                  if (rates.isEmpty) {
                                    if (matching['rate_hour']?.isNotEmpty ?? false) rates['Hour'] = matching['rate_hour'];
                                    if (matching['rate_day']?.isNotEmpty ?? false) rates['Day'] = matching['rate_day'];
                                    if (matching['rate_trip']?.isNotEmpty ?? false) rates['Trip'] = matching['rate_trip'];
                                  }
                                  if (rates.isNotEmpty) {
                                    activeRateTypes = rates.keys.toList();
                                  }
                                } catch (_) {}
                              }

                              // 2. If V-Num is empty/new, check matching V-Type in Vehicle Registry
                              if (activeRateTypes.isEmpty && cleanType.isNotEmpty) {
                                final Set<String> typeRates = {};
                                for (var reg in data.vehicleRegistry) {
                                  final regType = (reg['type'] ?? '').toString().trim().toLowerCase();
                                  if (regType == cleanType) {
                                    if (reg['rates'] != null) {
                                      try {
                                        Map<String, dynamic> r = jsonDecode(reg['rates']);
                                        typeRates.addAll(r.keys);
                                      } catch (_) {}
                                    }
                                    if (reg['rate_hour']?.isNotEmpty ?? false) typeRates.add('Hour');
                                    if (reg['rate_day']?.isNotEmpty ?? false) typeRates.add('Day');
                                    if (reg['rate_trip']?.isNotEmpty ?? false) typeRates.add('Trip');
                                  }
                                }
                                if (typeRates.isNotEmpty) {
                                  activeRateTypes = typeRates.toList();
                                }
                              }

                              // 3. Fallback to availableRateTypes if present
                              if (activeRateTypes.isEmpty && availableRateTypes.isNotEmpty) {
                                activeRateTypes = availableRateTypes;
                              }

                              // 4. Default minimal fallback if no vehicle/type rates found anywhere
                              if (activeRateTypes.isEmpty) {
                                activeRateTypes = ['Day', 'Hour', 'Trip'];
                              }

                              final Map<String, String> normalizedMap = {};
                              for (var t in activeRateTypes) {
                                if (t.trim().isEmpty) continue;
                                String norm = t[0].toUpperCase() + t.substring(1).toLowerCase();
                                normalizedMap[norm.toLowerCase()] = norm;
                              }

                              String normCurrent = (currentRateType.isNotEmpty)
                                  ? (currentRateType[0].toUpperCase() + currentRateType.substring(1).toLowerCase())
                                  : 'Day';

                              if (!normalizedMap.containsValue(normCurrent)) {
                                normCurrent = normalizedMap.values.isNotEmpty ? normalizedMap.values.first : 'Day';
                              }

                              return DropdownButtonFormField<String>(
                                key: ValueKey('${cleanNum}_${cleanType}_${normCurrent}_${normalizedMap.keys.join("_")}'),
                                initialValue: normCurrent,
                                decoration: const InputDecoration(
                                  labelText: 'R-Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: normalizedMap.values
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12))))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      currentRateType = val;
                                      String? matchingRate = _getRateForType(val);
                                      if (matchingRate != null && matchingRate.isNotEmpty) {
                                        rateController.text = matchingRate;
                                        _calculateTotal();
                                      }
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Qunt
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: durationController,
                            decoration: const InputDecoration(
                              labelText: 'Qunt',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateTotal(),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Rate
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: rateController,
                            decoration: const InputDecoration(
                              labelText: 'Rate (₹)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateTotal(),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Bata
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: battaController,
                            decoration: const InputDecoration(
                              labelText: 'Bata (₹)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _calculateTotal(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ROW 4: [ Amount ] | [ Received ] | [ Driver ]
                    Row(
                      children: [
                        // Amount
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: totalController,
                            decoration: InputDecoration(
                              labelText: 'Amount (₹)',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isAmountManuallyEdited ? Icons.edit_off : Icons.edit,
                                  color: _isAmountManuallyEdited ? JarvisTheme.primary : Colors.grey,
                                  size: 18,
                                ),
                                tooltip: _isAmountManuallyEdited
                                    ? 'Manual amount active (Click to reset auto-calc)'
                                    : 'Edit amount manually',
                                onPressed: () {
                                  setState(() {
                                    _isAmountManuallyEdited = !_isAmountManuallyEdited;
                                    if (!_isAmountManuallyEdited) {
                                      _calculateTotal();
                                    }
                                  });
                                },
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _onAmountEdited(),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Received
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: paidController,
                            decoration: const InputDecoration(
                              labelText: 'Received (₹)',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Driver
                        Expanded(
                          flex: 1,
                          child: Consumer<DataProvider>(
                            builder: (context, data, _) {
                              final Set<String> driverSet = {
                                ...data.allDrivers.map((d) => (d['name'] ?? d['driver_name'] ?? '').toString().trim()),
                                ...data.allVehicles.map((v) => (v['driver'] ?? '').toString().trim()),
                                ...data.allLabour.map((l) => (l['name'] ?? '').toString().trim()),
                                ...data.vehiclePayments.map((vp) => (vp['driver'] ?? '').toString().trim()),
                                ...data.vehicleRegistry.map((vr) => (vr['driver'] ?? '').toString().trim()),
                              };
                              driverSet.removeWhere((n) => n.isEmpty);

                              final List<String> registeredDrivers = driverSet.toList();

                              return Autocomplete<String>(
                                focusNode: driverFocusNode,
                                textEditingController: driverController,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (registeredDrivers.isEmpty) {
                                    return const Iterable<String>.empty();
                                  }
                                  if (textEditingValue.text.isEmpty) {
                                    return registeredDrivers;
                                  }
                                  final input = textEditingValue.text.toLowerCase().trim();
                                  return registeredDrivers.where((d) => d.toLowerCase().contains(input));
                                },
                                onSelected: (String selection) {
                                  setState(() {
                                    driverController.text = selection;
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: const InputDecoration(
                                      labelText: 'Driver',
                                      hintText: 'Type or select driver',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      setState(() {});
                                    },
                                  );
                                },
                                optionsViewBuilder: (context, onSelected, options) {
                                  final cardWidth = (MediaQuery.of(context).size.width - 40) / 3;
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 8.0,
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.white,
                                      child: SizedBox(
                                        width: cardWidth,
                                        child: Container(
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          child: ListView.separated(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                                            itemBuilder: (BuildContext context, int index) {
                                              final option = options.elementAt(index);
                                              return ListTile(
                                                dense: true,
                                                leading: const Icon(Icons.person, size: 16, color: JarvisTheme.primary),
                                                title: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // ROW 5: Desc
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Desc (Description / Notes)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.description, size: 18),
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 10),

                    // ROW 6: [ Select Supplier ] | [ Select Material ] | [ Mat Qty ]
                    Row(
                      children: [
                        // Select Supplier
                        Expanded(
                          flex: 2,
                          child: Consumer<DataProvider>(
                            builder: (context, data, _) {
                              final List<String> supplierList = data.generalSuppliers
                                  .map((s) => (s['name'] ?? '').toString().trim())
                                  .where((name) => name.isNotEmpty)
                                  .toSet()
                                  .toList()..sort();

                              return Autocomplete<String>(
                                textEditingController: supplierController,
                                focusNode: supplierFocusNode,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return supplierList;
                                  return supplierList.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) {
                                  setState(() {
                                    selectedSupplier = selection;
                                    supplierController.text = selection;
                                    _onSupplierOrMaterialChanged();
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Select Supplier (Optional)',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.store, size: 18),
                                      suffixIcon: supplierList.isNotEmpty
                                          ? PopupMenuButton<String>(
                                              icon: const Icon(Icons.arrow_drop_down),
                                              onSelected: (String value) {
                                                controller.text = value;
                                                setState(() {
                                                  selectedSupplier = value;
                                                  supplierController.text = value;
                                                  _onSupplierOrMaterialChanged();
                                                });
                                              },
                                              itemBuilder: (BuildContext context) {
                                                return supplierList.map((String choice) {
                                                  return PopupMenuItem<String>(
                                                    value: choice,
                                                    child: Text(choice),
                                                  );
                                                }).toList();
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        selectedSupplier = val.trim().isEmpty ? null : val.trim();
                                        _onSupplierOrMaterialChanged();
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Select Material
                        Expanded(
                          flex: 2,
                          child: Consumer<DataProvider>(
                            builder: (context, data, _) {
                              final String supplier = selectedSupplier?.trim().toLowerCase() ?? '';
                              List<String> materialList = [];

                              if (supplier.isNotEmpty) {
                                final Set<String> supplierMatSet = {};
                                
                                final sMap = data.suppliers.firstWhere(
                                  (s) => (s['name'] ?? '').toString().trim().toLowerCase() == supplier,
                                  orElse: () => {},
                                );

                                if (sMap.isNotEmpty) {
                                  final matStr = (sMap['material'] ?? '').toString().trim();
                                  if (matStr.isNotEmpty) {
                                    for (var m in matStr.split(',')) {
                                      final t = m.trim();
                                      if (t.isNotEmpty) supplierMatSet.add(t);
                                    }
                                  }
                                }

                                for (var sm in _supplierMaterials) {
                                  final m = (sm['material_name'] ?? '').toString().trim();
                                  if (m.isNotEmpty) supplierMatSet.add(m);
                                }

                                for (var v in data.allVehicles) {
                                  if ((v['supplier'] ?? '').toString().trim().toLowerCase() == supplier) {
                                    final m = (v['material_name'] ?? '').toString().trim();
                                    if (m.isNotEmpty) supplierMatSet.add(m);
                                  }
                                }

                                for (var e in data.allSiteExpenses) {
                                  if ((e['supplier'] ?? '').toString().trim().toLowerCase() == supplier) {
                                    final m = (e['material_name'] ?? '').toString().trim();
                                    if (m.isNotEmpty) supplierMatSet.add(m);
                                  }
                                }

                                materialList = supplierMatSet.toList()..sort();
                              } else {
                                final Set<String> materialSet = {
                                  ...data.allVehicles.map((v) => (v['material_name'] ?? '').toString().trim()),
                                  ...data.allSiteExpenses.map((e) => (e['material_name'] ?? '').toString().trim()),
                                  'Sand', 'M-Sand', 'P-Sand', 'Gravel', 'Blue Metal', 'Soil', 'Dust', 'Bricks', 'Jelly',
                                };
                                materialSet.removeWhere((m) => m.isEmpty);
                                materialList = materialSet.toList()..sort();
                              }

                              return Autocomplete<String>(
                                textEditingController: materialNameController,
                                focusNode: materialFocusNode,
                                optionsBuilder: (TextEditingValue textEditingValue) {
                                  if (textEditingValue.text.isEmpty) return materialList;
                                  return materialList.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                                },
                                onSelected: (String selection) {
                                  setState(() {
                                    materialNameController.text = selection;
                                    _onSupplierOrMaterialChanged();
                                  });
                                },
                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    decoration: InputDecoration(
                                      labelText: 'Select Material (Optional)',
                                      border: const OutlineInputBorder(),
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.category, size: 18),
                                      suffixIcon: materialList.isNotEmpty
                                          ? PopupMenuButton<String>(
                                              icon: const Icon(Icons.arrow_drop_down),
                                              onSelected: (String value) {
                                                controller.text = value;
                                                setState(() {
                                                  materialNameController.text = value;
                                                  _onSupplierOrMaterialChanged();
                                                });
                                              },
                                              itemBuilder: (BuildContext context) {
                                                return materialList.map((String choice) {
                                                  return PopupMenuItem<String>(
                                                    value: choice,
                                                    child: Text(choice),
                                                  );
                                                }).toList();
                                              },
                                            )
                                          : null,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _onSupplierOrMaterialChanged();
                                      });
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Material Qty
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: quantityController,
                            decoration: const InputDecoration(
                              labelText: 'Mat Qty',
                              hintText: 'Qty',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // GRAND TOTAL & SAVE BUTTONS IN ONE COMPACT CARD
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: grandTotalController,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                      decoration: InputDecoration(
                        labelText: 'Final Grand Total (₹)',
                        labelStyle: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                        prefixText: '₹ ',
                        filled: true,
                        fillColor: Colors.green.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.3))),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: JarvisTheme.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _save(andNew: true),
                              child: const Text('SAVE & ADD ANOTHER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: JarvisTheme.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _save(andNew: false),
                              child: const Text('SAVE ENTRY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save({bool andNew = false}) async {
    final totalAmount = double.tryParse(totalController.text) ?? 0.0;
    final battaAmount = double.tryParse(battaController.text) ?? 0.0;
    final materialCost = double.tryParse(materialAmountController.text) ?? 0.0;
    final rentAmount = (totalAmount - battaAmount >= 0) ? (totalAmount - battaAmount) : totalAmount;
    
    // VALIDATION
    if (widget.isOwn) {
       if (numberController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or enter a Vehicle')));
          return;
       }
    } else {
       if (numberController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Vehicle Number')));
          return;
       }
       if (totalAmount == 0 && battaAmount == 0 && materialCost == 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Rent Amount, Batta OR Material Cost')));
          return;
       }
    }
    
    final grandTotal = totalAmount + materialCost;
    
    final paid = double.tryParse(paidController.text) ?? 0.0;
    final balance = grandTotal - paid;

    final data = Provider.of<DataProvider>(context, listen: false);

    double buyPriceToSave = currentBuyPrice ?? 0.0;
    if (buyPriceToSave <= 0 && materialPriceController.text.isNotEmpty) {
      buyPriceToSave = _parseAmount(materialPriceController.text);
    }
    if (buyPriceToSave <= 0 && selectedSupplier != null && materialNameController.text.isNotEmpty) {
      try {
        final prev = data.allVehicles.firstWhere(
          (v) => (v['supplier'] ?? '').toString().trim().toLowerCase() == selectedSupplier!.trim().toLowerCase() &&
                 (v['material_name'] ?? '').toString().trim().toLowerCase() == materialNameController.text.trim().toLowerCase() &&
                 _parseAmount(v['buy_price']) > 0,
          orElse: () => {},
        );
        if (prev.isNotEmpty) {
          buyPriceToSave = _parseAmount(prev['buy_price']);
        }
      } catch (_) {}
    }

    final newVehicle = {
      if (_isEditing && _editingId != null) 'id': _editingId else 'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'number': numberController.text,
      'type': typeController.text,
      'bill_no': billNoController.text.trim(),
      'isOwnSite': _isOwnSite ? 1 : 0,
      'total': '₹${grandTotal.toStringAsFixed(0)}',
      'rent_amount': '₹${rentAmount.toStringAsFixed(0)}',
      'batta': '₹${battaAmount.toStringAsFixed(0)}',
      'batta_amount': battaAmount.toStringAsFixed(0),
      'paid': '₹${paid.toStringAsFixed(0)}',
      'manual_desc': descriptionController.text,
      'driver': driverController.text.trim(),
      'balance': '₹${balance.toStringAsFixed(0)}',
      'date': DateFormat('dd MMM yyyy').format(selectedDate),
      'status': balance <= 0 ? StatusType.paid : StatusType.pending,
      'isOwn': widget.isOwn ? 1 : 0,
      'isRentedOut': widget.isOwn ? 1 : 0,
      'site': selectedSite ?? 'General',
      'customer': selectedCustomer,
      'rate': rateController.text,
      'duration': durationController.text,
      'rate_type': currentRateType,
      'supplier': selectedSupplier,
      'material_name': materialNameController.text,
      'quantity': quantityController.text,
      'unit': currentUnit,
      'material_amount': materialAmountController.text,
      'unit_price': materialPriceController.text,
      'buy_price': buyPriceToSave > 0 ? buyPriceToSave.toString() : (currentBuyPrice?.toString() ?? '0'),
    };
    
    if (_isEditing && _editingId != null) {
      double oldTotal = _parseAmount(widget.vehicle!['total']);
      double newTotal = grandTotal;
      double diff = newTotal - oldTotal;

      await data.updateVehicle(_editingId!, newVehicle);
      
      if (widget.isOwn && selectedCustomer != null) {
        // Handled by _syncBalances in data provider
      }
      
      // Update Supplier Balance Logic (Diff) - Skipping complex diff logic for simplicity/safety
      // Ideally we should reverse old and apply new.
      
    } else {
      await data.addVehicle(newVehicle);
      
      if (widget.isOwn && selectedCustomer != null) {
        // Handled by _syncBalances in data provider
      }
      
      // Update Supplier Balance Logic (handled via Ledgers reading vehicles table directly now)
      if (selectedSupplier != null && quantityController.text.isNotEmpty) {
           // We no longer create a duplicate 'site_expenses' entry. 
           // The DataProvider getters will be updated to read from 'vehicles' table.
      }
    }
    if (andNew) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Saved. Add another.')));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddVehiclePaymentScreen(
              isOwn: widget.isOwn,
              initialCustomer: widget.initialCustomer,
              initialSite: widget.initialSite,
            ),
          ),
        );
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }
  double _parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll('₹', '').replaceAll(',', '').trim()) ?? 0.0;
    }
    return 0.0;
  }

  void _calculateFromQty() {
     setState(() {
       double qty = _parseAmount(quantityController.text);
       double price = _parseAmount(materialPriceController.text);
       double amount = _parseAmount(materialAmountController.text);
       
       if (price > 0) {
         materialAmountController.text = (qty * price).toStringAsFixed(0);
       } else if (amount > 0 && qty > 0) {
         materialPriceController.text = (amount / qty).toStringAsFixed(2);
       }
     });
  }

  void _calculateFromPrice() {
     setState(() {
       double qty = _parseAmount(quantityController.text);
       double price = _parseAmount(materialPriceController.text);
       if (qty > 0) {
          materialAmountController.text = (qty * price).toStringAsFixed(0);
       }
     });
  }

  void _calculateFromAmount() {
     setState(() {
       double qty = _parseAmount(quantityController.text);
       double amount = _parseAmount(materialAmountController.text);
       if (qty > 0) {
          materialPriceController.text = (amount / qty).toStringAsFixed(2);
       }
     });
  }

  Future<void> _deleteEntry() async {
     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Delete Entry'),
         content: const Text('Are you sure you want to delete this vehicle entry?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
           TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
         ],
       ),
     );
     
     if (confirm == true && _editingId != null) {
        final data = Provider.of<DataProvider>(context, listen: false);
        await data.deleteVehicle(_editingId!);
        if (mounted) Navigator.pop(context);
     }
  }

  // TOTALS SYNC LOGIC
  void _syncGrandTotal() {
    if (_isUpdatingInternally) return;
    _isUpdatingInternally = true;
    double amount = _parseAmount(totalController.text);
    double material = _parseAmount(materialAmountController.text);
    double total = amount + material;
    String val = total.toStringAsFixed(0);
    if (grandTotalController.text != val) grandTotalController.text = val;
    _isUpdatingInternally = false;
  }
  void _onHireChargeChanged() => _syncGrandTotal();
  void _onMaterialAmountChanged() => _syncGrandTotal();
  void _onGrandTotalChanged() {
    if (_isUpdatingInternally) return;
    _isUpdatingInternally = true;
    double total = _parseAmount(grandTotalController.text);
    double material = _parseAmount(materialAmountController.text);
    double amount = total - material;
    String amountVal = amount >= 0 ? amount.toStringAsFixed(0) : '0';
    if (totalController.text != amountVal) {
      totalController.text = amountVal;
      if (!_isAmountManuallyEdited) {
        _isAmountManuallyEdited = true;
      }
    }
    _isUpdatingInternally = false;
  }
}
