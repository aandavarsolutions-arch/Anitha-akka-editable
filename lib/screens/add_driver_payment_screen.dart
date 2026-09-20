import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';

class AddDriverPaymentScreen extends StatefulWidget {
  final String? initialDriverId;

  const AddDriverPaymentScreen({
    super.key,
    this.initialDriverId,
  });

  @override
  State<AddDriverPaymentScreen> createState() => _AddDriverPaymentScreenState();
}

class _AddDriverPaymentScreenState extends State<AddDriverPaymentScreen> {
  final _driverSearchController = TextEditingController();
  final _amountController = TextEditingController();

  Map<String, dynamic>? _selectedDriver;
  String _selectedMode = 'GPAY';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final data = Provider.of<DataProvider>(context, listen: false);
      if (widget.initialDriverId != null) {
        final found = data.allDrivers.firstWhere(
          (d) => d['id'].toString() == widget.initialDriverId.toString(),
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          setState(() {
            _selectedDriver = found;
            _driverSearchController.text = found['name'] ?? '';
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _driverSearchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('ADD DRIVER PAYMENT'),
        actions: const [DevBrandingBadge()],
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          final allDrivers = data.allDrivers;

          // Filter suggestions based on search text
          final query = _driverSearchController.text.trim().toLowerCase();
          final suggestions = query.isEmpty 
              ? allDrivers 
              : allDrivers.where((d) {
                  final name = (d['name'] ?? '').toString().toLowerCase();
                  final contact = (d['contact'] ?? '').toString().toLowerCase();
                  return name.contains(query) || contact.contains(query);
                }).toList();

          // Get Payments History for selected date
          final selectedDateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
          final isToday = selectedDateStr == DateFormat('dd MMM yyyy').format(DateTime.now());
          final selectedDatePayments = data.driverPayments.where((p) {
            return p['type'] == 'Payment' && p['date'] == selectedDateStr;
          }).toList();

          // Sort newest payment first
          selectedDatePayments.sort((a, b) => (b['id'] ?? '').toString().compareTo((a['id'] ?? '').toString()));

          final double totalPaidForDate = selectedDatePayments.where((p) {
            final m = (p['mode'] ?? '').toString().trim().toLowerCase();
            return m != 'deduct from advance' && !m.contains('deduct') && !m.contains('கழித்தல்');
          }).fold(0.0, (sum, p) => sum + data.parseAmount(p['amount']));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PAYMENT ENTRY CARD
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ENTER PAYMENT DETAILS',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: JarvisTheme.secondary),
                        ),
                        const SizedBox(height: 16),

                        // 1. Driver Name Auto-Suggestion Input
                        const Text('Driver Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _driverSearchController,
                          onChanged: (val) {
                            setState(() {
                              _showSuggestions = true;
                              _selectedDriver = null;
                            });
                          },
                          onTap: () {
                            setState(() => _showSuggestions = true);
                          },
                          decoration: InputDecoration(
                            hintText: 'Type driver name to search...',
                            prefixIcon: const Icon(Icons.person_search, color: JarvisTheme.secondary),
                            suffixIcon: _selectedDriver != null
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (_driverSearchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          setState(() {
                                            _driverSearchController.clear();
                                            _selectedDriver = null;
                                            _showSuggestions = true;
                                          });
                                        },
                                      )
                                    : null),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),

                        // Driver Auto-Suggestions Dropdown List
                        if (_showSuggestions && _selectedDriver == null && suggestions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: suggestions.length,
                              itemBuilder: (context, idx) {
                                final d = suggestions[idx];
                                final dName = d['name'] ?? 'Unknown';
                                final dType = d['type'] ?? 'Monthly';
                                final dContact = d['contact'] ?? '';
                                final dBalance = d['balance'] ?? '₹0';

                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.person, color: JarvisTheme.secondary),
                                  title: Text(dName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('$dType wage • $dContact'),
                                  trailing: Text('Pending: $dBalance', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                  onTap: () {
                                    setState(() {
                                      _selectedDriver = d;
                                      _driverSearchController.text = dName;
                                      _showSuggestions = false;
                                    });
                                  },
                                );
                              },
                            ),
                          ),

                        // Selected Driver Info Badge
                        if (_selectedDriver != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.badge, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedDriver!['name'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '${_selectedDriver!['type']} • Salary: ${_selectedDriver!['salary']}',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Pending: ${_selectedDriver!['balance'] ?? "₹0"}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Adv Box: ₹${data.getDriverRemainingAdvance(_selectedDriver!).toInt()}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // 2. Amount Input
                        const Text('Amount Paid (₹):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            hintText: 'Enter amount paid (e.g. 500)',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),

                        const SizedBox(height: 16),

                        // 3. Payment Mode ChoiceChips
                        const Text('Payment Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Cash', 'GPAY', 'Bank', 'Give Advance', 'Deduct from Advance'].map((mode) {
                            final isSelected = _selectedMode == mode;
                            String displayLabel = mode;
                            if (mode == 'Deduct from Advance') {
                              displayLabel = 'Deduct from Advance (அட்வான்ஸில் கழித்தல்)';
                            } else if (mode == 'Give Advance') {
                              displayLabel = 'Give Advance (அட்வான்ஸ் வழங்குதல்)';
                            }
                            Color selectedColor = JarvisTheme.secondary;
                            if (mode == 'Deduct from Advance') {
                              selectedColor = Colors.orange[800]!;
                            } else if (mode == 'Give Advance') {
                              selectedColor = Colors.deepOrange[700]!;
                            }
                            return ChoiceChip(
                              label: Text(
                                displayLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: selectedColor,
                              backgroundColor: Colors.grey[200],
                              showCheckmark: false,
                              onSelected: (selected) {
                                if (selected) setState(() => _selectedMode = mode);
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // 4. Date & Time Row
                        Row(
                          children: [
                            Expanded(
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Date:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                subtitle: Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: const Icon(Icons.calendar_today, size: 18, color: JarvisTheme.secondary),
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) setState(() => _selectedDate = picked);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Time:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                subtitle: Text(_selectedTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                                trailing: const Icon(Icons.access_time, size: 18, color: JarvisTheme.secondary),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (picked != null) setState(() => _selectedTime = picked);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // SAVE PAYMENT BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _savePayment,
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('SAVE PAYMENT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // PAYMENTS HISTORY SECTION FOR SELECTED DATE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isToday ? "TODAY'S PAYMENTS HISTORY" : "${selectedDateStr.toUpperCase()} PAYMENTS HISTORY",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Total: ₹${totalPaidForDate.toInt()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (selectedDatePayments.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.green, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isToday ? 'Total Paid Today' : 'Total Paid On $selectedDateStr',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '₹${totalPaidForDate.toInt()}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '${selectedDatePayments.length} Payments Recorded',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (selectedDatePayments.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        isToday ? 'No payments recorded today yet' : 'No payments recorded on $selectedDateStr',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: selectedDatePayments.length,
                    itemBuilder: (context, index) {
                      final pay = selectedDatePayments[index];
                      final driverId = pay['driver_id']?.toString() ?? '';
                      final driver = allDrivers.firstWhere((d) => d['id'].toString() == driverId, orElse: () => {});
                      final driverName = driver['name'] ?? 'Unknown Driver';
                      final modeStr = pay['mode']?.toString() ?? 'Cash';
                      final isDeduct = modeStr.toLowerCase().contains('deduct') || modeStr.contains('கழித்தல்');
                      final amtStr = pay['amount']?.toString() ?? '₹0';
                      final timeStr = pay['time']?.toString() ?? DateFormat('hh:mm a').format(DateTime.now());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDeduct 
                                ? Colors.orange.withValues(alpha: 0.12)
                                : Colors.green.withValues(alpha: 0.1),
                            child: Icon(
                              isDeduct ? Icons.remove_circle_outline : Icons.payment, 
                              color: isDeduct ? Colors.orange[800] : Colors.green, 
                              size: 20
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDeduct 
                                      ? Colors.orange.withValues(alpha: 0.12)
                                      : Colors.purple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDeduct 
                                        ? Colors.orange.withValues(alpha: 0.4)
                                        : Colors.purple.withValues(alpha: 0.4)
                                  ),
                                ),
                                child: Text(
                                  modeStr,
                                  style: TextStyle(
                                    fontSize: 10, 
                                    fontWeight: FontWeight.bold, 
                                    color: isDeduct ? Colors.orange[800] : Colors.purple
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text('Time: $timeStr • Date: ${pay['date']}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    amtStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 16, 
                                      color: isDeduct ? Colors.orange[800] : Colors.green
                                    ),
                                  ),
                                  if (isDeduct)
                                    Text(
                                      'Adv Deducted',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                                    ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                onPressed: () {
                                  _showEditPaymentDialog(context, data, pay);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () {
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
                                      content: Text('Are you sure you want to delete payment of $amtStr recorded for $driverName?'),
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
                                            data.deleteDriverPayment(pay['id']);
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Payment deleted')),
                                            );
                                          },
                                          child: const Text('DELETE'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _savePayment() {
    if (_selectedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please search and select a driver first')),
      );
      return;
    }

    final amt = double.tryParse(_amountController.text) ?? 0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount')),
      );
      return;
    }

    final provider = Provider.of<DataProvider>(context, listen: false);
    final driverId = _selectedDriver!['id'].toString();
    final driverName = _selectedDriver!['name'] ?? '';

    final dt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final formattedTime = DateFormat('hh:mm a').format(dt);

    provider.addDriverPayment(
      driverId, 
      amt, 
      _selectedDate, 
      mode: _selectedMode,
      time: formattedTime,
    );

    _amountController.clear();
    setState(() {
      _selectedDriver = null;
      _driverSearchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment of ₹${amt.toInt()} recorded for $driverName at $formattedTime'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showEditPaymentDialog(BuildContext context, DataProvider data, Map<String, dynamic> pay) {
    final amtVal = data.parseAmount(pay['amount']);
    final editAmountController = TextEditingController(text: amtVal > 0 ? amtVal.toInt().toString() : '');
    String selectedMode = (pay['mode'] ?? 'GPAY').toString().trim();
    if (selectedMode.isEmpty) selectedMode = 'Cash';

    final driverId = pay['driver_id']?.toString();
    final driver = data.allDrivers.firstWhere(
      (d) => d['id'].toString() == driverId,
      orElse: () => {},
    );
    final driverName = driver['name'] ?? 'Driver';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Payment - $driverName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Amount Paid (₹):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: editAmountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Enter new amount',
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('Payment Mode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMode,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'GPAY', child: Text('GPAY')),
                        DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                        DropdownMenuItem(value: 'Give Advance', child: Text('Give Advance (அட்வான்ஸ் வழங்குதல்)')),
                        DropdownMenuItem(value: 'Deduct from Advance', child: Text('Deduct from Advance (அட்வான்ஸில் கழித்தல்)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedMode = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: JarvisTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final newAmt = double.tryParse(editAmountController.text) ?? 0;
                    if (newAmt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount')),
                      );
                      return;
                    }
                    await data.updateDriverPayment(
                      pay['id'],
                      driverId: driverId ?? '',
                      amount: newAmt,
                      date: _selectedDate,
                      mode: selectedMode,
                      time: pay['time'],
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment updated successfully'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('UPDATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
