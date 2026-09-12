import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import 'add_vehicle_payment_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';
import 'package:share_plus/share_plus.dart';

class VehiclePaymentsScreen extends StatefulWidget {
  final bool isOwn;
  final String? customerName;
  const VehiclePaymentsScreen({super.key, this.isOwn = true, this.customerName});

  @override
  State<VehiclePaymentsScreen> createState() => _VehiclePaymentsScreenState();
}

class _VehiclePaymentsScreenState extends State<VehiclePaymentsScreen> {
  DateTimeRange? _selectedDateRange;
  String? _filterVehicleNo;
  String? _filterVehicleType;
  String? _filterDriver;
  String _sortBy = 'Date'; 
  final Set<String> _selectedIds = {};
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: JarvisTheme.background,
        appBar: AppBar(
          title: Text(widget.customerName != null ? '${widget.customerName!.toUpperCase()} - VEHICLES' : (widget.isOwn ? 'OWN VEHICLES' : 'RENTAL VEHICLES')),
          bottom: const TabBar(
            indicatorColor: JarvisTheme.secondary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'PENDING'),
              Tab(text: 'HISTORY'),
            ],
          ),
          actions: [
            // Filter Icon (Replaces standalone Date Picker)
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  tooltip: 'Filter',
                  onPressed: _showFilterDialog,
                ),
                if (_filterVehicleType != null || _filterVehicleNo != null || _filterDriver != null || _selectedDateRange != null)
                   Positioned(
                     right: 8,
                     top: 8,
                     child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                   )
              ],
                ),
            IconButton(
                icon: const Icon(Icons.share, color: Colors.green),
                tooltip: 'Share via WhatsApp',
                onPressed: () => _handlePdfAction(share: true),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert), // Changed icon to standard 3-dot
              tooltip: 'Options',
              onSelected: (val) {
                if (val == 'pdf') {
                  _handlePdfAction();
                } else if (val == 'excel') {
                  _handleExcelAction();
                } else {
                  setState(() => _sortBy = val);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Date', child: Text('Sort by Date')),
                const PopupMenuItem(value: 'Vehicle', child: Text('Sort by Vehicle No')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf, color: Colors.grey), SizedBox(width: 8), Text('Save PDF')])),
                const PopupMenuItem(value: 'excel', child: Row(children: [Icon(Icons.grid_on, color: Colors.grey), SizedBox(width: 8), Text('Export Excel')])),
              ],
            ),
            const DevBrandingBadge()
          ],
        ),
        floatingActionButton: (AppConfig.isReadOnly || _selectedIds.isNotEmpty) ? null : FloatingActionButton(
          onPressed: () {
             Map<String, dynamic>? defaults;
             if (widget.customerName != null) {
               final data = Provider.of<DataProvider>(context, listen: false);
               final customerVehicles = data.allVehicles.where((v) => v['customer'] == widget.customerName).toList();
               if (customerVehicles.isNotEmpty) {
                 final last = customerVehicles.first;
                 defaults = {
                   'number': last['number'],
                   'type': last['type'],
                   'rate': last['rate'],
                   'rate_type': last['rate_type'],
                 };
               }
             }
             Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: widget.isOwn, initialCustomer: widget.customerName, defaults: defaults)));
          },
          backgroundColor: JarvisTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Consumer<DataProvider>(
          builder: (context, data, child) {
            // 1. Base Filter (Owner/Customer)
            List<Map<String, dynamic>> filteredVehicles = data.allVehicles.where((v) {
              if (widget.customerName != null) {
                if (v['customer'] != widget.customerName) return false;
              }
              if (widget.isOwn) {
                return v['isOwn'] == true;
              }
              return v['isOwn'] == false;
            }).toList();
  
            // 1.5 Vehicle Type Filter
            if (_filterVehicleType != null) {
              filteredVehicles = filteredVehicles.where((v) => (v['type'] ?? '').toString().trim() == _filterVehicleType).toList();
            }

            // 1.6 Vehicle Number Filter
            if (_filterVehicleNo != null) {
              filteredVehicles = filteredVehicles.where((v) => (v['number'] ?? '').toString().trim() == _filterVehicleNo).toList();
            }

            // 1.7 Driver Filter
            if (_filterDriver != null) {
              filteredVehicles = filteredVehicles.where((v) => (v['driver'] ?? '').toString().trim().toLowerCase() == _filterDriver!.toLowerCase()).toList();
            }

            // 2. Date Filter
            if (_selectedDateRange != null) {
              filteredVehicles = filteredVehicles.where((v) {
                try {
                  DateTime date = DateFormat('dd MMM yyyy').parse(v['date']);
                  return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                      date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
                } catch (e) {
                  return false;
                }
              }).toList();
            }

            // 3. Split into Pending/History
            final pending = filteredVehicles.where((v) => (data.parseAmount(v['balance']) > 0)).toList();
            final history = filteredVehicles.where((v) => (data.parseAmount(v['balance']) <= 0)).toList();

            // 4. Sort Helper
            void sortList(List<Map<String, dynamic>> list) {
              list.sort((a, b) {
                if (_sortBy == 'Vehicle') {
                  int cmp = (a['number'] ?? '').compareTo(b['number'] ?? '');
                  if (cmp != 0) return cmp;
                }
                // Secondary/Default sort by Date (Desc)
                try {
                  DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
                  DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
                  return db.compareTo(da); 
                } catch (_) { return 0; }
              });
            }

            sortList(pending);
            sortList(history);
  
            return Column(
              children: [
                if (_selectedDateRange != null || _filterVehicleNo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: JarvisTheme.secondary.withValues(alpha: 0.1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt, size: 16, color: JarvisTheme.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                               if (_filterVehicleNo != null) 'Vehicle: $_filterVehicleNo',
                               if (_selectedDateRange != null) 'Date: ${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                            ].join(', '),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: JarvisTheme.secondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedDateRange = null;
                            _filterVehicleNo = null;
                          }),
                          child: const Icon(Icons.close, size: 16, color: JarvisTheme.secondary),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildVehicleList(allVehicles: pending, isOwn: widget.isOwn, data: data, isSelectionEnabled: !widget.isOwn),
                      _buildVehicleList(allVehicles: history, isOwn: widget.isOwn, data: data, isSelectionEnabled: false),
                    ],
                  ),
                ),
                
                // Bottom Payment Bar
                if (_selectedIds.isNotEmpty && !AppConfig.isReadOnly && !widget.isOwn)
                  Builder(
                    builder: (context) {
                      double selectedTotal = 0;
                      for (String id in _selectedIds) {
                         final v = data.allVehicles.firstWhere((e) => e['id'] == id, orElse: () => {});
                         if (v.isNotEmpty) {
                           selectedTotal += data.parseAmount(v['balance']);
                         }
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            )
                          ],
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_selectedIds.length} Vehicles Selected', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  Text('₹${selectedTotal.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: JarvisTheme.primary)),
                                ],
                              ),
                              const Spacer(),
                              // Pay Button
                              ElevatedButton.icon(
                                onPressed: () => _showBulkPaymentDialog(context, selectedTotal),
                                icon: const Icon(Icons.payment),
                                label: const Text('PAY NOW'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: JarvisTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handlePdfAction({bool share = false}) {
    final data = Provider.of<DataProvider>(context, listen: false);
    List<Map<String, dynamic>> filtered = data.allVehicles.where((v) {
      if (widget.customerName != null) {
        if (v['customer'] != widget.customerName) return false;
      }
      if (widget.isOwn) {
        return v['isOwn'] == true;
      }
      return v['isOwn'] == false;
    }).toList();

    // 1.5 Vehicle Filter
    if (_filterVehicleNo != null) {
      filtered = filtered.where((v) => v['number'] == _filterVehicleNo).toList();
    }

    // 2. Date Filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((v) {
        try {
          DateTime date = DateFormat('dd MMM yyyy').parse(v['date']);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Determine Final List
    List<Map<String, dynamic>> finalItems;
    if (_selectedIds.isNotEmpty) {
      finalItems = filtered.where((v) => _selectedIds.contains(v['id'])).toList();
    } else {
      // Default: Print All UNPAID (Pending) that match filters
      finalItems = filtered.where((v) => data.parseAmount(v['balance']) > 0).toList();
    }

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to print')));
      return;
    }

    _generatePdf(context, finalItems, share: share);
  }

  void _handleExcelAction() {
    final data = Provider.of<DataProvider>(context, listen: false);
    List<Map<String, dynamic>> filtered = data.allVehicles.where((v) {
      if (widget.customerName != null) {
        if (v['customer'] != widget.customerName) return false;
      }
      if (widget.isOwn) {
        return v['isOwn'] == true;
      }
      return v['isOwn'] == false;
    }).toList();

    // 1.5 Vehicle Filter
    if (_filterVehicleNo != null) {
      filtered = filtered.where((v) => v['number'] == _filterVehicleNo).toList();
    }

    // 2. Date Filter
    if (_selectedDateRange != null) {
      filtered = filtered.where((v) {
        try {
          DateTime date = DateFormat('dd MMM yyyy').parse(v['date']);
          return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Determine Final List
    List<Map<String, dynamic>> finalItems;
    if (_selectedIds.isNotEmpty) {
      finalItems = filtered.where((v) => _selectedIds.contains(v['id'])).toList();
    } else {
      finalItems = filtered.where((v) => data.parseAmount(v['balance']) > 0).toList();
    }

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to export')));
      return;
    }

    _generateExcel(context, finalItems);
  }

  Future<void> _generatePdf(BuildContext context, List<Map<String, dynamic>> displayedBills, {bool share = false}) async {
    final data = Provider.of<DataProvider>(context, listen: false);
    
    // 1. Identify Scope (All relevant Vehicle Entries/Bills, ignoring date for now)
    final scopeVehicles = data.allVehicles.where((v) {
       if (widget.customerName != null && v['customer'] != widget.customerName) return false;
       if (widget.isOwn && v['isOwn'] != true) return false;
       if (!widget.isOwn && v['isOwn'] == true) return false;
       if (_filterVehicleNo != null && v['number'] != _filterVehicleNo) return false;
       return true;
    }).toList();
    final scopeIds = scopeVehicles.map((v) => v['id']).toSet();

    // 2. Fetch & Filter Payments
    List<Map<String, dynamic>> payments = data.allVehiclePayments.where((p) {
       if (!scopeIds.contains(p['vehicle_id'])) return false;
       
       if (_selectedDateRange != null) {
          try {
            final pDate = DateFormat('dd MMM yyyy').parse(p['date']);
            return pDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
                   pDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          } catch (_) { return false; }
       }
       return true;
    }).toList();
    
    // Sort Payments Descending
    payments.sort((a, b) {
       try {
         return DateFormat('dd MMM yyyy').parse(b['date']).compareTo(DateFormat('dd MMM yyyy').parse(a['date']));
       } catch (_) { return 0; }
    });

    // 3. Prepare PDF Rows
    // Section A: BILLS (Use displayedBills which are already date-filtered)
    final List<List<String>> billRows = displayedBills.map((item) {
       String desc = '';
       if (item['rate'] != null) {
          final unit = item['rate_type'] == 'Trip' ? 'Trips' : (item['rate_type'] ?? 'Unit');
          desc = '${item['duration']} $unit @ Rs. ${item['rate']}/$unit';
       } else {
         desc = item['rate_type'] ?? 'Rent';
       }
       if (item['material_name'] != null && item['material_name'].isNotEmpty) {
         desc += '\n+ ${item['material_name']}';
         if (item['quantity'] != null) desc += ' (${item['quantity']} ${item['unit']})';
       }
       
       // Calculate Billed Amount (Total)
       final billed = data.parseAmount(item['total']).toStringAsFixed(0);
       
       return <String>[
         item['date'] ?? '',
         item['number'] ?? '',
         item['type'] ?? '',
         desc,
         billed
       ];
    }).toList();

    // Section B: PAYMENTS
    final List<List<String>> paymentRows = payments.map((p) {
       // Try to find vehicle number for context
       final v = scopeVehicles.firstWhere((e) => e['id'] == p['vehicle_id'], orElse: () => {});
       return <String>[
         p['date'] ?? '',
         v.isNotEmpty ? v['number'] : '',
         'Payment',
         'Payment Received',
         p['amount'] ?? ''
       ];
    }).toList();

    // Combine
    final List<List<String>> finalRows = [];
    if (billRows.isNotEmpty) {
       finalRows.add(['--- BILLS / TRIPS ---', '', '', '', '']);
       finalRows.addAll(billRows);
    }
    if (paymentRows.isNotEmpty) {
       if (finalRows.isNotEmpty) finalRows.add(['', '', '', '', '']);
       finalRows.add(['--- PAYMENTS ---', '', '', '', '']);
       finalRows.addAll(paymentRows);
    }

    // Totals
    double totalBilled = 0;
    for (var b in displayedBills) {
      totalBilled += data.parseAmount(b['total']);
    }
    
    double totalPaid = 0;
    for (var p in payments) {
      totalPaid += data.parseAmount(p['amount']);
    }
    
    // Calculate Balance (Scope: Total Outstanding of relevant vehicles?)
    // Or Balance of displayed items?
    // Usually Balance = Total Billed - Total Paid (in period)? 
    // Or Closing Balance of Account?
    // Let's show Total Pending of the Scope (All items matching filter, regardless of date, or just date?)
    // Usually "Outstanding" implies typically current outstanding.
    double totalPending = 0;
    // Calculate pending from ALL relevant vehicles (scopeVehicles) to show "Current Balance"
    for (var v in scopeVehicles) {
      totalPending += data.parseAmount(v['balance']);
    }

    final Map<String, String> totals = {
       'Total Billed': 'Running Total', // Placeholder or sum of list
       'Total Paid': 'Rs. ${totalPaid.toStringAsFixed(0)}',
       'Pending Balance': 'Rs. ${totalPending.toStringAsFixed(0)}',
    };
    // Update Total Billed to sum of displayed
    totals['Total Billed (Selected Period)'] = 'Rs. ${totalBilled.toStringAsFixed(0)}';

    // Fetch Business Settings
    final businessName = await data.getSetting('business_name');
    final logoPath = await data.getLogoPath();

    if (share) {
       // Generate File First
       final file = await PdfService.getLedgerPdfFile(
         title: 'Vehicle Invoice / Report',
         subTitle: widget.customerName != null ? 'Customer: ${widget.customerName}' : 'Vehicle Payment Report',
         headers: ['Date', 'Vehicle', 'Type', 'Description', 'Amount'],
         data: finalRows,
         totals: totals,
         businessName: businessName,
         logoPath: logoPath,
         cellAlignments: {
           0: pw.Alignment.centerLeft,
           1: pw.Alignment.centerLeft,
           2: pw.Alignment.centerLeft,
           3: pw.Alignment.centerLeft,
           4: pw.Alignment.centerRight,
         },
       );

       // Ask User Preference
       showDialog(
         context: context, 
         builder: (context) => AlertDialog(
           title: const Text('Share PDF'),
           content: const Text('Choose how you want to send this file.'),
           actions: [
             TextButton.icon(
               onPressed: () {
                 Navigator.pop(context);
                 Share.shareXFiles([XFile(file.path)], text: 'Ledger');
               }, 
               icon: const Icon(Icons.share), 
               label: const Text('Windows Share')
             ),
             ElevatedButton.icon(
               onPressed: () async {
                 Navigator.pop(context);
                 final success = await PdfService.openWhatsAppWithFile(file.path);
                 if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('File copied! Select Contact in WhatsApp and Press Ctrl+V'), 
                      duration: Duration(seconds: 5),
                      backgroundColor: Colors.green,
                    ));
                 }
               }, 
               icon: const Icon(Icons.copy), 
               label: const Text('Use WhatsApp (Copy & Paste)'),
               style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
             ),
           ],
         )
       );
    } else {
       await PdfService.generateLedgerPdf(
        title: 'Vehicle Invoice / Report',
        subTitle: widget.customerName != null ? 'Customer: ${widget.customerName}' : 'Vehicle Payment Report',
        headers: ['Date', 'Vehicle', 'Type', 'Description', 'Amount'],
        data: finalRows,
        totals: totals,
        businessName: businessName,
        logoPath: logoPath,
        cellAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerLeft,
          2: pw.Alignment.centerLeft,
          3: pw.Alignment.centerLeft,
          4: pw.Alignment.centerRight,
        },
       );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Generated Successfully')));
     }
   }

  Future<void> _generateExcel(BuildContext context, List<Map<String, dynamic>> displayedBills) async {
    final data = Provider.of<DataProvider>(context, listen: false);
    
    // 1. Identify Scope (All relevant Vehicle Entries/Bills, ignoring date for now)
    final scopeVehicles = data.allVehicles.where((v) {
       if (widget.customerName != null && v['customer'] != widget.customerName) return false;
       if (widget.isOwn && v['isOwn'] != true) return false;
       if (!widget.isOwn && v['isOwn'] == true) return false;
       if (_filterVehicleNo != null && v['number'] != _filterVehicleNo) return false;
       return true;
    }).toList();

    // 2. Identify Payments matching same scope
    final List<Map<String, dynamic>> scopePayments = [];
    for (var v in scopeVehicles) {
       final payments = data.allVehiclePayments.where((p) => p['vehicle_id'] == v['id']).toList();
       scopePayments.addAll(payments);
    }

    // 3. Apply Date Filters to both lists
    final List<Map<String, dynamic>> finalBills = [];
    for (var b in displayedBills) {
       finalBills.add(b);
    }
    
    final List<Map<String, dynamic>> finalPayments = [];
    for (var p in scopePayments) {
       if (_selectedDateRange != null) {
          try {
             DateTime date = DateFormat('dd MMM yyyy').parse(p['date']);
             if (date.isBefore(_selectedDateRange!.start) || date.isAfter(_selectedDateRange!.end)) {
                continue;
             }
          } catch (_) { continue; }
       }
       finalPayments.add(p);
    }

    // 4. Sort Oldest First
    finalBills.sort((a, b) {
       try {
          return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
       } catch (_) { return 0; }
    });
    finalPayments.sort((a, b) {
       try {
          return DateFormat('dd MMM yyyy').parse(a['date']).compareTo(DateFormat('dd MMM yyyy').parse(b['date']));
       } catch (_) { return 0; }
    });

    final List<List<String>> finalRows = [];
    double totalBilled = 0;

    if (finalBills.isNotEmpty) {
      finalRows.add(['--- BILLS (TRIPS & MAINTENANCE) ---', '', '', '', '']);
      for (var b in finalBills) {
         double amt = data.parseAmount(b['balance']);
         totalBilled += amt;
         String type = b['source_type'] ?? (b['isOwn'] == true ? 'Own' : 'Hire');
         finalRows.add([
            b['date'] ?? '',
            b['number'] ?? '',
            type,
            b['material_name']?.toString().isNotEmpty == true ? b['material_name'] : 'Rent',
            'Rs. ${amt.toInt()}'
         ]);
      }
      finalRows.add(['', '', '', '', '']);
    }

    double totalPaid = 0;
    if (finalPayments.isNotEmpty) {
      finalRows.add(['--- PAYMENTS ---', '', '', '', '']);
      for (var p in finalPayments) {
         double amt = data.parseAmount(p['amount']);
         totalPaid += amt;
         finalRows.add([
            p['date'] ?? '',
            '-',
            'Payment',
            p['description'] ?? '',
            'Rs. ${amt.toInt()}'
         ]);
      }
    }

    final totals = {
       'Total Billed': 'Rs. ${totalBilled.toInt()}',
       'Total Paid': 'Rs. ${totalPaid.toInt()}',
       'Balance Due': 'Rs. ${(totalBilled - totalPaid).toInt()}',
    };

    final businessName = await data.getSetting('business_name');

    await ExcelService.generateLedgerExcel(
       title: 'Vehicle Invoice / Report',
       subTitle: widget.customerName != null ? 'Customer: ${widget.customerName}' : 'Vehicle Payment Report',
       headers: ['Date', 'Vehicle', 'Type', 'Description', 'Amount'],
       data: finalRows,
       totals: totals,
       businessName: businessName,
    );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated Successfully')));
  }

  void _showFilterDialog() {
    final data = Provider.of<DataProvider>(context, listen: false);
    final allVehicles = data.allVehicles.where((v) {
       if (widget.customerName != null) return v['customer'] == widget.customerName;
       if (widget.isOwn) return v['isOwn'] == true;
       return v['isOwn'] == false;
    }).toList();
    
    // Unique Vehicle Types
    final uniqueTypes = allVehicles
        .map((v) => (v['type'] ?? '').toString().trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()..sort();

    // Unique Vehicle Numbers
    final uniqueNumbers = allVehicles
        .map((v) => (v['number'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList()..sort();

    // Unique Drivers
    final driverSet = <String>{};
    for (var v in allVehicles) {
      final d = (v['driver'] ?? '').toString().trim();
      if (d.isNotEmpty) driverSet.add(d);
    }
    for (var dObj in data.allDrivers) {
      final dName = (dObj['name'] ?? '').toString().trim();
      if (dName.isNotEmpty) driverSet.add(dName);
    }
    final uniqueDrivers = driverSet.toList()..sort();
    
    String? tempVehicleType = _filterVehicleType;
    String? tempVehicleNo = _filterVehicleNo;
    String? tempDriver = _filterDriver;
    DateTimeRange? tempDateRange = _selectedDateRange;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Filter Vehicles'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Vehicle Type', border: OutlineInputBorder()),
                    initialValue: tempVehicleType,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Vehicle Types')),
                      ...uniqueTypes.map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    ],
                    onChanged: (val) {
                      setDialogState(() => tempVehicleType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Vehicle Number', border: OutlineInputBorder()),
                    initialValue: tempVehicleNo,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Vehicle Numbers')),
                      ...uniqueNumbers.map((no) => DropdownMenuItem(value: no, child: Text(no)))
                    ],
                    onChanged: (val) {
                      setDialogState(() => tempVehicleNo = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Driver', border: OutlineInputBorder()),
                    initialValue: tempDriver,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Drivers')),
                      ...uniqueDrivers.map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    ],
                    onChanged: (val) {
                      setDialogState(() => tempDriver = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Range'),
                    subtitle: Text(tempDateRange == null ? 'All Dates' : '${DateFormat('dd MMM').format(tempDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}'),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        initialDateRange: tempDateRange,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                         builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: JarvisTheme.primary,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: JarvisTheme.primary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => tempDateRange = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                   setDialogState(() {
                     tempVehicleType = null;
                     tempVehicleNo = null;
                     tempDriver = null;
                     tempDateRange = null;
                   });
                },
                child: const Text('RESET'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterVehicleType = tempVehicleType;
                    _filterVehicleNo = tempVehicleNo;
                    _filterDriver = tempDriver;
                    _selectedDateRange = tempDateRange;
                  });
                  Navigator.pop(context);
                },
                child: const Text('APPLY'),
              ),
            ],
          );
        }
      ),
    );
  }
  void _showBulkPaymentDialog(BuildContext context, double totalAmount) {
     final controller = TextEditingController(text: totalAmount.toInt().toString());
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text('Pay for ${_selectedIds.length} Vehicles'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             const Text('Enter amount received (distributed among selected).'),
             const SizedBox(height: 16),
             TextField(
               controller: controller,
               decoration: const InputDecoration(
                 labelText: 'Amount Received (₹)',
                 border: OutlineInputBorder(),
                 prefixText: '₹ ',
               ),
               keyboardType: TextInputType.number,
             ),
           ],
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
           ElevatedButton(
             onPressed: () async {
                final amount = double.tryParse(controller.text);
                if (amount == null || amount <= 0) return;

                final data = Provider.of<DataProvider>(context, listen: false);
                Navigator.pop(context);
                
                double remainingPayment = amount;
                int successCount = 0;
                final vehicles = data.allVehicles;

                for (String id in _selectedIds) {
                  if (remainingPayment <= 0) break;
                  
                  final v = vehicles.firstWhere((element) => element['id'] == id, orElse: () => {});
                  if (v.isNotEmpty) {
                     double totalValue = data.parseAmount(v['total']);
                     double previouslyPaid = data.parseAmount(v['paid']);
                     double balance = totalValue - previouslyPaid;
                     
                     double toPay = (remainingPayment >= balance) ? balance : remainingPayment;
                     double newPaidTotal = previouslyPaid + toPay;
                     
                     await data.updateVehicle(id, {
                       'paid': '₹${newPaidTotal.toInt()}',
                       'date': v['date'],
                     });
                     
                     remainingPayment -= toPay;
                     successCount++;
                  }
                }
                
                setState(() => _selectedIds.clear());
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $successCount items')));
             },
             child: const Text('PAY'),
           ),
         ],
       ),
     );
  }

  void _showInfoDialog(BuildContext context, Map<String, dynamic> item, DataProvider data, bool isOwn) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${item['type'] ?? 'Vehicle'} Info', style: const TextStyle(fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Date', item['date'] ?? 'N/A'),
            _infoRow('Vehicle', item['number'] ?? ''),
            if (item['bill_no'] != null && item['bill_no'].toString().trim().isNotEmpty)
                _infoRow('Bill No', item['bill_no']),
            if (item['customer'] != null && item['customer'].toString().trim().isNotEmpty)
                _infoRow('Customer', item['customer']),
            if (item['supplier'] != null && item['supplier'].toString().trim().isNotEmpty)
                _infoRow('Supplier', item['supplier']),
            _infoRow('Bill Amount', '₹${data.parseAmount(item['total']).toInt()}'),
            if (item['duration'] != null && item['duration'].toString().isNotEmpty && item['duration'].toString() != '0')
                _infoRow('Rental', '${item['duration']} ${item['rate_type'] ?? 'Day'} @ ₹${item['rate'] ?? '0'}'),
            if (data.parseAmount(item['batta'] ?? item['batta_amount']) > 0)
                _infoRow('Batta', '₹${data.parseAmount(item['batta'] ?? item['batta_amount']).toInt()}'),
            if (item['material_name'] != null && item['material_name'].isNotEmpty)
                _infoRow('Material', '${item['material_name']} (Qty: ${item['quantity'] ?? '0'})'),
            if (item['manual_desc'] != null && item['manual_desc'].toString().isNotEmpty)
                _infoRow('Desc', item['manual_desc']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
          if (!AppConfig.isReadOnly)
             ElevatedButton.icon(
               onPressed: () {
                 Navigator.pop(dialogContext);
                 Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: isOwn, vehicle: item)));
               },
               icon: const Icon(Icons.edit),
               label: const Text('EDIT'),
               style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.primary, foregroundColor: Colors.white),
             ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList({required List<Map<String, dynamic>> allVehicles, required bool isOwn, required DataProvider data, required bool isSelectionEnabled}) {
    final vehicles = allVehicles;

    if (vehicles.isEmpty) {
      return const Center(child: Text('No vehicles found'));
    }

    return Column(
      children: [
        if (isSelectionEnabled && vehicles.isNotEmpty && !AppConfig.isReadOnly)
          Container(
            color: Colors.grey.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: vehicles.isNotEmpty && _selectedIds.length == vehicles.length && 
                         vehicles.every((v) => _selectedIds.contains(v['id'])),
                  activeColor: JarvisTheme.primary,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.addAll(vehicles.map((v) => v['id'].toString()));
                      } else {
                        _selectedIds.clear(); // This might clear across tabs if mixed usage, but here vehicles is filtered list. Actually _selectedIds is global to screen.
                        // Better to only remove current list IDs if unchecked? 
                        // For "Select All" behavior on current tab, usually we want to toggle current list.
                        if (val == false) {
                            _selectedIds.removeAll(vehicles.map((v) => v['id'].toString()));
                        }
                      }
                    });
                  },
                ),
                const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
        final vehicle = vehicles[index];
        final id = vehicle['id'];
        final isSelected = _selectedIds.contains(id);
        final balance = data.parseAmount(vehicle['balance']);
        final isPending = balance > 0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: isSelected 
             ? RoundedRectangleBorder(side: const BorderSide(color: JarvisTheme.primary, width: 2), borderRadius: BorderRadius.circular(12))
             : null,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 // Always show checkbox if balance > 0
                 if (isSelectionEnabled && !AppConfig.isReadOnly) 
                   Checkbox(
                     value: isSelected, 
                     activeColor: JarvisTheme.primary,
                     onChanged: (val) {
                       setState(() {
                         if (val == true) {
                           _selectedIds.add(id);
                         } else {
                           _selectedIds.remove(id);
                         }
                       });
                     }
                   ),
                 Expanded(
                   child: InkWell(
                     onTap: () {
                        if (isSelectionEnabled) {
                           setState(() {
                             if (isSelected) {
                               _selectedIds.remove(id);
                             } else {
                               _selectedIds.add(id);
                             }
                           });
                        } else if (!AppConfig.isReadOnly) {
                            _showInfoDialog(context, vehicle, data, isOwn);
                        }
                     },
                     child: Padding(
                       padding: const EdgeInsets.all(8.0),
                       child: Column(
                         children: [
                           Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle['number'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: JarvisTheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                                                // Show Rent info (Duration @ Rate)
                                   Text(
                                     '${vehicle['duration'] ?? '0'} ${vehicle['rate_type'] ?? 'Day'} @ ₹${vehicle['rate'] ?? '0'}',
                                     style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                   ),
                                   // Show Material (if any)
                                   if (vehicle['material_name'] != null && vehicle['material_name'].isNotEmpty)
                                      Text(
                                        '${vehicle['material_name']} (Qty: ${vehicle['quantity'] ?? '0'})',
                                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                   Text(
                                     vehicle['date'],
                                     style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                   ),
                                 ],
                              ), // Closing the first Column
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${data.parseAmount(vehicle['total']).toInt()}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: JarvisTheme.primary,
                                        ),
                                      ),
                                      if (balance > 0 && !isOwn)
                                        Text(
                                          'Bal: ₹${balance.toInt()}',
                                          style: const TextStyle(fontSize: 11, color: Colors.red),
                                        ),
                                    ],
                                  ),
                                      if (!AppConfig.isReadOnly && !isOwn)
                                        IconButton(
                                           icon: const Icon(Icons.edit, size: 20, color: Colors.blueGrey),
                                           onPressed: () {
                                               Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: isOwn, vehicle: vehicle)));
                                           },
                                        )
                                ]
                              ),
                            ],
                           ),
                           // Material Details (Compact)
                           if (vehicle['material_name'] != null && vehicle['material_name'].isNotEmpty)
                             Container(
                               margin: const EdgeInsets.only(top: 8),
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(
                                 color: Colors.orange.shade50,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: Colors.orange.shade100),
                               ),
                               child: Row(
                                 children: [
                                   const Icon(Icons.local_shipping, size: 16, color: Colors.orange),
                                   const SizedBox(width: 8),
                                   Expanded(child: Text('${vehicle['material_name']} - ${vehicle['quantity']} ${vehicle['unit']}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12))),
                                   if (data.parseAmount(vehicle['material_amount']) > 0)
                                     Text('₹${data.parseAmount(vehicle['material_amount']).toInt()}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                             ),
                         ],
                       ),
                     ),
                   ),
                 ),
               ],
            ),
          ),
        );
      },


          ),
        ),
      ],
    );
  }
}
