import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/status_chip.dart';
import '../data/data_provider.dart';
import '../widgets/dev_branding_badge.dart';
import 'driver_history_screen.dart';
import 'driver_attendance_screen.dart';
import 'driver_attendance_report_screen.dart';
import 'add_driver_payment_screen.dart';
import '../app_config.dart';
import '../services/pdf_service.dart';
import 'package:pdf/widgets.dart' as pw;

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  String _driverType = 'Daily';
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('DRIVERS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.white),
            tooltip: 'Attendance Report',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverAttendanceReportScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add_check, color: Colors.white),
            tooltip: 'Bulk Attendance',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const DriverAttendanceScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.calendar_month, color: _selectedDateRange != null ? JarvisTheme.secondary : Colors.white),
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _selectedDateRange,
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
                setState(() => _selectedDateRange = picked);
              }
            },
          ),
          const DevBrandingBadge()
        ],
      ),
      floatingActionButton: AppConfig.isReadOnly ? null : FloatingActionButton(
        onPressed: () => _showAddDriverDialog(context, initialType: _driverType),
        child: const Icon(Icons.add),
      ),
      body: Consumer<DataProvider>(
        builder: (context, data, child) {
          List<Map<String, dynamic>> filteredDrivers = data.allDrivers;

          // 1. Filter by Type
          filteredDrivers = filteredDrivers.where((d) => d['type'] == _driverType).toList();

          // 2. Filter by Date Range
          if (_selectedDateRange != null) {
            filteredDrivers = filteredDrivers.where((d) {
              try {
                DateTime date = DateFormat('dd MMM yyyy').parse(d['date']);
                return date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
                    date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
              } catch (e) {
                return false;
              }
            }).toList();
          }

          // 3. Filter by Search Query
          if (_searchQuery.trim().isNotEmpty) {
            final q = _searchQuery.toLowerCase().trim();
            filteredDrivers = filteredDrivers.where((d) {
              final name = (d['name'] ?? '').toString().toLowerCase();
              final contact = (d['contact'] ?? '').toString().toLowerCase();
              return name.contains(q) || contact.contains(q);
            }).toList();
          }

          return Column(
            children: [
              if (_selectedDateRange != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: JarvisTheme.secondary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, size: 16, color: JarvisTheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        'Range: ${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: JarvisTheme.secondary),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDateRange = null),
                        child: const Icon(Icons.close, size: 16, color: JarvisTheme.secondary),
                      ),
                    ],
                  ),
                ),

              // Search Bar & Quick Add Payment Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Column(
                  children: [
                    // Search Bar
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search driver by name or phone...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, size: 20, color: JarvisTheme.secondary),
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                        filled: true,
                        fillColor: JarvisTheme.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: JarvisTheme.secondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Type Filters & Add Payment Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: ['Daily', 'Monthly'].map((type) {
                            final isSelected = _driverType == type;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: ChoiceChip(
                                label: Text(type == 'Daily' ? 'Daily Wages' : type),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) setState(() => _driverType = type);
                                },
                                selectedColor: JarvisTheme.secondary.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSelected ? JarvisTheme.secondary : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (!AppConfig.isReadOnly)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddDriverPaymentScreen()),
                              );
                            },
                            icon: const Icon(Icons.payment, size: 16),
                            label: const Text('Add Payment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildDriverList(filteredDrivers, data),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDriverList(List<Map<String, dynamic>> drivers, DataProvider data) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No drivers matching "$_searchQuery"' 
                  : 'No $_driverType Drivers',
              style: TextStyle(fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final driver = drivers[index];
        final empType = driver['emp_type'] ?? 'Permanent';
        final salaryType = driver['type'] ?? 'Monthly';
        final salaryRate = driver['salary'] ?? '₹0';

        return Card(
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
                        Text(
                          driver['name'] ?? 'Unknown',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if ((driver['contact'] ?? '').toString().isNotEmpty)
                          Text(
                            driver['contact'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: (empType == 'Temporary' ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: (empType == 'Temporary' ? Colors.orange : Colors.blue).withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                empType,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: empType == 'Temporary' ? Colors.orange[800] : Colors.blue[800]),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: JarvisTheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: JarvisTheme.secondary.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                '$salaryType: $salaryRate',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: JarvisTheme.secondary),
                              ),
                            ),
                            if (driver['date']?.toString().isNotEmpty ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'Joined: ${driver['date']}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                                ),
                              ),
                            if (driver['license_expiry']?.toString().isNotEmpty ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'Lic Exp: ${driver['license_expiry']}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                            if (driver['pause_salary'] == 1 || driver['pause_salary'] == true || driver['pause_salary']?.toString() == '1')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                                ),
                                child: const Text(
                                  'Auto-Salary Paused',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                            if (driver['type'] == 'Monthly' && data.getLastCreditedSalaryMonth(driver['id'].toString()) != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.indigo.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'Last Salary: ${data.getLastCreditedSalaryMonth(driver['id'].toString())}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (!AppConfig.isReadOnly)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                             if (value == 'edit') {
                                _showAddDriverDialog(context, driver: driver, initialType: driver['type']);
                             } else if (value == 'delete') {
                                _confirmAndDeleteDriver(context, data, driver);
                             } else if (value == 'payment') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddDriverPaymentScreen(initialDriverId: driver['id'].toString()),
                                  ),
                                );
                             } else if (value == 'history') {
                                _showDriverHistoryDialog(context, driver['id'], driver['name'] ?? 'Unknown');
                             } else if (value == 'credit_salary') {
                                _showCreditSalaryDialog(context, driver);
                             } else if (value == 'pdf_joined') {
                                _generateJoinedToTodayPdf(context, driver);
                             }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'payment',
                              child: Row(children: [Icon(Icons.payment, size: 18, color: Colors.green), SizedBox(width: 8), Text('Add Payment')]),
                            ),
                            if (driver['type'] == 'Monthly')
                              const PopupMenuItem(
                                value: 'credit_salary',
                                child: Row(children: [Icon(Icons.add_card, size: 18, color: Colors.teal), SizedBox(width: 8), Text('Credit Month Salary')]),
                              ),
                            const PopupMenuItem(
                              value: 'history',
                              child: Row(children: [Icon(Icons.menu_book, size: 18, color: Colors.purple), SizedBox(width: 8), Text('Ledger')]),
                            ),
                            const PopupMenuItem(
                              value: 'pdf_joined',
                              child: Row(children: [Icon(Icons.picture_as_pdf, size: 18, color: Colors.deepOrange), SizedBox(width: 8), Text('PDF (Joined to Today)')]),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete')]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: JarvisTheme.background,
                     borderRadius: BorderRadius.circular(8),
                   ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildBalanceItem('Salary Earned', driver['earnings'] ?? '₹0'),
                            _buildBalanceItem('Paid', driver['paid'] ?? '₹0', color: JarvisTheme.statusPaid),
                            _buildBalanceItem(
                              'Salary Pending', 
                              '₹${(data.parseAmount(driver['earnings']) - data.parseAmount(driver['paid'])).toInt()}', 
                              color: JarvisTheme.statusPending
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  'Advance Box: ₹${data.getDriverRemainingAdvance(driver).toInt()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                                ),
                              ],
                            ),
                            if (!AppConfig.isReadOnly && driver['type'] == 'Monthly')
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => _showCreditSalaryDialog(context, driver),
                                icon: const Icon(Icons.add_card, size: 16, color: Colors.teal),
                                label: const Text('Credit Salary', style: TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                 ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreditSalaryDialog(BuildContext context, Map<String, dynamic> driver) {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final driverId = driver['id'].toString();
    final defaultSalary = provider.parseAmount(driver['salary'] ?? driver['earnings']);
    final salaryController = TextEditingController(text: defaultSalary > 0 ? defaultSalary.toInt().toString() : '');

    DateTime selectedMonth = DateTime.now();
    DateTime creditDate = DateTime.now();
    if (driver['date'] != null && driver['date'].toString().trim().isNotEmpty) {
      try {
        creditDate = DateFormat('dd MMM yyyy').parse(driver['date'].toString().trim());
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Credit Salary - ${driver['name'] ?? 'Driver'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select month and credit date for this driver:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    helpText: 'SELECT SALARY MONTH',
                  );
                  if (picked != null) {
                    setState(() {
                      selectedMonth = DateTime(picked.year, picked.month, 1);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month, color: JarvisTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: creditDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    helpText: 'SELECT CREDIT DATE',
                  );
                  if (picked != null) {
                    setState(() {
                      creditDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Credit Date: ${DateFormat('dd MMM yyyy').format(creditDate)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const Icon(Icons.calendar_today, color: JarvisTheme.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: salaryController,
                decoration: const InputDecoration(
                  labelText: 'Salary Amount (₹)',
                  hintText: 'e.g. 15000',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.primary),
              onPressed: () async {
                final amt = provider.parseAmount(salaryController.text);
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid salary amount')),
                  );
                  return;
                }
                await provider.creditDriverMonthlySalary(driverId, selectedMonth, amt, creditDate: creditDate);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Credited ₹${amt.toInt()} salary for ${DateFormat('MMM yyyy').format(selectedMonth)} on ${DateFormat('dd MMM yyyy').format(creditDate)}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Credit Salary', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDriverHistoryDialog(BuildContext context, String driverId, String driverName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverHistoryScreen(driverId: driverId, driverName: driverName),
      ),
    );
  }

  void _confirmAndDeleteDriver(BuildContext context, DataProvider data, Map<String, dynamic> driver) {
    final driverName = driver['name'] ?? 'Driver';
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
        content: Text('Are you sure you want to delete employee "$driverName"? All related attendance and payment records will be removed.'),
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
              data.deleteDriver(driver['id']);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Employee "$driverName" deleted')),
              );
            },
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String amount, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  void _showAddDriverDialog(BuildContext context, {Map<String, dynamic>? driver, String initialType = 'Daily'}) {
    final nameController = TextEditingController(text: driver?['name']);
    final contactController = TextEditingController(text: driver?['contact']);
    final salaryController = TextEditingController(text: driver != null ? driver['salary']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') : '');
    
    DateTime joiningDate = DateTime.now();
    try {
      if (driver?['date']?.toString().isNotEmpty ?? false) {
        joiningDate = DateFormat('dd MMM yyyy').parse(driver!['date']);
      }
    } catch (_) {}


    DateTime? licenseDate;
    try {
      if (driver?['license_expiry']?.toString().isNotEmpty ?? false) {
        licenseDate = DateFormat('dd MMM yyyy').parse(driver!['license_expiry']);
      }
    } catch (_) {}
    
    String empType = driver?['emp_type'] ?? 'Permanent';
    String salaryType = driver?['type'] ?? initialType;
    bool pauseSalary = (driver?['pause_salary'] == 1 || driver?['pause_salary'] == true || driver?['pause_salary']?.toString() == '1') || (driver == null && empType == 'Temporary');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(driver == null ? 'Add New Employee' : 'Edit Employee Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contactController,
                  decoration: const InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: empType,
                  decoration: const InputDecoration(labelText: 'Employee Type', border: OutlineInputBorder()),
                  items: ['Permanent', 'Temporary'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        empType = val;
                        if (empType == 'Temporary') {
                          pauseSalary = true;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: salaryType,
                  decoration: const InputDecoration(labelText: 'Salary Type', border: OutlineInputBorder()),
                  items: ['Monthly', 'Daily'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => salaryType = val!),
                ),
                if (salaryType == 'Monthly') ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      title: const Text('Pause Auto Salary Credit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                      subtitle: const Text('Disable automatic 1st-of-month salary credit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      value: pauseSalary,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() => pauseSalary = val),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  decoration: InputDecoration(
                    labelText: salaryType == 'Monthly' ? 'Monthly Salary (₹)' : 'Daily Wage (₹)',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date of Joining:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                    DateFormat('dd MMM yyyy').format(joiningDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: JarvisTheme.primary),
                  ),
                  trailing: const Icon(Icons.calendar_month, color: JarvisTheme.secondary, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: joiningDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) setState(() => joiningDate = picked);
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('License End Date:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  subtitle: Text(
                    licenseDate != null ? DateFormat('dd MMM yyyy').format(licenseDate!) : 'Not set',
                    style: TextStyle(fontWeight: FontWeight.bold, color: licenseDate != null ? Colors.blue[900] : Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (licenseDate != null)
                        IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => licenseDate = null)),
                      const Icon(Icons.calendar_month, color: JarvisTheme.secondary, size: 20),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: licenseDate ?? DateTime.now().add(const Duration(days: 365)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => licenseDate = picked);
                  },
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
                final name = nameController.text.trim();
                final contact = contactController.text.trim();
                final salaryVal = salaryController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter driver name')),
                  );
                  return;
                }

                final provider = Provider.of<DataProvider>(context, listen: false);

                // Duplicate Check: Phone if provided, Name if phone is empty
                if (contact.isNotEmpty) {
                  final existing = provider.allDrivers.firstWhere(
                    (d) => (d['contact'] ?? '').toString().replaceAll(' ', '') == contact.replaceAll(' ', '') &&
                           (driver == null || d['id'].toString() != driver['id'].toString()),
                    orElse: () => {},
                  );

                  if (existing.isNotEmpty) {
                    final existingName = existing['name'] ?? 'Driver';
                    final existingEmp = existing['emp_type'] ?? '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Driver with phone "$contact" ALREADY EXISTS! ($existingName - $existingEmp)'),
                        backgroundColor: Colors.red[800],
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }
                } else {
                  final existing = provider.allDrivers.firstWhere(
                    (d) => (d['name'] ?? '').toString().toLowerCase().trim() == name.toLowerCase().trim() &&
                           (driver == null || d['id'].toString() != driver['id'].toString()),
                    orElse: () => {},
                  );

                  if (existing.isNotEmpty) {
                    final existingEmp = existing['emp_type'] ?? '';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Driver with name "$name" ALREADY EXISTS! ($existingEmp)'),
                        backgroundColor: Colors.red[800],
                        duration: const Duration(seconds: 4),
                      ),
                    );
                    return;
                  }
                }

                final newData = {
                  if (driver != null) 'id': driver['id'],
                  'name': name,
                  'contact': contact,
                  'emp_type': empType,
                  'type': salaryType,
                  'salary': '₹$salaryVal',
                  'advance_amount': driver != null ? (driver['advance_amount'] ?? driver['advance'] ?? '₹0') : '₹0',
                  'advance_date': DateFormat('dd MMM yyyy').format(joiningDate),
                  'license_expiry': licenseDate != null ? DateFormat('dd MMM yyyy').format(licenseDate!) : '',
                  'earnings': driver != null ? (driver['earnings'] ?? '₹0') : '₹0',
                  'paid': driver != null ? (driver['paid'] ?? '₹0') : '₹0',
                  'balance': driver != null ? (driver['balance'] ?? '₹0') : '₹0',
                  'status': 'Active',
                  'pause_salary': pauseSalary ? 1 : 0,
                  'date': DateFormat('dd MMM yyyy').format(joiningDate),
                };

                if (driver == null) {
                  await provider.addDriver(newData).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding employee: $e'), backgroundColor: Colors.red),
                    );
                    throw e; 
                  });
                } else {
                  await provider.updateDriver(driver['id'], newData).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating employee: $e'), backgroundColor: Colors.red),
                    );
                    throw e;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateJoinedToTodayPdf(BuildContext context, Map<String, dynamic> driver) async {
    final driverId = driver['id']?.toString() ?? '';
    final driverName = driver['name'] ?? 'Driver';
    final dateStr = driver['date']?.toString() ?? '';

    DateTime startDate;
    try {
      startDate = DateFormat('dd MMM yyyy').parse(dateStr);
    } catch (_) {
      startDate = DateTime(2020);
    }
    DateTime endDate = DateTime.now();

    final data = Provider.of<DataProvider>(context, listen: false);

    try {
      final ledger = await data.getDriverLedgerCategorized(driverId);

      bool inRange(String? dStr) {
        if (dStr == null) return true;
        try {
          final d = DateFormat('dd MMM yyyy').parse(dStr);
          return d.isAfter(startDate.subtract(const Duration(days: 1))) &&
                 d.isBefore(endDate.add(const Duration(days: 1)));
        } catch (_) { return false; }
      }

      final paid = ledger['paid']!.where((item) => inRange(item['date'])).toList();
      final allWorkEntries = ledger['work']!.where((item) => inRange(item['date'])).toList();

      Map<String, Map<String, dynamic>> attendanceMap = {};
      for (var w in allWorkEntries) {
        if (w['type'] == 'Attendance' && w['date'] != null) {
          attendanceMap[w['date'].toString()] = w;
        }
      }

      Map<String, List<Map<String, dynamic>>> paymentsMap = {};
      for (var p in paid) {
        final d = p['date']?.toString() ?? '';
        if (d.isNotEmpty) {
          if (!paymentsMap.containsKey(d)) paymentsMap[d] = [];
          paymentsMap[d]!.add(p);
        }
      }

      Map<String, Map<String, dynamic>> salaryMap = {};
      for (var w in allWorkEntries) {
        if ((w['type'] == 'Work' || w['status'] == 'Salary') && w['date'] != null) {
          salaryMap[w['date'].toString()] = w;
        }
      }

      final isDailyDriver = (driver['type'] ?? 'Monthly') == 'Daily';
      final dailyWageRate = data.parseAmount(driver['salary'] ?? driver['earnings']);

      List<Map<String, dynamic>> combinedRows = [];
      DateTime curDate = startDate;

      while (!curDate.isAfter(endDate)) {
        final curDateStr = DateFormat('dd MMM yyyy').format(curDate);

        final attItem = attendanceMap[curDateStr];
        final salItem = salaryMap[curDateStr];
        final payList = paymentsMap[curDateStr] ?? [];

        String attStatus = 'Absent';
        if (attItem != null) {
          attStatus = attItem['status']?.toString() ?? 'Present';
        }

        double earningsAmt = 0;
        if (salItem != null) {
          earningsAmt = data.parseAmount(salItem['amount']);
        } else if (attStatus == 'Present') {
          if (attItem != null) {
            earningsAmt = data.parseAmount(attItem['amount']);
          } else if (isDailyDriver && dailyWageRate > 0) {
            earningsAmt = dailyWageRate;
          }
        }

        if (salItem != null) {
          final displayAtt = 'Salary Credit ($attStatus)';
          if (payList.isNotEmpty) {
            for (int i = 0; i < payList.length; i++) {
              final p = payList[i];
              final pAmt = data.parseAmount(p['amount']);
              final pMode = (p['mode'] != null && p['mode'].toString().trim().isNotEmpty) ? p['mode'].toString().trim() : 'Cash';
              combinedRows.add({
                'date': curDateStr,
                'attendance': (i == 0) ? displayAtt : '-',
                'mode': pMode,
                'earnings': (i == 0) ? earningsAmt : 0.0,
                'paid': pAmt,
                'hasPayment': true,
                'rawAttStatus': attStatus,
              });
            }
          } else {
            combinedRows.add({
              'date': curDateStr,
              'attendance': displayAtt,
              'mode': '-',
              'earnings': earningsAmt,
              'paid': 0.0,
              'hasPayment': false,
              'rawAttStatus': attStatus,
            });
          }
        } else {
          if (payList.isNotEmpty) {
            for (int i = 0; i < payList.length; i++) {
              final p = payList[i];
              final pAmt = data.parseAmount(p['amount']);
              final pMode = (p['mode'] != null && p['mode'].toString().trim().isNotEmpty) ? p['mode'].toString().trim() : 'Cash';

              combinedRows.add({
                'date': curDateStr,
                'attendance': (i == 0) ? attStatus : '-',
                'mode': pMode,
                'earnings': (i == 0) ? earningsAmt : 0.0,
                'paid': pAmt,
                'hasPayment': true,
                'rawAttStatus': attStatus,
              });
            }
          } else {
            combinedRows.add({
              'date': curDateStr,
              'attendance': attStatus,
              'mode': '-',
              'earnings': earningsAmt,
              'paid': 0.0,
              'hasPayment': false,
              'rawAttStatus': attStatus,
            });
          }
        }

        curDate = curDate.add(const Duration(days: 1));
      }

      combinedRows.sort((a, b) {
        try {
          DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
          DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
          return da.compareTo(db);
        } catch (_) { return 0; }
      });

      final List<List<String>> rows = [];
      Set<String> uniquePresentDates = {};
      Set<String> uniqueAbsentDates = {};
      double totalWork = 0;
      double totalPaidHistory = 0;

      for (var item in combinedRows) {
        final attStatus = item['attendance']?.toString() ?? '-';
        final rawAtt = item['rawAttStatus']?.toString() ?? '';
        final modeText = item['mode']?.toString() ?? '-';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();
        final isGiveAdvance = modeText == 'Give Advance' || modeText == 'Advance' || modeText.toLowerCase().contains('give advance') || modeText == 'Advance Box Given';
        final hasPayment = item['hasPayment'] as bool;
        final dStr = item['date']?.toString() ?? '';

        if (attStatus.contains('Present') || rawAtt == 'Present') {
          uniquePresentDates.add(dStr);
        } else if (attStatus.contains('Absent') || rawAtt == 'Absent') {
          if (!uniquePresentDates.contains(dStr)) {
            uniqueAbsentDates.add(dStr);
          }
        }

        totalWork += earningsAmt;
        if (!isGiveAdvance) {
          totalPaidHistory += paidAmt;
        }

        rows.add([
          dStr, 
          attStatus, 
          modeText, 
          'Rs. ${earningsAmt.toInt()}',
          'Rs. ${paidAmt.toInt()}'
        ]);
      }

      // Advance Box Calculations
      final targetId = driver['id']?.toString().trim().toLowerCase();
      final targetName = driver['name']?.toString().trim().toLowerCase();
      final matchedDriver = data.drivers.firstWhere(
        (d) {
          final dId = (d['id'] ?? '').toString().trim().toLowerCase();
          final dName = (d['name'] ?? '').toString().trim().toLowerCase();
          return (targetId != null && targetId.isNotEmpty && dId == targetId) ||
                 (targetName != null && targetName.isNotEmpty && dName == targetName);
        },
        orElse: () => driver,
      );

      final totalAdvanceDeducted = data.getDriverAdvanceDeducted(matchedDriver['id']?.toString() ?? '');
      final initialAdv = data.getDriverInitialAdvance(matchedDriver);
      final remainingAdv = data.getDriverRemainingAdvance(matchedDriver);

      // Month-by-month summary grouping
      Map<String, Map<String, dynamic>> monthlyStats = {};
      for (var item in combinedRows) {
        final dStr = item['date']?.toString() ?? '';
        DateTime? d;
        try {
          d = DateFormat('dd MMM yyyy').parse(dStr);
        } catch (_) {}
        if (d == null) continue;

        final monthKey = DateFormat('MMM yyyy').format(d);
        if (!monthlyStats.containsKey(monthKey)) {
          monthlyStats[monthKey] = {
            'monthDate': DateTime(d.year, d.month, 1),
            'presentDates': <String>{},
            'absentDates': <String>{},
            'earnings': 0.0,
            'paid': 0.0,
            'advance': 0.0,
          };
        }

        final stats = monthlyStats[monthKey]!;
        final attStatus = item['attendance']?.toString() ?? '-';
        final rawAtt = item['rawAttStatus']?.toString() ?? '';
        final pMode = item['mode']?.toString() ?? '';
        final isGiveAdvance = pMode == 'Give Advance' || pMode == 'Advance' || pMode.toLowerCase().contains('give advance') || pMode == 'Advance Box Given';
        final paidAmt = (item['paid'] as num).toDouble();
        final earningsAmt = (item['earnings'] as num).toDouble();

        if (attStatus.contains('Present') || rawAtt == 'Present') {
          (stats['presentDates'] as Set<String>).add(dStr);
        } else if (attStatus.contains('Absent') || rawAtt == 'Absent') {
          if (!(stats['presentDates'] as Set<String>).contains(dStr)) {
            (stats['absentDates'] as Set<String>).add(dStr);
          }
        }

        stats['earnings'] = (stats['earnings'] as double) + earningsAmt;
        if (isGiveAdvance) {
          stats['advance'] = (stats['advance'] as double) + paidAmt;
        } else {
          stats['paid'] = (stats['paid'] as double) + paidAmt;
        }
      }

      List<MapEntry<String, Map<String, dynamic>>> sortedMonths = monthlyStats.entries.toList();
      sortedMonths.sort((a, b) => (a.value['monthDate'] as DateTime).compareTo(b.value['monthDate'] as DateTime));

      List<List<String>> monthlySummaryRows = [];
      for (var entry in sortedMonths) {
        final mName = entry.key;
        final stats = entry.value;
        final pCount = (stats['presentDates'] as Set<String>).length;
        final aCount = (stats['absentDates'] as Set<String>).length;
        final mEarnings = (stats['earnings'] as double);
        final mPaid = (stats['paid'] as double);
        final mAdv = (stats['advance'] as double);
        final mBal = mEarnings - mPaid;

        monthlySummaryRows.add([
          mName,
          '$pCount Days',
          '$aCount Days',
          'Rs. ${mEarnings.toInt()}',
          'Rs. ${mPaid.toInt()}',
          'Rs. ${mAdv.toInt()}',
          'Rs. ${mBal.toInt()}',
        ]);
      }

      final dbName = await data.getSetting('business_name');
      final businessName = (dbName != null && dbName.trim().isNotEmpty) ? dbName.trim() : 'Aandavar Solutions';
      final logoPath = await data.getLogoPath();

      final netBal = totalWork - totalPaidHistory;
      final startStr = DateFormat('dd MMM yyyy').format(startDate);
      final endStr = DateFormat('dd MMM yyyy').format(endDate);

      final totals = {
        'Total Present Days': '${uniquePresentDates.length} Days',
        'Total Absent Days': '${uniqueAbsentDates.length} Days',
        'Total Earnings': 'Rs. ${totalWork.toInt()}',
        'Total Paid': 'Rs. ${totalPaidHistory.toInt()}',
        'Net Balance': 'Rs. ${netBal.toInt()}',
        if (initialAdv > 0 || totalAdvanceDeducted > 0 || remainingAdv > 0) ...{
          'Advance Box Initial Total': 'Rs. ${initialAdv.toInt()}',
          'Advance Box Deducted (Used)': 'Rs. ${totalAdvanceDeducted.toInt()}',
          'Remaining Advance Box': 'Rs. ${remainingAdv.toInt()}',
        },
      };

      final pdfHeaders = ['Date', 'Attendance', 'Payment Mode', 'Salary', 'Amount Paid'];
      final alignments = {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      };

      await PdfService.generateLedgerPdf(
        title: '$driverName - Driver Ledger',
        subTitle: 'Joined Date to Today ($startStr - $endStr)',
        headers: pdfHeaders,
        data: rows,
        totals: totals,
        businessName: businessName,
        logoPath: logoPath,
        cellAlignments: alignments,
        monthlySummaryData: monthlySummaryRows.isNotEmpty ? monthlySummaryRows : null,
        monthlySummaryHeaders: ['Month', 'Present', 'Absent', 'Earnings', 'Paid', 'Advance Given', 'Balance'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver Ledger PDF Generated (Joining Date to Today)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }
}
