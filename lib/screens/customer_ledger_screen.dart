
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/dev_branding_badge.dart';
import '../app_config.dart';
import 'package:share_plus/share_plus.dart';
import 'add_vehicle_payment_screen.dart';

class CustomerLedgerScreen extends StatefulWidget {
  final String customerName;

  const CustomerLedgerScreen({super.key, required this.customerName});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Selection for bulk payment
  final Set<String> _selectedUnpaidIds = {};
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
        // Live Balance
        final customer = data.customers.firstWhere((c) => c['name'] == widget.customerName, orElse: () => {});
        final balance = customer['balance'] ?? '₹0';

        return Scaffold(
          backgroundColor: JarvisTheme.background,
          appBar: AppBar(
            title: Text('${widget.customerName.toUpperCase()} - LEDGER'),
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
                    icon: const Icon(Icons.share, color: Colors.green),
                    onPressed: () => _generatePdf(context, data, share: true),
                    tooltip: 'Share via WhatsApp',
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
                      Text(
                        data.parseAmount(balance) > 0 ? 'BALANCE DUE' : 'EXCESS / CREDIT', 
                        style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)
                      ),
                      Text(
                        balance.replaceAll('-', ''), 
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: data.parseAmount(balance) > 0 ? Colors.red : Colors.green
                        )
                      ),
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
            future: data.getCustomerLedger(widget.customerName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                 return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final ledger = snapshot.data ?? {'bills': [], 'payments': []};
              final bills = ledger['bills']!.where((item) => _isDateInRange(item['date'])).toList();
              final payments = ledger['payments']!.where((item) => _isDateInRange(item['date'])).toList();

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
    
    double totalBilled = 0;
    for (var item in items) {
       totalBilled += data.parseAmount(item['bill_amount']); // Use bill_amount (total) not balance
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
               Text('₹${totalBilled.toInt()}', style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
             ],
           ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              
              String desc = item['description'] ?? '';
              if (item['material_name'] != null && item['material_name'].toString().isNotEmpty) {
                  desc += '\n+ ${item['material_name']}';
              }
              final battaVal = data.parseAmount(item['batta'] ?? item['batta_amount']);
              if (battaVal > 0) {
                  desc += '\n+ Batta: ₹${battaVal.toInt()}';
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(item['title'] ?? 'Debit', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _showInfoDialog(context, item, data),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(desc),
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
              final isDiscount = item['type'] == 'Discount' || (item['title'] ?? '').toString().contains('Discount') || (item['description'] ?? '').toString().toLowerCase().contains('discount');
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDiscount ? Colors.orange : Colors.green,
                    child: Icon(isDiscount ? Icons.local_offer : Icons.check, color: Colors.white),
                  ),
                  title: Text(item['title'] ?? (isDiscount ? 'Discount Given' : 'Payment Received'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _showInfoDialog(context, item, data),
                  subtitle: Text('${item['description'] ?? ''}\n${item['date'] ?? ''}'),
                  trailing: Text(
                    item['amount'].toString().startsWith('₹') ? item['amount'] : '₹${item['amount']}',
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
    final notesController = TextEditingController();
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
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
                title: const Text('Is this a Discount?', style: TextStyle(fontSize: 13)),
                value: isDiscount,
                activeColor: Colors.orange,
                subtitle: const Text('Reduces balance without receiving cash', style: TextStyle(fontSize: 11)),
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
                
                await data.addCustomerPayment({
                  'customer_name': widget.customerName,
                  'amount': '₹${amount.toInt()}',
                  'date': DateFormat('dd MMM yyyy').format(selectedDate),
                  'notes': notesController.text.isNotEmpty 
                      ? notesController.text 
                      : (isDiscount ? 'Discount Given' : 'Received Payment'),
                  'type': isDiscount ? 'Discount' : 'Payment',
                });
                
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isDiscount ? 'Discount Recorded' : 'Payment Added')));
              },
              child: const Text('SAVE PAYMENT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    bool isVehicle = item['source'] == 'Vehicle';
    bool isSite = item['source'] == 'Site';
    bool isPayment = item['type'] == 'Payment' || item['type'] == 'CustomerPayment' || item['type'] == 'Income';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item['title'] ?? (isPayment ? 'Payment Info' : 'Entry Info'), style: const TextStyle(fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Date', item['date'] ?? 'N/A'),
            if (isPayment) ...[
               _infoRow('Amount', '₹${data.parseAmount(item['amount']).toInt()}'),
               _infoRow('Type', item['type'] ?? ''),
               if (item['description'] != null) _infoRow('Desc', item['description']),
            ] else if (isVehicle) ...[
                 _infoRow('Vehicle', item['number'] ?? item['vehicle_no'] ?? ''),
                 if (item['bill_no'] != null && item['bill_no'].toString().trim().isNotEmpty)
                    _infoRow('Bill No', item['bill_no']),
                 _infoRow('Bill Amount', '₹${data.parseAmount(item['bill_amount'] ?? item['total']).toInt()}'),
                if (item['duration'] != null && item['duration'].toString().isNotEmpty && item['duration'].toString() != '0')
                   _infoRow('Rental', '${item['duration']} ${item['rate_type'] ?? 'Day'} @ ₹${item['rate'] ?? '0'}'),
                if (data.parseAmount(item['batta'] ?? item['batta_amount']) > 0)
                   _infoRow('Batta', '₹${data.parseAmount(item['batta'] ?? item['batta_amount']).toInt()}'),
                if (item['material_name'] != null && item['material_name'].isNotEmpty)
                   _infoRow('Material', '${item['material_name']} (Qty: ${item['quantity'] ?? '0'})'),
                if (item['manual_desc'] != null && item['manual_desc'].toString().isNotEmpty)
                   _infoRow('Desc', item['manual_desc']),
            ] else if (isSite) ...[
                _infoRow('Site', item['site'] ?? ''),
                _infoRow('Estimate', '₹${data.parseAmount(item['bill_amount']).toInt()}'),
                _infoRow('Work', item['description'] ?? ''),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CLOSE')),
          if (!AppConfig.isReadOnly)
             ElevatedButton.icon(
               onPressed: () {
                 Navigator.pop(dialogContext);
                 if (isPayment) {
                    _showEditPaymentDialog(context, item, data);
                 } else if (isVehicle) {
                    bool isOwnVehicle = item['isOwn'] == true || item['isOwn'] == 1;
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddVehiclePaymentScreen(isOwn: isOwnVehicle, vehicle: item)));
                 } else {
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

  void _showEditBillDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    if (AppConfig.isReadOnly) return;
    final source = item['source'] ?? '';
    final id = item['id'];
    
    if (source != 'Vehicle' && source != 'Site') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only Vehicle & Site entries can be edited here.')));
      return;
    }

    final amountController = TextEditingController(text: data.parseAmount(item['bill_amount']).toInt().toString());
    final descController = TextEditingController(text: item['manual_desc'] ?? item['description'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${item['type']} Entry'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null) return;
              
              if (source == 'Vehicle') {
                await data.updateVehicle(id, {
                  'total': '₹${amt.toInt()}',
                  'rent_amount': '₹${amt.toInt()}',
                  'manual_desc': descController.text,
                });
              } else if (source == 'Site') {
                final siteId = id.toString().replaceAll('EST-', '');
                await data.updateIncome(siteId, {
                  'estimate': '₹${amt.toInt()}',
                  'work_type': descController.text,
                });
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry Updated')));
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, Map<String, dynamic> item, DataProvider data) {
    if (AppConfig.isReadOnly) return;
    final type = item['type'];
    final id = item['id'];
    final amountController = TextEditingController(text: data.parseAmount(item['amount']).toInt().toString());
    final notesController = TextEditingController(text: item['description'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            if (type == 'CustomerPayment') ...[
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ]
          ],
        ),
        actions: [
          if (type == 'CustomerPayment') 
            TextButton(
              onPressed: () async {
                await data.deleteCustomerPayment(id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Deleted')));
              }, 
              child: const Text('DELETE', style: TextStyle(color: Colors.red))
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amountController.text);
              if (amt == null) return;
              
              if (type == 'CustomerPayment') {
                await data.updateCustomerPayment(id, {
                  'amount': '₹${amt.toInt()}',
                  'notes': notesController.text,
                });
              } else if (type == 'Income') {
                await data.updateIncomePayment(id, {'amount': '₹${amt.toInt()}'});
              } else if (type == 'Payment') {
                await data.updateVehiclePayment(id, {'amount': '₹${amt.toInt()}'});
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Updated')));
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, DataProvider data, {bool save = false, bool share = false, bool isExcel = false}) async {
       try {
          final ledger = await data.getCustomerLedger(widget.customerName);
          final List<Map<String, dynamic>> bills = ledger['bills']!.where((item) => _isDateInRange(item['date'])).toList();
          final List<Map<String, dynamic>> payments = ledger['payments']!.where((item) {
             if (!_isDateInRange(item['date'])) return false;
             final title = (item['title'] ?? '').toString().toLowerCase();
             final type = (item['type'] ?? '').toString().toLowerCase();
             if (title.contains('expense') || type.contains('expense')) return false;
             return true;
          }).toList();

          // REQ: Oldest date first for PDF
          bills.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date'] ?? '');
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date'] ?? '');
                return da.compareTo(db);
             } catch (_) { return 0; }
          });
          payments.sort((a, b) {
             try {
                DateTime da = DateFormat('dd MMM yyyy').parse(a['date'] ?? '');
                DateTime db = DateFormat('dd MMM yyyy').parse(b['date'] ?? '');
                return da.compareTo(db);
             } catch (_) { return 0; }
          });

          // Fetch Customer Address
          final customerObj = data.customers.firstWhere((c) => c['name'] == widget.customerName, orElse: () => {});
          String customerAddress = (customerObj['address'] ?? '').toString().trim();
          if (customerAddress.isEmpty) {
            customerAddress = 'Sangampalayam'; // Default sample address if not set
          }

          // Build 9-Column Customer Statement Rows:
          // S.No | Date | Vehicle Details | Rate type | Hours/Day | Rate | Bata | Material | Amount
          final List<List<String>> statementRows = [];
          double totalBilledInRange = 0;
          double totalHoursInRange = 0;
          double totalCalcValueInRange = 0;
          double totalBataInRange = 0;
          double totalMaterialInRange = 0;

          String lastDate = '';
          int sNo = 1;

          for (var item in bills) {
               double amt = data.parseAmount(item['bill_amount'] ?? item['total']);
               totalBilledInRange += amt;

               String rawDate = (item['date'] ?? '').toString().trim();
               String displayDate = rawDate;
               try {
                  DateTime dt = DateFormat('dd MMM yyyy').parse(rawDate);
                  displayDate = DateFormat('dd.MM.yy').format(dt);
               } catch (_) {
                  try {
                     DateTime dt = DateFormat('yyyy-MM-dd').parse(rawDate);
                     displayDate = DateFormat('dd.MM.yy').format(dt);
                  } catch (_) {}
               }

               String dateCell = displayDate;

               String vType = (item['type'] ?? '').toString().trim();
               if (vType.isEmpty) {
                  String title = (item['title'] ?? '').toString();
                  if (title.contains(' - ')) {
                     vType = title.split(' - ').first.trim();
                  } else {
                     vType = 'Vehicle';
                  }
               }
               String rawNo = (item['number'] ?? item['vehicle_no'] ?? item['details'] ?? '').toString().trim();
               String cleanNo = rawNo
                   .replaceAll(vType, '')
                   .replaceAll('-', '')
                   .replaceAll('(', '')
                   .replaceAll(')', '')
                   .trim();
               String vehicleDetailsStr = cleanNo.isNotEmpty && cleanNo != '-' ? '$vType($cleanNo)' : vType;

               String rateTypeStr = (item['rate_type'] ?? item['unit'] ?? '').toString().trim();
               if (rateTypeStr.isEmpty) rateTypeStr = '-';

               double duration = double.tryParse(item['duration']?.toString() ?? '0') ?? 0;
               if (duration <= 0) {
                  duration = double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
               }
               totalHoursInRange += duration;
               String hoursDayStr = duration > 0 ? (duration % 1 == 0 ? duration.toInt().toString() : duration.toString()) : '-';

               double rate = data.parseAmount(item['rate']);
               String rateStr = rate > 0 ? rate.toInt().toString() : '-';

               double bVal = data.parseAmount(item['batta'] ?? item['batta_amount']);
               totalBataInRange += bVal;
               String bataStr = bVal > 0 ? bVal.toInt().toString() : '-';

               String matName = (item['material_name'] ?? item['material'] ?? item['particulars'] ?? '').toString().trim();
               if (matName == vType || matName == rawNo || matName == vehicleDetailsStr || matName == '0') {
                  matName = '';
               }
               String materialStr = matName.isNotEmpty ? matName : '-';

               double calcVal = 0;
               if (duration > 0 && rate > 0) {
                  calcVal = duration * rate;
               } else {
                  double mVal = data.parseAmount(item['material_amount']);
                  calcVal = amt - bVal - mVal;
                  if (calcVal < 0) calcVal = 0;
               }
               totalCalcValueInRange += calcVal;

               if (amt <= 0) {
                  double mVal = data.parseAmount(item['material_amount']);
                  amt = calcVal + bVal + mVal;
               }
               String amountStr = amt.toInt().toString();

               statementRows.add([
                   (sNo++).toString(),
                   dateCell,
                   vehicleDetailsStr,
                   rateTypeStr,
                   hoursDayStr,
                   rateStr,
                   bataStr,
                   materialStr,
                   amountStr,
               ]);
          }

          final List<List<String>> paymentStatementRows = [];
          double totalPaidInRange = 0;
          int paySNo = 1;
          for (var item in payments) {
               double amt = data.parseAmount(item['amount']);
               if (amt <= 0) continue;
               totalPaidInRange += amt;

               String rawDate = (item['date'] ?? '').toString().trim();
               String displayDate = rawDate;
               try {
                  DateTime dt = DateFormat('dd MMM yyyy').parse(rawDate);
                  displayDate = DateFormat('dd.MM.yy').format(dt);
               } catch (_) {
                  try {
                     DateTime dt = DateFormat('yyyy-MM-dd').parse(rawDate);
                     displayDate = DateFormat('dd.MM.yy').format(dt);
                  } catch (_) {}
               }

               String desc = (item['description'] ?? item['notes'] ?? item['subtitle'] ?? item['desc'] ?? item['title'] ?? '').toString().trim();
               if (desc.isEmpty || desc.toLowerCase() == 'generic payment') {
                  desc = (item['title'] ?? 'Payment Received').toString().trim();
               }

               paymentStatementRows.add([
                  (paySNo++).toString(),
                  displayDate,
                  desc,
                  'Rs. ${amt.toInt()}',
               ]);
          }

          final Map<String, String> totals = {
             'Total Amount': 'Rs. ${totalBilledInRange.toInt()}',
             'Paid Amount': 'Rs. ${totalPaidInRange.toInt()}',
             'Balance': 'Rs. ${(totalBilledInRange - totalPaidInRange).toInt()}',
          };

          if (isExcel) {
             await ExcelService.generateCustomerAccountStatementExcel(
                customerName: widget.customerName,
                customerAddress: customerAddress,
                dataRows: statementRows,
                totals: totals,
                paymentRows: paymentStatementRows,
             );
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Statement Generated')));
             return;
          }

          final logoPath = await data.getLogoPath();

          if (share) {
             final file = await PdfService.getCustomerAccountStatementPdfFile(
                customerName: widget.customerName,
                customerAddress: customerAddress,
                dataRows: statementRows,
                totals: totals,
                paymentRows: paymentStatementRows,
                logoPath: logoPath,
             );

             String textSummary = "*CUSTOMER ACCOUNT STATEMENT*\n*Customer: ${widget.customerName} ($customerAddress)*\n\n";
             textSummary += "S.No | Date | Vehicle | Rate type | Hours/Day | Rate | Bata | Material | Amount\n";
             for (var r in statementRows.take(20)) {
                textSummary += r.join(' | ') + '\n';
             }
             totals.forEach((k, v) => textSummary += "$k: $v\n");

             await PdfService.showShareDialog(context, file, title: 'Share Customer Account Statement PDF', textSummary: textSummary);
          } else if (save) {
             await PdfService.saveCustomerAccountStatementPdf(
                customerName: widget.customerName,
                customerAddress: customerAddress,
                dataRows: statementRows,
                totals: totals,
                paymentRows: paymentStatementRows,
                logoPath: logoPath,
             );
          } else {
             await PdfService.generateCustomerAccountStatementPdf(
                customerName: widget.customerName,
                customerAddress: customerAddress,
                dataRows: statementRows,
                totals: totals,
                paymentRows: paymentStatementRows,
                logoPath: logoPath,
             );
          }

          if (!share) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(save ? 'PDF Saved' : 'Statement Generated')));

       } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
       }
  }

  Future<void> _generateExcel(BuildContext context, DataProvider data) async {
       await _generatePdf(context, data, isExcel: true);
  }
}
