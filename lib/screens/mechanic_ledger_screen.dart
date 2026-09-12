import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';

class MechanicLedgerScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const MechanicLedgerScreen({super.key, required this.supplierId, required this.supplierName});

  @override
  State<MechanicLedgerScreen> createState() => _MechanicLedgerScreenState();
}

class _MechanicLedgerScreenState extends State<MechanicLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange? _selectedDateRange;

  bool _isDateInRange(String? dateStr) {
    if (_selectedDateRange == null) return true;
    if (dateStr == null) return true;
    try {
      final date = DateFormat('dd MMM yyyy').parse(dateStr);
      return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
             date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    } catch (_) { return false; }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, child) {
        // Look up supplier live balance
        final supplier = data.suppliers.firstWhere((s) => s['id'] == widget.supplierId, orElse: () => {});
        final balance = supplier['balance'] ?? '0';

        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: Text('${widget.supplierName} LEDGER'),
            actions: [
                if (_selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.highlight_off),
                    tooltip: 'Clear Date Filter',
                    onPressed: () => setState(() => _selectedDateRange = null),
                  ),
                IconButton(
                  icon: Icon(Icons.date_range, color: _selectedDateRange != null ? JarvisTheme.secondary : null),
                  onPressed: () async {
                     final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _selectedDateRange,
                     );
                     if (picked != null) {
                        setState(() => _selectedDateRange = picked);
                     }
                  },
                  tooltip: 'Filter by Date',
                ),
                IconButton(
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () => _generatePdf(context, data, save: true),
                    tooltip: 'Save as PDF',
                ),
                IconButton(
                    icon: const Icon(Icons.print),
                    onPressed: () => _generatePdf(context, data),
                    tooltip: 'Print',
                ),
                IconButton(
                    icon: const Icon(Icons.grid_on),
                    onPressed: () => _generateExcel(context, data),
                    tooltip: 'Export as Excel',
                ),
                const DevBrandingBadge()
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: JarvisTheme.secondary,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'BILLS'),
                Tab(text: 'PAYMENTS'),
              ],
            ),
          ),
          bottomNavigationBar: Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('BALANCE DUE', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      Text(balance, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  if (!AppConfig.isReadOnly)
                    ElevatedButton.icon(
                      onPressed: () => _showAddPaymentDialog(context),
                      icon: const Icon(Icons.add_card),
                      label: const Text('ADD PAYMENT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JarvisTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
            future: data.getMechanicLedgerCategorized(widget.supplierName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Center(child: Text('No data found'));
              }

              final bills = snapshot.data!['all_bills']!.where((item) => _isDateInRange(item['date'])).toList();
              final payments = snapshot.data!['paid']!.where((item) => _isDateInRange(item['date'])).toList();
              
              return TabBarView(
                controller: _tabController,
                children: [
                   _buildBillsList(bills, data),
                   _buildPaymentsList(payments, data),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBillsList(List<Map<String, dynamic>> items, DataProvider data) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No bills found', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }
    
    double totalAmount = 0;
    for (var item in items) {
       totalAmount += data.parseAmount(item['bill_amount']);
    }

    return Column(
      children: [
          // Total Billed Summary (Keep only this, balance is at bottom now)
          Container(
             width: double.infinity,
             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
             color: Colors.orange.shade50,
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text('TOTAL BILLED:', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                 Text('₹${totalAmount.toInt()}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
               ],
             ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue, // Mechanic Theme
                    child: Icon(Icons.build, color: Colors.white, size: 20),
                  ),
                  title: Text(item['title'] ?? 'Maintenance', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['vehicle_no'] != null && item['vehicle_no'] != item['title']) Text('Vehicle: ${item['vehicle_no']}'),
                      if (item['description'] != null && item['description'] != item['title']) Text(item['description']),
                      if (item['quantity'] != null && item['quantity'].toString().isNotEmpty)
                         Text('Qty: ${item['quantity']} ${item['unit'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      if (item['date'] != null) Text(item['date'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  trailing: Text(
                    '₹${data.parseAmount(item['bill_amount']).toInt()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsList(List<Map<String, dynamic>> items, DataProvider data) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('No payments recorded', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    double totalPaid = 0;
    for (var item in items) {
       totalPaid += data.parseAmount(item['amount']);
    }

    return Column(
      children: [
         Container(
           width: double.infinity,
           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
           color: Colors.green.shade50,
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Text('TOTAL PAID:', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
               Text('₹${totalPaid.toInt()}', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
             ],
           ),
         ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isDiscount = item['type'] == 'Discount' || (item['title'] ?? '').toString().contains('Discount');
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDiscount ? Colors.orange : Colors.green,
                    child: Icon(isDiscount ? Icons.local_offer : Icons.check, color: Colors.white),
                  ),
                  title: Text(item['title'] ?? (isDiscount ? 'Discount Received' : 'Payment Made'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item['date'] ?? ''}\n${item['description'] ?? ''}'),
                  trailing: Text(
                    item['amount'],
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDiscount ? Colors.orange.shade800 : Colors.green),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
     final controller = TextEditingController();
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
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
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
                subtitle: const Text('Discount allowed by Mechanic - reduces balance without paying cash', style: TextStyle(fontSize: 11)),
                onChanged: (val) => setState(() => isDiscount = val),
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
                 
                 try {
                    await data.recordSupplierPayment(
                      widget.supplierId, 
                      amount, 
                      DateFormat('dd MMM yyyy').format(selectedDate),
                      isDiscount: isDiscount,
                      notes: isDiscount ? 'Discount Allowed' : 'Payment Made',
                    );
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDiscount ? 'Discount Recorded' : 'Payment Recorded')));

                 } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                 }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, DataProvider data, {bool save = false}) async {
      try {
          final ledgerData = await data.getMechanicLedgerCategorized(widget.supplierName);
          final filteredBills = ledgerData['all_bills']!.where((item) => _isDateInRange(item['date'])).toList();
          final filteredPayments = ledgerData['paid']!.where((item) => _isDateInRange(item['date'])).toList();

          // Sort bills by date ascending (ledger style)
          filteredBills.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
                return da.compareTo(db);
             } catch(_) { return 0; }
          });
          filteredPayments.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
                return da.compareTo(db);
             } catch(_) { return 0; }
          });

          // Prepare PDF Data - Two Sections
          // 1. BILLS
          final List<List<String>> billRows = [];
          double totalBilledInRange = 0;
          for (var item in filteredBills) {
               String vNo = (item['vehicle_no'] ?? item['number'] ?? '').toString().trim();
               String vehicleDetails = (item['vehicle_display'] != null && item['vehicle_display'].toString().isNotEmpty)
                   ? item['vehicle_display'].toString()
                   : data.getVehicleDisplayName(vNo);
               if (vehicleDetails.isEmpty) vehicleDetails = '-';

               String desc = '';
               if (item['material_name'] != null && item['material_name'].toString().trim().isNotEmpty) {
                 desc = item['material_name'].toString().trim();
               } else if (item['title'] != null && item['title'].toString().trim().isNotEmpty) {
                 desc = item['title'].toString().trim();
                 if (desc.contains(': ')) {
                   desc = desc.split(': ').sublist(1).join(': ');
                 }
               } else if (item['description'] != null && item['description'].toString().trim().isNotEmpty) {
                 desc = item['description'].toString().trim();
                 if (desc.contains(': ')) {
                   desc = desc.split(': ').sublist(1).join(': ');
                 }
               }
               if (desc.isEmpty || desc.toLowerCase() == 'repair' || desc.toLowerCase() == 'maintenance' || desc.toLowerCase() == 'expense') {
                 desc = item['material_name'] ?? item['description'] ?? item['title'] ?? '-';
               }
               
               double amt = data.parseAmount(item['bill_amount']);
               totalBilledInRange += amt;

               billRows.add([
                   item['date'] ?? '',
                   vehicleDetails,
                   desc,
                   'Rs. ${amt.toInt()}'
               ]);
          }
          
          // 2. PAYMENTS
          final List<List<String>> paymentRows = [];
          double totalPaidInRange = 0;
          for (var item in filteredPayments) {
               double amt = data.parseAmount(item['amount']);
               totalPaidInRange += amt;
               paymentRows.add([
                   item['date'] ?? '',
                   item['type'] ?? 'Payment',
                   item['description'] ?? (item['title'] ?? 'Ledger Settlement'),
                   'Rs. ${amt.toInt()}'
               ]);
          }
          
          final List<List<String>> finalRows = [];
          if (billRows.isNotEmpty) {
            finalRows.add(['--- BILLS ---', '', '', '']);
            finalRows.addAll(billRows);
            finalRows.add(['', '', '', '']);
          }
          
          if (paymentRows.isNotEmpty) {
            finalRows.add(['--- PAYMENTS ---', '', '', '']);
            finalRows.addAll(paymentRows);
          }

          final Map<String, String> totals = {
             'Total Billed': 'Rs. ${totalBilledInRange.toInt()}',
             'Total Paid': 'Rs. ${totalPaidInRange.toInt()}',
             'Balance': 'Rs. ${(totalBilledInRange - totalPaidInRange).toInt()}',
          };
          
          final businessName = await data.getSetting('business_name');
          final logoPath = await data.getLogoPath();

          if (save) {
             await PdfService.saveLedgerPdf(
              title: '${widget.supplierName} Ledger',
              subTitle: 'Bills & Payments Statement',
              headers: ['Date', 'Vehicle Details', 'Description', 'Amount'],
              data: finalRows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
             );
          } else {
             await PdfService.generateLedgerPdf(
              title: '${widget.supplierName} Ledger',
              subTitle: 'Bills & Payments Statement',
              headers: ['Date', 'Vehicle Details', 'Description', 'Amount'],
              data: finalRows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
             );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'Report Generated')));

      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _generateExcel(BuildContext context, DataProvider data) async {
      try {
          final ledgerData = await data.getMechanicLedgerCategorized(widget.supplierName);
          final filteredBills = ledgerData['all_bills']!.where((item) => _isDateInRange(item['date'])).toList();
          final filteredPayments = ledgerData['paid']!.where((item) => _isDateInRange(item['date'])).toList();

          filteredBills.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
                return da.compareTo(db);
             } catch(_) { return 0; }
          });
          filteredPayments.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
                return da.compareTo(db);
             } catch(_) { return 0; }
          });

          final List<List<String>> billRows = [];
          double totalBilledInRange = 0;
          for (var item in filteredBills) {
               String vNo = (item['vehicle_no'] ?? item['number'] ?? '').toString().trim();
               String vehicleDetails = vNo;
               if (vNo.isNotEmpty) {
                 try {
                   final reg = data.vehicleRegistry.firstWhere(
                     (v) => (v['number'] ?? '').toString().replaceAll(' ', '').toLowerCase() == vNo.replaceAll(' ', '').toLowerCase(),
                   );
                   if (reg['type'] != null && reg['type'].toString().trim().isNotEmpty) {
                     vehicleDetails = '$vNo (${reg['type']})';
                   }
                 } catch (_) {}
               } else {
                 vehicleDetails = '-';
               }

               String desc = '';
               if (item['material_name'] != null && item['material_name'].toString().trim().isNotEmpty) {
                 desc = item['material_name'].toString().trim();
               } else if (item['title'] != null && item['title'].toString().trim().isNotEmpty) {
                 desc = item['title'].toString().trim();
                 if (desc.contains(': ')) {
                   desc = desc.split(': ').sublist(1).join(': ');
                 }
               } else if (item['description'] != null && item['description'].toString().trim().isNotEmpty) {
                 desc = item['description'].toString().trim();
                 if (desc.contains(': ')) {
                   desc = desc.split(': ').sublist(1).join(': ');
                 }
               }
               if (desc.isEmpty || desc.toLowerCase() == 'repair' || desc.toLowerCase() == 'maintenance' || desc.toLowerCase() == 'expense') {
                 desc = item['material_name'] ?? item['description'] ?? item['title'] ?? '-';
               }

               double amt = data.parseAmount(item['bill_amount']);
               totalBilledInRange += amt;

               billRows.add([
                   item['date'] ?? '',
                   vehicleDetails,
                   desc,
                   'Rs. ${amt.toInt()}'
               ]);
          }

          final List<List<String>> paymentRows = [];
          double totalPaidInRange = 0;
          for (var item in filteredPayments) {
               double amt = data.parseAmount(item['amount']);
               totalPaidInRange += amt;
               paymentRows.add([
                   item['date'] ?? '',
                   item['type'] ?? 'Payment',
                   item['description'] ?? (item['title'] ?? 'Ledger Settlement'),
                   'Rs. ${amt.toInt()}'
               ]);
          }

          final List<List<String>> finalRows = [];
          if (billRows.isNotEmpty) {
            finalRows.add(['--- BILLS ---', '', '', '']);
            finalRows.addAll(billRows);
            finalRows.add(['', '', '', '']);
          }
          if (paymentRows.isNotEmpty) {
            finalRows.add(['--- PAYMENTS ---', '', '', '']);
            finalRows.addAll(paymentRows);
          }

          final Map<String, String> totals = {
             'Total Billed': 'Rs. ${totalBilledInRange.toInt()}',
             'Total Paid': 'Rs. ${totalPaidInRange.toInt()}',
             'Balance': 'Rs. ${(totalBilledInRange - totalPaidInRange).toInt()}',
          };

          final businessName = await data.getSetting('business_name');

          await ExcelService.generateLedgerExcel(
             title: '${widget.supplierName} Ledger',
             subTitle: 'Bills & Payments Statement',
             headers: ['Date', 'Vehicle Details', 'Description', 'Amount'],
             data: finalRows,
             totals: totals,
             businessName: businessName,
          );

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated')));
      } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }
}
