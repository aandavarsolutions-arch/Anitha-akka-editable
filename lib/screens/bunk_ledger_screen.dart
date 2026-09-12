import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import '../app_config.dart';
import 'add_vehicle_payment_screen.dart';

class BunkLedgerScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const BunkLedgerScreen({super.key, required this.supplierId, required this.supplierName});

  @override
  State<BunkLedgerScreen> createState() => _BunkLedgerScreenState();
}

class _BunkLedgerScreenState extends State<BunkLedgerScreen> with SingleTickerProviderStateMixin {
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
        final supplier = data.suppliers.firstWhere((s) => s['id'] == widget.supplierId, orElse: () => {});
        final balance = supplier['balance'] ?? '₹0';

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
                  onPressed: () => _generatePdf(context, Provider.of<DataProvider>(context, listen: false), save: true),
                  tooltip: 'Save as PDF',
              ),
              IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => _generatePdf(context, Provider.of<DataProvider>(context, listen: false)),
                  tooltip: 'Print',
              ),
              IconButton(
                  icon: const Icon(Icons.grid_on),
                  onPressed: () => _generateExcel(context, Provider.of<DataProvider>(context, listen: false)),
                  tooltip: 'Export as Excel',
              ),
              const DevBrandingBadge(),
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
            future: data.getBunkLedgerCategorized(widget.supplierName),
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
                  title: Text(item['title'] ?? 'Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _showInfoDialog(context, item, data),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['description'] ?? ''),
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
                  onTap: () => _showInfoDialog(context, item, data),
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
                subtitle: const Text('Discount allowed by Bunk - reduces balance without paying cash', style: TextStyle(fontSize: 11)),
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
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDiscount ? 'Discount Recorded' : 'Payment Recorded')));
                 } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          final ledgerData = await data.getBunkLedgerCategorized(widget.supplierName);
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
               String qtyDisplay = '';
               if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
                  qtyDisplay = '${item['material_name']}';
                  if (item['quantity'] != null && item['quantity'].toString().isNotEmpty && item['quantity'].toString() != '0') {
                    qtyDisplay += ' - ${item['quantity']} ${item['unit'] ?? ''}';
                  }
               } else if (item['quantity'] != null && item['quantity'].toString().isNotEmpty) {
                  qtyDisplay = '${item['quantity']} ${item['unit'] ?? ''}';
               } else {
                  qtyDisplay = item['material_name'] ?? '';
               }

               double amt = data.parseAmount(item['bill_amount']);
               totalBilledInRange += amt;

               String vNo = (item['vehicle_no'] ?? item['number'] ?? '').toString().trim();
               String vehicleDisplay = (item['vehicle_display'] != null && item['vehicle_display'].toString().isNotEmpty)
                   ? item['vehicle_display'].toString()
                   : data.getVehicleDisplayName(vNo);
               if (vehicleDisplay.isEmpty) {
                 vehicleDisplay = item['description'] ?? 'Expense';
               }

               billRows.add([
                   item['date'] ?? '',
                   vehicleDisplay,
                   qtyDisplay,
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
                   item['description'] ?? (item['title'] ?? ''),
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
              headers: ['Date', 'Description', 'Qty', 'Amount'],
              data: finalRows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
             );
          } else {
             await PdfService.generateLedgerPdf(
              title: '${widget.supplierName} Ledger',
              subTitle: 'Bills & Payments Statement',
              headers: ['Date', 'Description', 'Qty', 'Amount'],
              data: finalRows,
              totals: totals,
              businessName: businessName,
              logoPath: logoPath,
             );
          }

          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'Report Generated')));

      } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _generateExcel(BuildContext context, DataProvider data) async {
      try {
          final ledgerData = await data.getBunkLedgerCategorized(widget.supplierName);
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
               String qtyDisplay = '';
               if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
                  qtyDisplay = '${item['material_name']}';
                  if (item['quantity'] != null && item['quantity'].toString().isNotEmpty && item['quantity'].toString() != '0') {
                     qtyDisplay += ' - ${item['quantity']} ${item['unit'] ?? ''}';
                  }
               } else if (item['quantity'] != null && item['quantity'].toString().isNotEmpty) {
                  qtyDisplay = '${item['quantity']} ${item['unit'] ?? ''}';
               } else {
                  qtyDisplay = item['material_name'] ?? '';
               }

               double amt = data.parseAmount(item['bill_amount']);
               totalBilledInRange += amt;

               billRows.add([
                   item['date'] ?? '',
                   item['vehicle_no'] != null && item['vehicle_no'].toString().isNotEmpty
                        ? item['vehicle_no']
                        : (item['description'] ?? 'Expense'),
                   qtyDisplay,
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
                   item['description'] ?? (item['title'] ?? ''),
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
             headers: ['Date', 'Description', 'Qty', 'Amount'],
             data: finalRows,
             totals: totals,
             businessName: businessName,
          );

          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated')));

      } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  void _showInfoDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    bool isPayment = item['type'] == 'Payment' || item['type'] == 'Expense Payment';
    bool isVehicle = item['type'] == 'Vehicle' || item['source_type'] == 'Vehicle';
    bool isExpense = item['type'] == 'Expense' || item['source_type'] == 'Expense';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isPayment ? 'Payment Info' : 'Entry Info',
          style: const TextStyle(fontWeight: FontWeight.bold, color: JarvisTheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Date', item['date'] ?? 'N/A'),
            if (isPayment) ...[
               _infoRow('Amount', item['amount'] ?? 'N/A'),
               if (item['description'] != null && item['description'].toString().isNotEmpty)
                 _infoRow('For', item['description']),
            ] else if (isVehicle) ...[
                _infoRow('Vehicle', item['vehicle_no'] ?? item['number'] ?? ''),
                _infoRow('Material', item['material_name'] ?? 'N/A'),
                _infoRow('Bill Amount', '₹${data.parseAmount(item['bill_amount'] ?? item['total']).toInt()}'),
                if (item['quantity'] != null && item['quantity'].toString().isNotEmpty)
                   _infoRow('Quantity', '${item['quantity']} ${item['unit'] ?? ''}'),
                if (item['description'] != null && item['description'].toString().isNotEmpty)
                   _infoRow('Desc', item['description']),
            ] else if (isExpense) ...[
                _infoRow('Description', item['description'] ?? item['title'] ?? ''),
                _infoRow('Amount', '₹${data.parseAmount(item['bill_amount'] ?? item['amount']).toInt()}'),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
          if (!AppConfig.isReadOnly && (isPayment || isVehicle || isExpense))
             ElevatedButton.icon(
               onPressed: () {
                 Navigator.pop(dialogContext);
                 if (isPayment) {
                    _showEditPaymentDialog(context, item, data);
                 } else if (isVehicle) {
                    bool isOwnVehicle = item['isOwn'] == true || item['isOwn'] == 1 || item['is_own'] == true || item['is_own'] == 1;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: isOwnVehicle, vehicle: item)));
                 } else if (isExpense) {
                    _showEditBillDialog(context, item, data);
                 }
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
            width: 90,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    if (AppConfig.isReadOnly) return;
    final id = item['id'];
    final subType = item['sub_type'];

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit this payment directly.')));
      return;
    }
    final amountController = TextEditingController(text: data.parseAmount(item['amount']).toInt().toString());

    Future<bool> confirmDelete() async {
      return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Delete this payment entry?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
          ],
        ),
      ) ?? false;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item['description'] != null && item['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(item['description'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final ok = await confirmDelete();
              if (!ok) return;
              if (subType == 'initial_paid') {
                await data.updateExpense(id, {'paid': '₹0'});
              } else if (subType == 'sub_payment') {
                await data.deleteExpenseSubPayment(id);
              } else {
                await data.deleteSupplierPayment(id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Deleted')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null) return;
              Navigator.pop(dialogContext);
              if (subType == 'initial_paid') {
                await data.updateExpense(id, {'paid': '₹${amt.toInt()}'});
              } else if (subType == 'sub_payment') {
                await data.updateExpenseSubPayment(id, {'amount': '₹${amt.toInt()}'});
              } else {
                await data.updateSupplierPayment(id, {'amount': '₹${amt.toInt()}'});
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Updated')));
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }



  void _showEditBillDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    if (AppConfig.isReadOnly) return;
    final id = item['id'];
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit this bill directly.')));
      return;
    }

    final amountController = TextEditingController(text: data.parseAmount(item['bill_amount'] ?? item['amount']).toInt().toString());
    final descController = TextEditingController(text: item['description'] ?? item['title'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Expense Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              bool confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Delete'),
                  content: const Text('Are you sure you want to delete this expense?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('DELETE', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ) ?? false;
              if (confirm) {
                await data.deleteExpense(id);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Deleted')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null) return;
              await data.updateExpense(id, {
                'amount': '₹${amt.toInt()}',
                'title': descController.text,
              });
              Navigator.pop(context);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Updated')));
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }
}
