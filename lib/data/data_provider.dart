import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/status_chip.dart';
import '../theme.dart';
import 'database_helper.dart';
import 'mock_data.dart';
import '../services/google_drive_service.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';

class DataProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // --- SETTINGS (Moved to top for visibility) ---
  Future<String?> getSetting(String key) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    switch(key) {
      case 'dev_name': return 'Aandavar Solutions';
      case 'dev_contact': return '+91 99440 27958';
      case 'dev_email': return 'aandavarsolutions@gmail.com';
      case 'business_name': return 'Aandavar Solutions';
      default: return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.query('settings', where: 'key = ?', whereArgs: [key]);
    if (maps.isNotEmpty) {
       await _dbHelper.update('settings', {'value': value}, 'key', key);
    } else {
       await _dbHelper.insert('settings', {'key': key, 'value': value});
    }
    notifyListeners();
  }

  Future<String?> getLogoPath() async {
    return await getSetting('business_logo_path');
  }

  Future<Map<String, List<Map<String, dynamic>>>> getCustomerLedger(String customerName) async {
    final ledger = await getCustomerLedgerCategorized(customerName);
    return {
      'bills': ledger['bills']!,
      'payments': ledger['payments']!,
    };
  }

  // --- DATE NAVIGATION ---
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;
  
  DateTime get selectedDate => _selectedDate;
  DateTimeRange? get selectedDateRange => _selectedDateRange;

  void selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _selectedDate = picked;
      _selectedDateRange = null; // Clear range if single date picked
      notifyListeners();
    }
  }

  void selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: _selectedDate.subtract(const Duration(days: 6)),
        end: _selectedDate
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _selectedDateRange = picked;
      notifyListeners();
    }
  }

  void setSelectedDateRange(DateTimeRange range) {
    _selectedDateRange = range;
    notifyListeners();
  }

  void clearDateRange() {
    _selectedDateRange = null;
    notifyListeners();
  }

  void nextDay() {
    if (_selectedDateRange != null) {
      final duration = _selectedDateRange!.end.difference(_selectedDateRange!.start);
      _selectedDateRange = DateTimeRange(
        start: _selectedDateRange!.start.add(duration + const Duration(days: 1)),
        end: _selectedDateRange!.end.add(duration + const Duration(days: 1)),
      );
    } else {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    }
    notifyListeners();
  }

  void previousDay() {
    if (_selectedDateRange != null) {
      final duration = _selectedDateRange!.end.difference(_selectedDateRange!.start);
      _selectedDateRange = DateTimeRange(
        start: _selectedDateRange!.start.subtract(duration + const Duration(days: 1)),
        end: _selectedDateRange!.end.subtract(duration + const Duration(days: 1)),
      );
    } else {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    }
    notifyListeners();
  }
  
  String get formattedSelectedDate {
    if (_selectedDateRange != null) {
      final start = DateFormat('dd MMM').format(_selectedDateRange!.start);
      final end = DateFormat('dd MMM yyyy').format(_selectedDateRange!.end);
      return '$start - $end';
    }
    return DateFormat('dd MMM yyyy').format(_selectedDate);
  }

  bool _matchesSelectedDate(String? dateStr) {
    if (dateStr == null) return false;
    DateTime? date;
    
    if (dateStr == 'Today' || dateStr == 'Just now') {
       date = DateTime.now();
    } else {
      try {
        date = DateFormat('dd MMM yyyy').parse(dateStr);
      } catch (_) {
        try {
          final d = DateFormat('dd MMM').parse(dateStr);
          date = DateTime(DateTime.now().year, d.month, d.day);
        } catch (_) {
          return false;
        }
      }
    }

    if (_selectedDateRange != null) {
      // Normalize dates to midnight for comparison
      final compareDate = DateTime(date.year, date.month, date.day);
      final startDate = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      final endDate = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day);
      
      return (compareDate.isAtSameMomentAs(startDate) || compareDate.isAfter(startDate)) && 
             (compareDate.isAtSameMomentAs(endDate) || compareDate.isBefore(endDate));
    } else {
      return date.year == _selectedDate.year && 
             date.month == _selectedDate.month && 
             date.day == _selectedDate.day;
    }
  }

  // --- STATE ---
// ... (rest of class)
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _labour = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _siteIncome = [];
  List<Map<String, dynamic>> _siteExpenses = [];
  List<Map<String, dynamic>> _vehicleRegistry = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _billPayments = [];
  List<Map<String, dynamic>> _supplierPayments = [];
  List<Map<String, dynamic>> _vehiclePayments = [];
  List<Map<String, dynamic>> _labourPayments = [];
  List<Map<String, dynamic>> _driverPayments = [];
  List<Map<String, dynamic>> _driverAttendance = [];
  List<Map<String, dynamic>> _incomePayments = [];
  List<Map<String, dynamic>> _siteExpensePayments = [];
  List<Map<String, dynamic>> _customerPayments = [];

  List<Map<String, dynamic>> get supplierPayments => _supplierPayments;
  List<Map<String, dynamic>> get billPayments => _billPayments;
  List<Map<String, dynamic>> get vehiclePayments => _vehiclePayments;
  List<Map<String, dynamic>> get labourPayments => _labourPayments;
  List<Map<String, dynamic>> get customerPayments => _customerPayments;

  // --- GETTERS ---
  List<Map<String, dynamic>> get generalSuppliers {
    return _suppliers.where((s) {
       final material = (s['material'] ?? '').toString().toLowerCase();
       final name = (s['name'] ?? '').toString().toLowerCase();
       final isBunk = material.contains('fuel') || material.contains('petrol') || material.contains('diesel') || material.contains('bunk') || name.contains('bunk') || name.contains('fuel') || name.contains('petrol');
       final isMechanic = material.contains('mechanic') || material.contains('workshop') || material.contains('garage') || material.contains('service') || name.contains('mechanic') || name.contains('workshop') || name.contains('garage');
       return !isBunk && !isMechanic;
    }).toList();
  }

  List<Map<String, dynamic>> get bunkSuppliers {
    return _suppliers.where((s) {
       final material = (s['material'] ?? '').toString().toLowerCase();
       final name = (s['name'] ?? '').toString().toLowerCase();
       return material.contains('fuel') || material.contains('petrol') || material.contains('diesel') || material.contains('bunk') || name.contains('bunk') || name.contains('fuel') || name.contains('petrol');
    }).toList();
  }

  List<Map<String, dynamic>> get mechanicSuppliers {
    return _suppliers.where((s) {
       final material = (s['material'] ?? '').toString().toLowerCase();
       final name = (s['name'] ?? '').toString().toLowerCase();
       return material.contains('mechanic') || material.contains('workshop') || material.contains('garage') || material.contains('service') || name.contains('mechanic') || name.contains('workshop') || name.contains('garage');
    }).toList();
  }


  double _mainTankLiters = 0.0;
  double get mainTankLiters => _mainTankLiters;

  List<Map<String, dynamic>> _fuelIssues = [];
  List<Map<String, dynamic>> get fuelIssues => _fuelIssues;

  Future<void> syncFuelIssueExpenses() async {
    try {
      final issues = await _dbHelper.query('fuel_issues');
      final tankExpenses = await _dbHelper.query('site_expenses', 
        where: "supplier = 'Storage Tank' OR title LIKE '%Tank Dispense%'");

      if (issues.isEmpty) {
        for (var exp in tankExpenses) {
          final expId = exp['id'].toString().trim();
          await _dbHelper.rawDelete('site_expenses', 'id = ?', [expId]);
          await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [expId]);
          _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == expId);
        }
      } else {
        Set<int> matchedIssueIds = {};

        for (var exp in tankExpenses) {
          final expId = exp['id'].toString().trim();

          if (expId.startsWith('EXP_TANK_')) {
            final parsedIssueId = int.tryParse(expId.replaceFirst('EXP_TANK_', ''));
            if (parsedIssueId != null) {
              bool issueExists = issues.any((i) => (i['id'] as num?)?.toInt() == parsedIssueId);
              if (issueExists) {
                matchedIssueIds.add(parsedIssueId);
                continue;
              } else {
                await _dbHelper.rawDelete('site_expenses', 'id = ?', [expId]);
                await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [expId]);
                _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == expId);
                continue;
              }
            }
          }

          final expVNo = (exp['vehicle_no'] ?? '').toString().trim().toLowerCase();
          final expLiters = double.tryParse(exp['liters']?.toString() ?? exp['quantity']?.toString() ?? '0') ?? 0.0;
          
          int matchIndex = issues.indexWhere((issue) {
            final iId = (issue['id'] as num?)?.toInt();
            if (iId == null || matchedIssueIds.contains(iId)) return false;

            final iVNo = (issue['vehicle_number'] ?? '').toString().trim().toLowerCase();
            final iLiters = (issue['liters'] as num?)?.toDouble() ?? 0.0;
            return (expVNo.isEmpty || iVNo == expVNo) && (expLiters <= 0 || (iLiters - expLiters).abs() < 0.2);
          });

          if (matchIndex != -1) {
            final foundId = (issues[matchIndex]['id'] as num?)?.toInt();
            if (foundId != null) matchedIssueIds.add(foundId);
          } else {
            await _dbHelper.rawDelete('site_expenses', 'id = ?', [expId]);
            await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [expId]);
            _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == expId);
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing fuel issue expenses: $e');
    }
  }

  Future<void> fetchFuelTankData() async {
    try {
      await syncFuelIssueExpenses();
      final tanks = await _dbHelper.query('fuel_tanks');
      double tankBalance = 0.0;
      if (tanks.isNotEmpty) {
        tankBalance = (tanks.first['current_liters'] as num?)?.toDouble() ?? 0.0;
      }

      final tankExpenses = await _dbHelper.query('site_expenses', where: "vehicle_no LIKE '%Storage Tank%' OR vehicle_no LIKE '%Tank%' OR title LIKE '%Storage Tank%'");
      double totalBulkPurchased = 0.0;
      for (var e in tankExpenses) {
         double q = double.tryParse(e['quantity']?.toString() ?? '0') ?? 0.0;
         if (q <= 0) {
            q = double.tryParse(e['liters']?.toString() ?? '0') ?? 0.0;
         }
         totalBulkPurchased += q;
      }

      final issues = await _dbHelper.query('fuel_issues', orderBy: 'id DESC');
      double totalIssued = 0.0;
      for (var issue in issues) {
        totalIssued += (issue['liters'] as num?)?.toDouble() ?? 0.0;
      }

      double calculatedStock = totalBulkPurchased - totalIssued;
      if (calculatedStock < 0) calculatedStock = 0.0;

      _mainTankLiters = totalBulkPurchased > 0 ? calculatedStock : tankBalance;
      if (tanks.isNotEmpty) {
         await _dbHelper.update('fuel_tanks', {'current_liters': _mainTankLiters}, 'id', tanks.first['id'].toString());
      }

      _fuelIssues = List<Map<String, dynamic>>.from(issues);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching fuel tank data: $e');
    }
  }

  Future<void> addBulkTankFuel(double liters) async {
    try {
      final tanks = await _dbHelper.query('fuel_tanks');
      if (tanks.isNotEmpty) {
        final current = (tanks.first['current_liters'] as num?)?.toDouble() ?? 0.0;
        final newLiters = current + liters;
        await _dbHelper.update('fuel_tanks', {'current_liters': newLiters}, 'id', tanks.first['id'].toString());
        _mainTankLiters = newLiters;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding bulk tank fuel: $e');
    }
  }

  double getAverageFuelPricePerLiter() {
    double totalAmount = 0.0;
    double totalLiters = 0.0;

    for (var e in _siteExpenses) {
      final vNo = (e['vehicle_no'] ?? '').toString();
      final title = (e['title'] ?? '').toString();
      if (vNo.contains('Storage Tank') || vNo.contains('Tank') || title.contains('Storage Tank')) {
        double amt = parseAmount(e['amount']);
        double qty = double.tryParse(e['quantity']?.toString() ?? '0') ?? 0.0;
        if (qty <= 0) qty = double.tryParse(e['liters']?.toString() ?? '0') ?? 0.0;
        if (amt > 0 && qty > 0) {
          totalAmount += amt;
          totalLiters += qty;
        }
      }
    }

    if (totalAmount > 0 && totalLiters > 0) {
      return totalAmount / totalLiters;
    }
    return 90.0; // Default fallback to ₹90/Liter if no bulk purchase recorded
  }

  Future<bool> issueFuelToVehicle({
    required String date,
    required String vehicleNumber,
    required String vehicleType,
    required double liters,
    String? driverName,
    String? odometerHours,
    String? notes,
  }) async {
    try {
      final tanks = await _dbHelper.query('fuel_tanks');
      if (tanks.isEmpty) return false;
      final tankId = tanks.first['id'];
      final current = _mainTankLiters > 0 ? _mainTankLiters : ((tanks.first['current_liters'] as num?)?.toDouble() ?? 0.0);
      if (current < liters) return false;

      final newLiters = current - liters;
      await _dbHelper.update('fuel_tanks', {'current_liters': newLiters}, 'id', tankId.toString());
      _mainTankLiters = newLiters;

      final issueMap = {
        'date': date,
        'tank_id': tankId,
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'liters': liters,
        'driver_name': driverName ?? '',
        'odometer_hours': odometerHours ?? '',
        'notes': notes ?? '',
      };
      int issueId = await _dbHelper.insert('fuel_issues', issueMap);

      // Calculate Per-Liter Cost & Record Internal Vehicle Expense
      double pricePerLiter = getAverageFuelPricePerLiter();
      double calculatedVehicleCost = liters * pricePerLiter;

      String descNote = notes != null && notes.isNotEmpty ? notes : 'Tank Fuel Issue';
      final internalExpense = {
        'id': 'EXP_TANK_$issueId',
        'title': 'Fuel: Tank Dispense ($liters L @ ₹${pricePerLiter.toStringAsFixed(0)}/L)',
        'category': 'Vehicle',
        'site': null,
        'amount': '₹${calculatedVehicleCost.toInt()}',
        'paid': '₹${calculatedVehicleCost.toInt()}',
        'date': date,
        'supplier': 'Storage Tank',
        'vehicle_no': vehicleNumber,
        'quantity': liters.toString(),
        'unit': 'Liters',
        'liters': liters.toString(),
        'material_name': descNote,
      };

      await _dbHelper.insert('site_expenses', internalExpense);
      await _loadFromDB();
      await fetchFuelTankData();
      return true;
    } catch (e) {
      debugPrint('Error issuing fuel to vehicle: $e');
      return false;
    }
  }

  Future<bool> updateFuelIssue({
    required dynamic issueId,
    required String date,
    required String vehicleNumber,
    required String vehicleType,
    required double liters,
    String? driverName,
    String? odometerHours,
    String? notes,
  }) async {
    try {
      final cleanIdStr = issueId.toString().replaceAll('EXP_TANK_', '');
      final intId = int.tryParse(cleanIdStr);

      Map<String, dynamic>? oldIssue;
      if (intId != null) {
        final issues = await _dbHelper.query('fuel_issues', where: 'id = ?', whereArgs: [intId]);
        if (issues.isNotEmpty) {
          oldIssue = issues.first;
        }
      }

      double oldLiters = 0.0;
      if (oldIssue != null) {
        oldLiters = (oldIssue['liters'] as num?)?.toDouble() ?? 0.0;
      } else {
        final expId = 'EXP_TANK_$cleanIdStr';
        final expIndex = _siteExpenses.indexWhere((e) => e['id']?.toString() == expId || e['id']?.toString() == issueId.toString());
        if (expIndex != -1) {
          final exp = _siteExpenses[expIndex];
          oldLiters = double.tryParse(exp['liters']?.toString() ?? exp['quantity']?.toString() ?? '0') ?? 0.0;
        }
      }

      final double availableStock = _mainTankLiters + oldLiters;
      if (availableStock < liters) {
        return false;
      }

      final double newTankLiters = availableStock - liters;
      final tanks = await _dbHelper.query('fuel_tanks');
      if (tanks.isNotEmpty) {
        final tankId = tanks.first['id'];
        await _dbHelper.update('fuel_tanks', {'current_liters': newTankLiters}, 'id', tankId.toString());
      }
      _mainTankLiters = newTankLiters;

      if (intId != null && oldIssue != null) {
        final issueMap = {
          'date': date,
          'vehicle_number': vehicleNumber,
          'vehicle_type': vehicleType,
          'liters': liters,
          'driver_name': driverName ?? '',
          'odometer_hours': odometerHours ?? '',
          'notes': notes ?? '',
        };
        await _dbHelper.update('fuel_issues', issueMap, 'id', intId.toString());
      }

      double pricePerLiter = getAverageFuelPricePerLiter();
      double calculatedVehicleCost = liters * pricePerLiter;
      String descNote = notes != null && notes.isNotEmpty ? notes : 'Tank Fuel Issue';

      final expId = 'EXP_TANK_${intId ?? cleanIdStr}';
      final expenseUpdate = {
        'id': expId,
        'title': 'Fuel: Tank Dispense ($liters L @ ₹${pricePerLiter.toStringAsFixed(0)}/L)',
        'category': 'Vehicle',
        'site': '',
        'amount': '₹${calculatedVehicleCost.toInt()}',
        'paid': '₹${calculatedVehicleCost.toInt()}',
        'date': date,
        'supplier': 'Storage Tank',
        'vehicle_no': vehicleNumber,
        'quantity': liters.toString(),
        'unit': 'Liters',
        'liters': liters.toString(),
        'material_name': descNote,
      };

      final expCheck = await _dbHelper.query('site_expenses', where: 'id = ?', whereArgs: [expId]);
      if (expCheck.isNotEmpty) {
        await _dbHelper.update('site_expenses', expenseUpdate, 'id', expId);
      } else {
        await _dbHelper.insert('site_expenses', expenseUpdate);
      }

      await _loadFromDB();
      await fetchFuelTankData();
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('Error updating fuel issue: $e\n$stack');
      return false;
    }
  }


  Future<void> deleteFuelIssue(dynamic id) async {
    final intId = id is int ? id : int.tryParse(id.toString());
    try {
      if (intId != null) {
        final issues = await _dbHelper.query('fuel_issues', where: 'id = ?', whereArgs: [intId]);
        if (issues.isNotEmpty) {
          final issue = issues.first;
          final litersToRefund = (issue['liters'] as num?)?.toDouble() ?? 0.0;
          final tankId = issue['tank_id'];
          final vehicleNumber = (issue['vehicle_number'] ?? '').toString().trim();
          final date = (issue['date'] ?? '').toString().trim();

          await _dbHelper.delete('fuel_issues', 'id', intId);
        
        final tanks = await _dbHelper.query('fuel_tanks', where: 'id = ?', whereArgs: [tankId]);
        if (tanks.isNotEmpty) {
          final current = (tanks.first['current_liters'] as num?)?.toDouble() ?? 0.0;
          await _dbHelper.update('fuel_tanks', {'current_liters': current + litersToRefund}, 'id', tankId.toString());
        }

        // Direct delete matching expense by EXP_TANK_$id
        final directExpId = 'EXP_TANK_$id';
        await _dbHelper.rawDelete('site_expenses', 'id = ?', [directExpId]);
        await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [directExpId]);
        _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == directExpId);

        // Fallback: search and delete matching legacy expense if direct ID delete didn't find one
        final tankExpenses = await _dbHelper.query('site_expenses', 
          where: "supplier = 'Storage Tank' OR title LIKE '%Tank Dispense%'");
        for (var exp in tankExpenses) {
          final expVNo = (exp['vehicle_no'] ?? '').toString().trim();
          final expLiters = double.tryParse(exp['liters']?.toString() ?? exp['quantity']?.toString() ?? '0') ?? 0.0;
          final expDate = (exp['date'] ?? '').toString().trim();

          bool vNoMatch = vehicleNumber.isEmpty || expVNo.toLowerCase() == vehicleNumber.toLowerCase();
          bool litersMatch = litersToRefund <= 0 || (expLiters - litersToRefund).abs() < 0.2;
          bool dateMatch = date.isEmpty || expDate.isEmpty || expDate == date || expDate.contains(date) || date.contains(expDate);

          if (vNoMatch && litersMatch && dateMatch) {
            final eId = exp['id'].toString().trim();
            await _dbHelper.rawDelete('site_expenses', 'id = ?', [eId]);
            await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [eId]);
            _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == eId);
            break;
          }
        }
      }
    }

    await fetchFuelTankData();
  } catch (e) {
    debugPrint('Error deleting fuel issue: $e');
  }
}

  DataProvider() {
    _initData();
  }



  Future<void> _initData() async {
    _isLoading = true;
    notifyListeners();

    await _loadFromDB();
    await fetchFuelTankData();
    await processMonthlySalaries();
    
    // Auto-Sync balances on launch to fix any discrepancies
    await syncAllSupplierBalances();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _seedMockData() async {
    for (var item in MockData.recentTransactions) {
      // Need to convert status/bools for DB
       final dbItem = {...item};
       if(dbItem['status'] is StatusType) dbItem['status'] = dbItem['status'].toString();
       if(dbItem['isExpense'] is bool) dbItem['isExpense'] = (dbItem['isExpense'] as bool) ? 1 : 0;
       await _dbHelper.insert('transactions', dbItem);
    }
    
    for (var item in MockData.bills) {
       final dbItem = {...item};
       if(dbItem['status'] is StatusType) dbItem['status'] = dbItem['status'].toString();
       await _dbHelper.insert('bills', dbItem);
    }
    
    for (var item in MockData.vehicles) {
       final dbItem = {...item};
       if(dbItem['status'] is StatusType) dbItem['status'] = dbItem['status'].toString();
       if(dbItem['isOwn'] is bool) dbItem['isOwn'] = (dbItem['isOwn'] as bool) ? 1 : 0;
       await _dbHelper.insert('vehicles', dbItem);
    }
    
    for (var item in MockData.labour) {
       await _dbHelper.insert('labour', item);
    }

    for (var item in MockData.suppliers) {
       await _dbHelper.insert('suppliers', item);
    }
    
    for (var item in MockData.drivers) {
       final dbItem = {...item};
       if(dbItem['status'] is StatusType) dbItem['status'] = dbItem['status'].toString();
       await _dbHelper.insert('drivers', dbItem);
    }

    for (var item in MockData.siteIncome) {
       final dbItem = {...item};
       if(dbItem['isProfit'] is bool) dbItem['isProfit'] = (dbItem['isProfit'] as bool) ? 1 : 0;
       await _dbHelper.insert('site_income', dbItem);
    }
    
    for (var item in MockData.expenses) {
       await _dbHelper.insert('site_expenses', item);
    }
  }

  Future<void> _loadFromDB() async {
    _recentTransactions = List.from(await _dbHelper.query('transactions'));
    
    _recentTransactions = _recentTransactions.map((e) {
      return {
        ...e,
        'isExpense': e['isExpense'] == 1,
        'status': _parseStatus(e['status']),
      };
    }).toList();

    _bills = (await _dbHelper.query('bills')).map((e) => {...e, 'status': _parseStatus(e['status'])}).toList();
    _labour = List.from(await _dbHelper.query('labour'));
    _vehicleRegistry = List.from(await _dbHelper.query('vehicle_registry'));
    
    /* 
    // Migration: Move Own Site Vehicle Expenses to Site Expenses
    // DISABLED: This was causing data loss on restart for simple vehicle tracking.
    final rawVehicles = await _dbHelper.query('vehicles');
    for (var v in rawVehicles) {
      if (v['isOwn'] == 1 && (v['isRentedOut'] == 0 || v['isRentedOut'] == false)) {
        final expense = {
          'id': _generateId('EXP'),
          'title': '${v['type'] ?? 'Vehicle'} Usage',
          'category': 'Vehicle',
          'site': v['site'],
          'amount': v['total'],
          'paid': v['paid'],
          'date': v['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          'vehicle_no': v['number'],
          'status': v['status'] ?? 'Pending',
        };
        await _dbHelper.insert('site_expenses', expense);
        await _dbHelper.delete('vehicles', 'id', v['id']);
      }
    }
    */

    _vehicles = (await _dbHelper.query('vehicles')).map((e) {
      return {
        ...e,
        'isOwn': e['isOwn'] == 1,
        'isRentedOut': e['isRentedOut'] == 1, 
        'site': e['site'], // Map site
        'status': _parseStatus(e['status']),
      };
    }).toList();

    _suppliers = List.from(await _dbHelper.query('suppliers'));
    
    _drivers = (await _dbHelper.query('drivers')).map((e) => {...e, 'status': _parseStatus(e['status'])}).toList();

    // --- Patch: Restore Driver Initial Advance if decremented by old payment deductions ---
    for (int i = 0; i < _drivers.length; i++) {
      var d = _drivers[i];
      final name = (d['name'] ?? '').toString();
      final currentAdv = parseAmount(d['advance_amount'] ?? d['advance']);
      if (name.toLowerCase().contains('saravana') && (currentAdv == 24400 || currentAdv == 24700)) {
        final restoredStr = '₹25000';
        await _dbHelper.update('drivers', {'advance_amount': restoredStr}, 'id', d['id']);
        _drivers[i] = {...d, 'advance_amount': restoredStr};
      }
    }

    _siteIncome = (await _dbHelper.query('site_income')).map((e) {
      return {
        ...e,
        'isProfit': e['isProfit'] == 1,
      };
    }).toList();
    
    _siteExpenses = (await _dbHelper.query('site_expenses')).map((e) {
      return {
        ...e,
        'status': _parseStatus(e['status']),
      };
    }).toList();

    // --- Patch: Fix Missing Sites for Vehicle Expenses ---
    for (int i = 0; i < _siteExpenses.length; i++) {
       var e = _siteExpenses[i];
       if (e['category'] == 'Vehicle' && (e['site'] == null || e['site'].toString().isEmpty) && e['vehicle_no'] != null) {
          try {
             final activeVehicle = _vehicles.firstWhere(
                (v) => v['number'] == e['vehicle_no'] && (v['status'] == StatusType.active || v['status'] == 'Active'),
                orElse: () => _vehicles.firstWhere((v) => v['number'] == e['vehicle_no'], orElse: () => {})
             );
             if (activeVehicle.isNotEmpty && activeVehicle['site'] != null) {
                // Update DB
                await _dbHelper.update('site_expenses', {'site': activeVehicle['site']}, 'id', e['id']);
                // Update Memory
                _siteExpenses[i] = {...e, 'site': activeVehicle['site']};
             }
          } catch (_) {}
       }
    }

    try {
      _customers = List.from(await _dbHelper.query('customers'));
      await _cleanupDemoData();
      _billPayments = List.from(await _dbHelper.query('bill_payments'));
      _supplierPayments = List.from(await _dbHelper.query('supplier_payments'));
      _vehiclePayments = List.from(await _dbHelper.query('vehicle_payments'));
      // Filter out orphan vehicle payments where vehicle was deleted
      final validVehicleIds = _vehicles.map((v) => v['id']?.toString()).toSet();
      _vehiclePayments.removeWhere((p) => !validVehicleIds.contains(p['vehicle_id']?.toString()));
      _labourPayments = List.from(await _dbHelper.query('labour_payments'));
      _driverPayments = List.from(await _dbHelper.query('driver_payments'));
      _driverAttendance = List.from(await _dbHelper.query('driver_attendance'));
      _incomePayments = List.from(await _dbHelper.query('income_payments'));
      _siteExpensePayments = List.from(await _dbHelper.query('site_expense_payments'));
      
      // Cleanup duplicate site expense payments (e.g. EXPP and PAREXP for same expense)
      final Set<String> seenExpPaymentKeys = {};
      final List<Map<String, dynamic>> cleanExpPayments = [];
      for (var p in _siteExpensePayments) {
        final expId = p['expense_id']?.toString().trim() ?? '';
        final amt = p['amount']?.toString().trim() ?? '';
        final date = p['date']?.toString().trim() ?? '';
        final key = '$expId|$amt|$date';
        if (seenExpPaymentKeys.contains(key) && p['id'].toString().startsWith('PAREXP')) {
          await _dbHelper.delete('site_expense_payments', 'id', p['id']);
          continue;
        }
        seenExpPaymentKeys.add(key);
        cleanExpPayments.add(p);
      }
      _siteExpensePayments = cleanExpPayments;
      _customerPayments = List.from(await _dbHelper.query('customer_payments'));
      
      // Auto-sync all driver and entity balances on startup
      await syncAllSupplierBalances();
    } catch (e) {
      debugPrint('Error loading sub-tables: $e');
    }
  }

  Future<void> _cleanupDemoData() async {
    final demoName = 'MultiPage Demo Customer';
    try {
      await _dbHelper.delete('customers', 'name', demoName);
      await _dbHelper.delete('customers', 'id', 'CUST-DEMO-001');
      _customers.removeWhere((c) => 
        (c['name'] ?? '').toString().toLowerCase().trim() == demoName.toLowerCase().trim() || c['id'] == 'CUST-DEMO-001'
      );

      await _dbHelper.delete('vehicles', 'customer', demoName);
      _vehicles.removeWhere((v) => 
        (v['customer'] ?? '').toString().toLowerCase().trim() == demoName.toLowerCase().trim() || (v['id'] ?? '').toString().startsWith('VEH-DEMO-')
      );
    } catch (e) {
      debugPrint('Error cleaning up demo data: $e');
    }
  }

  StatusType _parseStatus(String? status) {
    if (status == 'StatusType.paid') return StatusType.paid;
    if (status == 'StatusType.pending') return StatusType.pending;
    if (status == 'StatusType.partial') return StatusType.partial;
    if (status == 'StatusType.active' || status == 'Active') return StatusType.active;
    if (status == 'StatusType.inactive' || status == 'Inactive') return StatusType.inactive;
    return StatusType.pending;
  }

  bool _parseBool(dynamic val, {bool defaultValue = false}) {
    if (val == null) return defaultValue;
    if (val is bool) return val;
    if (val is num) return val == 1;
    if (val is String) {
      final s = val.trim().toLowerCase();
      if (s == '1' || s == 'true') return true;
      if (s == '0' || s == 'false') return false;
    }
    return defaultValue;
  }


  List<Map<String, dynamic>> get recentTransactions {
    List<Map<String, dynamic>> all = [];
    
    // 1. Manual Transactions (Filter these too?)
    // Manual Transactions didn't have 'date' field explicitly managed in UI, 
    // but code has 'date': 'Just now' in addTransaction.
    // Ideally manual transactions should be filtered. 
    // Assuming they have a date... _recentTransactions logic needs check.
    // Current addTransaction sets 'date': 'Just now'.
    // We should probably skip filtering manual transactions if date format is bad, OR fix addTransaction.
    // For now, let's filter manual transactions if they match.
    for (var tx in _recentTransactions) {
         if (_matchesSelectedDate(tx['date'])) {
             all.add(tx);
         }
    }
    

    // 3. Site Expenses (Bills)
    for (var e in _siteExpenses) {
      if (_matchesSelectedDate(e['date'])) {
        all.add({
          'id': e['id'],
          'title': e['title'] ?? e['category'] ?? 'Expense Bill',
          'subtitle': '${e['site'] ?? 'Site'} - Bill',
          'amount': e['amount'],
          'date': e['date'],
          'status': _parseStatus(e['status']?.toString()), 
          'isExpense': true,
        });
      }
    }

    // 4. Site Expense Payments (Actual money paid)
    for (var p in _siteExpensePayments) {
      if (_matchesSelectedDate(p['date'])) {
        final exp = _siteExpenses.firstWhere((e) => e['id'] == p['expense_id'], orElse: () => {});
        all.add({
          'id': p['id'],
          'title': 'Paid: ${exp['title'] ?? exp['category'] ?? 'Expense'}',
          'subtitle': exp['site'] ?? 'Expense Payment',
          'amount': p['amount'],
          'date': p['date'],
          'status': StatusType.paid,
          'isExpense': true,
        });
      }
    }

    // 5. Site Income Receipts (Money received)
    for (var p in _incomePayments) {
      if (_matchesSelectedDate(p['date'])) {
        final site = _siteIncome.firstWhere((s) => s['id'] == p['income_id'], orElse: () => {});
        all.add({
          'id': p['id'],
          'title': 'Receipt: ${site['site'] ?? 'Site'}',
          'subtitle': 'Income Received',
          'amount': p['amount'],
          'date': p['date'],
          'status': StatusType.paid,
          'isExpense': false,
        });
      }
    }
    
     // 6. Vehicles
    for (var v in _vehicles) {
        if (_matchesSelectedDate(v['date'] ?? 'Today') && parseAmount(v['paid']) > 0) {
           final isOwn = _parseBool(v['isOwn']);
           final isRentedOut = _parseBool(v['isRentedOut'], defaultValue: true); 
           final isIncome = isOwn && isRentedOut;
           
           final String vType = (v['type'] ?? 'Vehicle').toString().trim();
           final String customer = (v['customer'] ?? '').toString().trim();
           final String site = (v['site'] ?? '').toString().trim();

           List<String> subParts = [vType];
           if (customer.isNotEmpty) {
             subParts.add('Customer: $customer');
           } else if (site.isNotEmpty && site != 'General') {
             subParts.add('Site: $site');
           } else if (site.isNotEmpty) {
             subParts.add(site);
           }

           all.add({
             'id': v['id'],
             'title': 'Vehicle: ${v['number']}',
             'subtitle': subParts.join(' • '),
             'amount': v['paid'],
             'date': v['date'] ?? 'Today', 
             'status': _parseStatus(v['status']?.toString()),
             'isExpense': !isIncome,
           });
        }
    }

    // 7. Generic Customer Payments
    for (var p in _customerPayments) {
        if (_matchesSelectedDate(p['date'])) {
            final isDisc = p['type']?.toString() == 'Discount' || (p['notes'] ?? '').toString().toLowerCase().contains('discount');
            if (isDisc) continue;
            all.add({
                'id': p['id'],
                'title': 'Payment: ${p['customer_name']}',
                'subtitle': p['notes'] ?? 'Received Payment',
                'amount': p['amount'],
                'date': p['date'],
                'status': StatusType.paid,
                'isExpense': false,
            });
        }
    }

    // 8. Supplier Ledger Payments
    for (var p in _supplierPayments) {
      if (_matchesSelectedDate(p['date'])) {
        final type = p['type']?.toString() ?? 'Payment';
        if (type == 'Discount') continue;

        final sId = (p['supplier_id'] ?? '').toString().trim();
        final s = _suppliers.firstWhere((e) => (e['id'] ?? '').toString().trim() == sId, orElse: () => {});
        final supName = (s['name'] ?? '').toString().trim();

        all.add({
          'id': p['id'],
          'title': supName.isNotEmpty ? 'Supplier Paid: $supName' : 'Supplier Payment',
          'subtitle': 'Supplier Ledger Payment',
          'amount': p['amount'],
          'date': p['date'],
          'status': StatusType.paid,
          'isExpense': true,
        });
      }
    }

    // 9. Driver Payments
    for (var p in _driverPayments) {
      if (_matchesSelectedDate(p['date'])) {
        final dId = (p['driver_id'] ?? '').toString().trim();
        final d = _drivers.firstWhere((e) => (e['id'] ?? '').toString().trim() == dId, orElse: () => {});
        final driverName = (d['name'] ?? '').toString().trim();
        final type = p['type']?.toString() ?? 'Payment';
        final mode = (p['mode'] ?? '').toString().trim();
        final isDeduct = mode == 'Deduct from Advance' || mode.toLowerCase().contains('deduct');

        if (type == 'Payment' && !isDeduct) {
          all.add({
            'id': p['id'],
            'title': driverName.isNotEmpty ? 'Driver Paid: $driverName' : 'Driver Payment',
            'subtitle': 'Mode: $mode',
            'amount': p['amount'],
            'date': p['date'],
            'status': StatusType.paid,
            'isExpense': true,
          });
        }
      }
    }
    
    all.sort((a, b) {
       int getTs(String id) {
          try {
             return int.parse(id.split('-').last);
          } catch (e) { return 0; }
       }
       return getTs(b['id'] ?? '').compareTo(getTs(a['id'] ?? '')); 
    });

    return all;
  }

  List<Map<String, dynamic>> get expiryAlerts {
    List<Map<String, dynamic>> alerts = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Vehicle Registry Expiries
    for (var v in _vehicleRegistry) {
      final vNo = (v['number'] ?? 'Vehicle').toString().trim();
      final vType = (v['type'] ?? '').toString().trim();
      final title = vType.isNotEmpty ? '$vNo ($vType)' : vNo;

      void checkDoc(String? dateStr, String docType) {
        if (dateStr == null || dateStr.toString().trim().isEmpty) return;
        try {
          DateTime expDate = DateFormat('dd MMM yyyy').parse(dateStr.toString().trim());
          int daysLeft = expDate.difference(today).inDays;

          if (daysLeft < 0) {
            alerts.add({
              'id': 'V-${v['id']}-$docType',
              'title': title,
              'doc_type': docType,
              'date': dateStr,
              'days_left': daysLeft,
              'is_expired': true,
              'category': 'Vehicle',
            });
          } else if (daysLeft <= 30) {
            alerts.add({
              'id': 'V-${v['id']}-$docType',
              'title': title,
              'doc_type': docType,
              'date': dateStr,
              'days_left': daysLeft,
              'is_expired': false,
              'category': 'Vehicle',
            });
          }
        } catch (_) {}
      }

      checkDoc(v['insurance_expiry'], 'Insurance');
      checkDoc(v['fc_expiry'], 'FC');
      checkDoc(v['puc_expiry'], 'PUC');
    }

    // 2. Driver License Expiries
    for (var d in _drivers) {
      final dName = (d['name'] ?? 'Driver').toString().trim();
      final licDate = d['license_expiry'];

      if (licDate != null && licDate.toString().trim().isNotEmpty) {
        try {
          DateTime expDate = DateFormat('dd MMM yyyy').parse(licDate.toString().trim());
          int daysLeft = expDate.difference(today).inDays;

          if (daysLeft < 0) {
            alerts.add({
              'id': 'D-${d['id']}-License',
              'title': 'Driver: $dName',
              'doc_type': 'Driving License',
              'date': licDate,
              'days_left': daysLeft,
              'is_expired': true,
              'category': 'Driver',
            });
          } else if (daysLeft <= 30) {
            alerts.add({
              'id': 'D-${d['id']}-License',
              'title': 'Driver: $dName',
              'doc_type': 'Driving License',
              'date': licDate,
              'days_left': daysLeft,
              'is_expired': false,
              'category': 'Driver',
            });
          }
        } catch (_) {}
      }
    }

    alerts.sort((a, b) => (a['days_left'] as int).compareTo(b['days_left'] as int));
    return alerts;
  }
  
  List<Map<String, dynamic>> get bills => _bills; // Unfiltered
  List<Map<String, dynamic>> get suppliers => _suppliers; // Unfiltered
  
  // Filtered Lists
  List<Map<String, dynamic>> get labour => _labour.where((e) => _matchesSelectedDate(e['date'] ?? 'Today')).toList();
  List<Map<String, dynamic>> get vehicles => _vehicles.where((e) => _matchesSelectedDate(e['date'] ?? 'Today')).toList();
  List<Map<String, dynamic>> get drivers => _drivers.where((e) => _matchesSelectedDate(e['date'] ?? 'Today')).toList();
  List<Map<String, dynamic>> get siteIncome => _siteIncome.where((e) => _matchesSelectedDate(e['date'] ?? 'Today')).toList();
  // Expose unfiltered list for Site Management
  List<Map<String, dynamic>> get unfilteredSiteIncome => _siteIncome;
  List<Map<String, dynamic>> get siteExpenses => _siteExpenses
      .where((e) => _matchesSelectedDate(e['date'] ?? 'Today'))
      .where((e) => !_isDuplicateExpense(e))
      .toList();

  List<Map<String, dynamic>> get allSiteExpenses => _siteExpenses.where((e) => !_isDuplicateExpense(e)).toList();
  List<Map<String, dynamic>> get allSiteIncome => _siteIncome;
  List<Map<String, dynamic>> get allVehicles => _vehicles;
  List<Map<String, dynamic>> get allDrivers => _drivers;
  List<Map<String, dynamic>> get driverPayments => _driverPayments;
  List<Map<String, dynamic>> get allLabour => _labour;
  List<Map<String, dynamic>> get vehicleRegistry => _vehicleRegistry;
  List<Map<String, dynamic>> get customers => _customers;
  List<Map<String, dynamic>> get allVehiclePayments => _vehiclePayments;
  List<Map<String, dynamic>> get allCustomerPayments => _customerPayments;

  List<String> get allSites {
    Set<String> sites = {}; // Using Set to ensure uniqueness
    // 1. From Site Income (Primary Source of "Sites")
    for (var i in _siteIncome) { // Access source directly, not filtered, to get GLOBAL sites
       if (i['site'] != null) sites.add(i['site']);
    }
    // 2. From Labour (Maybe?) - Usually Labour is assigned to a Site defined in Income. 
    // Let's stick to Site Income as the definition of Sites for now.
    
    return sites.toList();
  }

  List<String> get activeSites {
    Set<String> sites = {};
    for (var i in _siteIncome) {
       // Status is stored as 'Active' or 'Completed' (or null default)
       // Filter only Active sites
       if (i['site'] != null && (i['status'] == null || i['status'] == 'Active')) {
          sites.add(i['site']);
       }
    }
    return sites.toList();
  }

  // --- DYNAMIC TOTALS ---

  void _sortByDateDesc(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });
  }

  void _sortByDateAsc(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        return da.compareTo(db);
      } catch (_) {
        return 0;
      }
    });
  }

  bool _isDuplicateExpense(Map<String, dynamic> e) {
    if (e['category'] != 'Vehicle' && e['category'] != 'Material') return false;
    
    final String id = e['id']?.toString() ?? '';
    // Manual expenses (EXP prefix) should NEVER be filtered as duplicates here
    if (id.startsWith('EXP')) return false;

    final String? vNo = e['vehicle_no']?.toString().trim().toLowerCase();
    if (vNo == null || vNo.isEmpty) return false;

    final eDate = e['date']?.toString().trim();
    final eAmt = parseAmount(e['amount']);

    return _vehicles.any((v) =>
        v['number'].toString().trim().toLowerCase() == vNo &&
        v['date']?.toString().trim() == eDate &&
        (parseAmount(v['total']) == eAmt || parseAmount(v['material_amount']) == eAmt));
  }

  double parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is! String) return 0.0;
    
    // Remove symbols and commas: "₹1,50,000" -> "150000"
    String clean = amount.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return 0.0;
    return double.tryParse(clean) ?? 0.0;
  }

  String getVehicleDisplayName(String? vNo) {
    if (vNo == null || vNo.trim().isEmpty) return '';
    final String clean = vNo.replaceAll(' ', '').replaceAll('-', '').toLowerCase().trim();
    if (clean.contains('storagetank') || clean.contains('bulktank') || clean.contains('bulkstorage')) {
      return 'Storage Tank';
    }

    String? type;

    // 1. Search Registry
    for (var r in _vehicleRegistry) {
      final rNum = (r['number'] ?? r['vehicle_no'] ?? '').toString().replaceAll(' ', '').replaceAll('-', '').toLowerCase().trim();
      final rType = (r['type'] ?? '').toString().trim();
      if (rNum.isNotEmpty && rNum == clean && rType.isNotEmpty) {
        type = rType;
        break;
      }
    }

    // 2. Search Vehicles
    if (type == null || type.isEmpty) {
      for (var v in _vehicles) {
        final vNum = (v['number'] ?? '').toString().replaceAll(' ', '').replaceAll('-', '').toLowerCase().trim();
        final vType = (v['type'] ?? '').toString().trim();
        if (vNum.isNotEmpty && vNum == clean && vType.isNotEmpty) {
          type = vType;
          break;
        }
      }
    }

    if (type != null && type.isNotEmpty) {
      return '${vNo.trim()} ($type)';
    }

    return vNo.trim();
  }

  String _formatAmount(double amount) {
    bool isNegative = amount < 0;
    double absAmount = amount.abs();
    String prefix = isNegative ? '-₹' : '₹';
    return '$prefix${absAmount.toInt()}';
  }

  double get totalExpenseValue {
    // Strictly sum from breakdown to ensure consistency with Reports
    return expenseBreakdown.values.fold(0.0, (sum, val) => sum + val);
  }

  List<Map<String, dynamic>> get allExpenseTransactions {
    List<Map<String, dynamic>> list = [];
    // 1. Site Expense Payments
    list.addAll(_siteExpensePayments);
    // 2. Labour Payments
    list.addAll(_labourPayments);
    // 3. Vehicle Payments (Filtered)
    for (var p in _vehiclePayments) {
        final v = _vehicles.firstWhere((e) => e['id'] == p['vehicle_id'], orElse: () => {});
        if (v.isNotEmpty) {
           bool isExpense = !_parseBool(v['isOwn']) || !_parseBool(v['isRentedOut'], defaultValue: true);
           if (!isExpense) continue;
        }
        list.add(p);
    }
    // 4. Supplier Payments (Exclude Discount entries from expenses)
    for (var p in _supplierPayments) {
      final type = p['type']?.toString() ?? 'Payment';
      if (type != 'Discount') list.add(p);
    }
    // 5. Driver Payments (Exclude Deduct from Advance)
    for (var p in _driverPayments) {
       final type = p['type']?.toString() ?? 'Payment';
       final mode = (p['mode'] ?? '').toString().trim();
       final isDeduct = mode == 'Deduct from Advance' || mode.toLowerCase().contains('deduct');
       if (type == 'Payment' && !isDeduct) list.add(p);
    }
    // 6. Bill Payments
    list.addAll(_billPayments);
    return list;
  }

  List<Map<String, dynamic>> get allIncomeTransactions {
    List<Map<String, dynamic>> list = [];
    // 1. Site Income Receipts
    list.addAll(_incomePayments);
    // 2. Own Vehicle Income
    for (var p in _vehiclePayments) {
        final v = _vehicles.firstWhere((e) => e['id'] == p['vehicle_id'], orElse: () => {});
        if (v.isNotEmpty && _parseBool(v['isOwn']) && _parseBool(v['isRentedOut'], defaultValue: true)) {
           list.add(p);
        }
    }
    return list;
  }

  String get totalExpense => _formatAmount(totalExpenseValue);

  Map<String, double> get expenseBreakdown {
    Map<String, double> categories = {};

    // 1. Site Expense Payments (Sum from site_expenses directly for Dashboard accuracy)
    for (var e in _siteExpenses) {
      if (_matchesSelectedDate(e['date'])) {
        final supplier = (e['supplier'] ?? '').toString().trim();
        final title = (e['title'] ?? '').toString().trim();
        final matName = (e['material_name'] ?? '').toString().trim();
        bool isInternalIssue = supplier == 'Storage Tank' || 
                               title.contains('Tank Dispense') || 
                               e['is_internal_issue'] == 1 || 
                               e['is_internal_issue'] == '1';

        if (!isInternalIssue) {
          final amount = parseAmount(e['paid']);
          final totalAmt = parseAmount(e['amount']);
          final effectiveAmt = totalAmt > 0 ? totalAmt : amount;
          if (effectiveAmt > 0) {
            String cat = e['category'] ?? 'Site Expense';
            final combinedText = '$title $matName $cat $supplier ${e['vehicle_no'] ?? ''}'.toLowerCase();
            if (combinedText.contains('storage tank') || combinedText.contains('bulk storage') || combinedText.contains('tank purchase') || combinedText.contains('fuel tank')) {
              cat = 'Bulk Fuel Storage';
            } else if (combinedText.contains('fuel') || combinedText.contains('diesel') || combinedText.contains('petrol') || combinedText.contains('bunk')) {
              cat = 'Vehicle Fuel';
            } else if (combinedText.contains('mechanic') || combinedText.contains('workshop') || combinedText.contains('service') || combinedText.contains('repair') || combinedText.contains('maintenance') || combinedText.contains('tyre') || combinedText.contains('oil') || combinedText.contains('spare')) {
              cat = 'Vehicle Maintenance';
            } else if (supplier.isNotEmpty) {
              cat = 'Supplier ($supplier)';
            }
            categories[cat] = (categories[cat] ?? 0) + effectiveAmt;
          }
        }
      }
    }

    // 2. Labour Payments (Sum from labour records directly for Dashboard accuracy)
    for (var l in _labour) {
      if (_matchesSelectedDate(l['date'] ?? 'Today')) {
        categories['Labour'] = (categories['Labour'] ?? 0) + parseAmount(l['advance']);
      }
    }

    // 3. Vehicle Expenses & Supplier Purchases from Vehicle Entries
    final vehicleKeywords = ['fuel', 'diesel', 'petrol', 'mechanic', 'workshop', 'service', 'repair', 'maintenance', 'oil', 'grease', 'tyre', 'spare'];
    for (var v in vehicles) {
      if (_matchesSelectedDate(v['date'])) {
        final String matName = (v['material_name'] ?? '').toString().toLowerCase().trim();
        final String supplier = (v['supplier'] ?? '').toString().trim();
        final String supplierLower = supplier.toLowerCase();
        
        bool isOwn = _parseBool(v['isOwn'], defaultValue: true);
        double buyCost = (double.tryParse(v['quantity']?.toString() ?? '0') ?? 0) * (double.tryParse(v['buy_price']?.toString() ?? '0') ?? 0);
        if (buyCost <= 0) buyCost = parseAmount(v['material_amount']);

        double totalAmt = parseAmount(v['total']);
        if (totalAmt <= 0) totalAmt = parseAmount(v['rent_amount']) + parseAmount(v['batta'] ?? v['batta_amount']);

        if (supplier.isNotEmpty) {
          double supAmt = isOwn ? buyCost : (buyCost > 0 ? buyCost : totalAmt);
          if (supAmt > 0) {
            bool isBunk = supplierLower.contains('bunk') || supplierLower.contains('fuel') || supplierLower.contains('petrol');
            bool isMechanic = supplierLower.contains('mechanic') || supplierLower.contains('workshop') || supplierLower.contains('garage') || supplierLower.contains('service');
            
            String supCat = 'Supplier ($supplier)';
            if (isBunk) supCat = 'Vehicle Fuel';
            else if (isMechanic) supCat = 'Vehicle Maintenance';
            
            categories[supCat] = (categories[supCat] ?? 0) + supAmt;
          }
        } else {
          bool isExpense = !isOwn || !_parseBool(v['isRentedOut'], defaultValue: true);
          if (isExpense) {
            bool isMaintenance = vehicleKeywords.any((k) => matName.contains(k) || supplierLower.contains(k));
            String cat = isMaintenance ? 'Vehicle Maintenance' : 'Vehicle Hire / Rent';
            if (!isMaintenance && matName.isNotEmpty && buyCost > 0) {
              cat = 'Materials';
            }
            if (totalAmt > 0) {
              categories[cat] = (categories[cat] ?? 0) + totalAmt;
            }
          }
        }
      }
    }

    // 4. Supplier Payments (Exclude Discount entries from expenses)

    for (var p in _supplierPayments) {
      if (_matchesSelectedDate(p['date'])) {
        final type = p['type']?.toString() ?? 'Payment';
        if (type == 'Discount') continue;

        final sId = (p['supplier_id'] ?? '').toString().trim();
        final s = _suppliers.firstWhere((e) => (e['id'] ?? '').toString().trim() == sId, orElse: () => {});
        String cat = 'Supplier Payments';
        if (s.isNotEmpty) {
           final supName = (s['name'] ?? '').toString().trim();
           final mat = (s['material'] ?? '').toString().toLowerCase();
           final name = supName.toLowerCase();
           bool isBunk = mat.contains('fuel') || mat.contains('petrol') || mat.contains('diesel') || mat.contains('bunk') || name.contains('bunk') || name.contains('fuel') || name.contains('petrol');
           bool isMechanic = mat.contains('mechanic') || mat.contains('workshop') || mat.contains('garage') || mat.contains('service') || name.contains('mechanic') || name.contains('workshop') || name.contains('garage');
           
           if (isBunk) cat = 'Vehicle Fuel';
           else if (isMechanic) cat = 'Vehicle Maintenance';
           else if (supName.isNotEmpty) cat = 'Supplier ($supName)';
        }
        if (!categories.containsKey(cat) && !categories.containsKey('Bulk Fuel Storage')) {
          categories[cat] = parseAmount(p['amount']);
        }
      }
    }

    // 5. Driver Salary Expenses (Monthly Salary Credits, Attendance Earnings & Payments)
    double driverSalaryExpense = 0.0;
    
    // Group driver payments, work credits, and daily wages attendance earnings
    Map<String, double> driverWorkTotals = {};
    Map<String, double> driverPaymentTotals = {};

    // A. Daily Wages Driver Attendance Earnings
    for (var att in _driverAttendance) {
       if (_matchesSelectedDate(att['date'] ?? 'Today')) {
          final String status = att['status']?.toString() ?? 'Present';
          if (status == 'Present') {
             final String dId = (att['driver_id'] ?? '').toString();
             double earnings = parseAmount(att['earnings']);
             if (earnings <= 0 && dId.isNotEmpty) {
                final driver = _drivers.firstWhere((d) => d['id'].toString() == dId, orElse: () => {});
                if (driver.isNotEmpty && driver['type'] == 'Daily') {
                   earnings = parseAmount(driver['salary'] ?? driver['earnings']);
                }
             }
             if (earnings > 0 && dId.isNotEmpty) {
                driverWorkTotals[dId] = (driverWorkTotals[dId] ?? 0) + earnings;
             }
          }
       }
    }

    // B. Monthly Driver Work Credits & Payments
    Map<String, double> driverRegularPaymentTotals = {};
    Map<String, double> driverAdvancePaymentTotals = {};

    for (var p in _driverPayments) {
       if (_matchesSelectedDate(p['date'])) {
          final String dId = (p['driver_id'] ?? '').toString();
          final String type = p['type']?.toString() ?? 'Payment';
          final String mode = (p['mode'] ?? '').toString().trim();
          final double amt = parseAmount(p['amount']);
          
          final bool isGiveAdvance = mode == 'Give Advance' || mode == 'Advance' || mode.contains('Advance Box') || (mode.toLowerCase().contains('advance') && !mode.toLowerCase().contains('deduct'));
          final bool isDeductAdvance = mode == 'Deduct from Advance' || mode.toLowerCase().contains('deduct');

          if (type == 'Work') {
             driverWorkTotals[dId] = (driverWorkTotals[dId] ?? 0) + amt;
          } else if (isGiveAdvance) {
             driverAdvancePaymentTotals[dId] = (driverAdvancePaymentTotals[dId] ?? 0) + amt;
          } else if (!isDeductAdvance) {
             driverRegularPaymentTotals[dId] = (driverRegularPaymentTotals[dId] ?? 0) + amt;
          }
       }
    }

    double driverAdvanceExpense = 0.0;

    // Combine work credits / daily wages or regular payments + advance payments per driver
    Set<String> allDriverIds = {
      ...driverWorkTotals.keys, 
      ...driverRegularPaymentTotals.keys, 
      ...driverAdvancePaymentTotals.keys
    };
    for (var dId in allDriverIds) {
       double workAmt = driverWorkTotals[dId] ?? 0.0;
       double regPaidAmt = driverRegularPaymentTotals[dId] ?? 0.0;
       double advPaidAmt = driverAdvancePaymentTotals[dId] ?? 0.0;
       
       double baseExpense = workAmt > 0 ? workAmt : regPaidAmt;
       driverSalaryExpense += baseExpense;
       driverAdvanceExpense += advPaidAmt;
    }

    if (driverSalaryExpense > 0) {
       categories['Driver Salary'] = driverSalaryExpense;
    }
    if (driverAdvanceExpense > 0) {
       categories['Driver Advance'] = driverAdvanceExpense;
    }

    // 6. Generic Bill Payments (Office/Misc)
    for (var p in _billPayments) {
       if (_matchesSelectedDate(p['date'])) {
         categories['Bills & Office'] = (categories['Bills & Office'] ?? 0) + parseAmount(p['amount']);
       }
    }

    return categories;
  }

  double get totalIncomeValue {
    double total = 0.0;
    // 1. Site Income (Directly from Site entries for Dashboard accuracy)
    for (var s in _siteIncome) {
      if (_matchesSelectedDate(s['date'])) {
        total += parseAmount(s['received']);
      }
    }

    // 2. Own Vehicle Income (Received from trip Customers)
    for (var p in _vehiclePayments) {
      if (_matchesSelectedDate(p['date'])) {
        final v = _vehicles.firstWhere((e) => e['id'] == p['vehicle_id'], orElse: () => {});
        if (v.isNotEmpty && _parseBool(v['isOwn']) && _parseBool(v['isRentedOut'], defaultValue: true)) {
           total += parseAmount(p['amount']);
        }
      }
    }
    // 3. Generic Customer Payments (Exclude Discounts from Cash Received / Income)
    for (var cp in _customerPayments) {
      if (_matchesSelectedDate(cp['date'])) {
         final isDisc = cp['type']?.toString() == 'Discount' || (cp['notes'] ?? '').toString().toLowerCase().contains('discount');
         if (isDisc) continue;
         total += parseAmount(cp['amount']);
      }
    }
    return total;
  }

  double get totalSalesValue {
    double total = 0.0;
    for (var v in vehicles) {
      if (_matchesSelectedDate(v['date'])) {
        final matAmt = parseAmount(v['material_amount']);
        final totalAmt = parseAmount(v['total']);
        final rentAmt = parseAmount(v['rent_amount']);
        final tripSales = totalAmt > 0 ? totalAmt : (matAmt > 0 ? matAmt : rentAmt);
        total += tripSales;
      }
    }
    for (var s in siteIncome) {
      if (_matchesSelectedDate(s['date'])) {
        final amt = parseAmount(s['amount']);
        if (amt > 0) {
          total += amt;
        }
      }
    }
    return total;
  }

  Map<String, double> get incomeBreakdown {
    Map<String, double> categories = {};
    
    // 1. Site Income
    for (var s in _siteIncome) {
      if (_matchesSelectedDate(s['date'])) {
        categories['Site Income'] = (categories['Site Income'] ?? 0) + parseAmount(s['received']);
      }
    }

    // 2. Vehicle Income
    for (var p in _vehiclePayments) {
      if (_matchesSelectedDate(p['date'])) {
        final v = _vehicles.firstWhere((e) => e['id'] == p['vehicle_id'], orElse: () => {});
        if (v.isNotEmpty && _parseBool(v['isOwn']) && _parseBool(v['isRentedOut'], defaultValue: true)) {
           categories['Vehicle Income'] = (categories['Vehicle Income'] ?? 0) + parseAmount(p['amount']);
        }
      }
    }
    // 3. Customer Payments (Exclude Discounts)
    for (var cp in _customerPayments) {
      if (_matchesSelectedDate(cp['date'])) {
         final isDisc = cp['type']?.toString() == 'Discount' || (cp['notes'] ?? '').toString().toLowerCase().contains('discount');
         if (isDisc) continue;
         categories['Direct Payment'] = (categories['Direct Payment'] ?? 0) + parseAmount(cp['amount']);
      }
    }
    
    return categories;
  }

  String get totalIncome => _formatAmount(totalIncomeValue);

  String get totalPending {
    double total = 0.0;
    // Income Pending
    for (var item in _siteIncome) {
      if (_matchesSelectedDate(item['date'] ?? 'Today')) {
        total += parseAmount(item['pending']);
      }
    }
    
    // Vehicle Balance
    for (var v in _vehicles) {
      if (_matchesSelectedDate(v['date'] ?? 'Today')) {
        total += parseAmount(v['balance']);
      }
    }

    // Supplier Balance
    for (var s in _suppliers) {
      if (_matchesSelectedDate(s['date'] ?? 'Today')) {
        total += parseAmount(s['balance']);
      }
    }

    // Labour Balance
    for (var l in _labour) {
      if (_matchesSelectedDate(l['date'] ?? 'Today')) {
        total += parseAmount(l['balance']);
      }
    }
    
    return _formatAmount(total);
  }

  // --- ACTIONS ---

  Future<void> resetApp() async {
    await _dbHelper.clearAllTables();
    _recentTransactions.clear();
    _bills.clear();
    _labour.clear();
    _vehicles.clear();
    _suppliers.clear();
    _drivers.clear();
    _siteIncome.clear();
    _siteExpenses.clear();
    _vehicleRegistry.clear();
    _customers.clear();
    _billPayments.clear();
    _supplierPayments.clear();
    _vehiclePayments.clear();
    _labourPayments.clear();
    _driverPayments.clear();
    _driverAttendance.clear();
    _incomePayments.clear();
    _siteExpensePayments.clear();
    _customerPayments.clear();
    _mainTankLiters = 0.0;
    _fuelIssues.clear();
    await fetchFuelTankData();
    notifyListeners();
  }


  // Generic Helper for ID creation
  String _generateId(String prefix) {
    // Use microseconds + random to avoid collision in tight loops
    final random = Random().nextInt(10000);
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  // BILLS
  Future<void> addBill(Map<String, dynamic> inputBill) async {
    final bill = Map<String, dynamic>.from(inputBill);
    if (!bill.containsKey('id')) {
      bill['id'] = _generateId('BILL');
    }
    
    // Auto-Calculate Status
    double amount = parseAmount(bill['amount']);
    double paid = parseAmount(bill['paid']);
    
    StatusType status = StatusType.pending;
    if (paid >= amount && amount > 0) {
      status = StatusType.paid;
    } else if (paid > 0) {
      status = StatusType.partial;
    }
    bill['status'] = status;
    
    // Ensure 'paid' is formatted (optional, but good for DB text consistency)
    // If entered as "500", maybe store as "₹500" or just "500". 
    // _parseAmount handles both. Let's store consistent with other money fields if possible, 
    // or just leave as is since we use _parseAmount everywhere.
    // bill['paid'] should be present.
    
    // Prepare for DB
    final Map<String, dynamic> dbBill = {...bill};
    dbBill['status'] = status.toString();
    
    await _dbHelper.insert('bills', dbBill);
    
    // Log Initial Payment if any
    if (paid > 0) {
      final payment = {
        'id': _generateId('PAY'),
        'bill_id': bill['id'],
        'amount': '₹${paid.toStringAsFixed(0)}',
        'date': bill['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      };
      await _dbHelper.insert('bill_payments', payment);
      _billPayments.add(payment);
    }

    // Memory
    final memoryBill = {...bill};
    _bills.insert(0, memoryBill);
    notifyListeners();
  }

  Future<void> updateBill(String id, Map<String, dynamic> newData) async {
    final index = _bills.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldBill = _bills[index];
      final merged = {...oldBill, ...newData};
      
      // Recalculate Logic
      double amount = parseAmount(merged['amount']);
      double paid = parseAmount(merged['paid']);
      double oldPaid = parseAmount(oldBill['paid']);
      
      StatusType status = StatusType.pending;
      if (paid >= amount && amount > 0) {
        status = StatusType.paid;
      } else if (paid > 0) {
        status = StatusType.partial;
      }
      merged['status'] = status;
      
      final Map<String, dynamic> dbBill = {...merged};
      dbBill['status'] = status.toString();
      
      await _dbHelper.update('bills', dbBill, 'id', id);
      
      // Log Payment Difference
      double diff = paid - oldPaid;
      if (diff > 0) {
         final payment = {
           'id': _generateId('PAY'),
           'bill_id': id,
           'amount': '₹${diff.toStringAsFixed(0)}',
           'date': newData['date'] ?? oldBill['date'], // Use new date if provided
         };
         await _dbHelper.insert('bill_payments', payment);
         _billPayments.add(payment);
      }

      _bills[index] = merged;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> getBillPayments(String billId) async {
    return await _dbHelper.query('bill_payments', where: 'bill_id = ?', whereArgs: [billId]);
  }

  Future<void> deleteBill(String id) async {
    await _dbHelper.delete('bills', 'id', id);
    _bills.removeWhere((element) => element['id'] == id);
    notifyListeners();
  }

  // LABOUR
  Future<void> addLabour(Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('LBR');
    await _dbHelper.insert('labour', data);
    
    double advance = parseAmount(data['advance']);
    if (advance > 0) {
      final payment = {
        'id': _generateId('PAY-LUR'),
        'labour_id': data['id'],
        'amount': '₹${advance.toStringAsFixed(0)}',
        'date': data['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      };
      await _dbHelper.insert('labour_payments', payment);
      _labourPayments.add(payment);
    }

    _labour.insert(0, data);
    
    // Sync Balances
    await _syncBalances(null, data);
    notifyListeners();
  }

  Future<void> updateLabour(String id, Map<String, dynamic> newData) async {
    final index = _labour.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _labour[index];
      final updated = {...oldData, ...newData};
      await _dbHelper.update('labour', updated, 'id', id);
      
      double newAdv = parseAmount(updated['advance']);
      double oldAdv = parseAmount(oldData['advance']);
      
      // Sync Payment Logs if paid amount changed
      if (newAdv != oldAdv) {
          if (newAdv <= 0) {
              await _dbHelper.delete('labour_payments', 'labour_id', id);
              _labourPayments.removeWhere((p) => p['labour_id'] == id);
          } else if (oldAdv <= 0 && newAdv > 0) {
              final payment = {
                'id': _generateId('PAY-LUR'),
                'labour_id': id,
                'amount': '₹${newAdv.toInt()}',
                'date': updated['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
              };
              await _dbHelper.insert('labour_payments', payment);
              _labourPayments.add(payment);
          } else {
              final pIndex = _labourPayments.indexWhere((p) => p['labour_id'] == id);
              if (pIndex != -1) {
                  final pId = _labourPayments[pIndex]['id'];
                  final updatedPayment = {
                    ..._labourPayments[pIndex],
                    'amount': '₹${newAdv.toInt()}',
                  };
                  await _dbHelper.update('labour_payments', updatedPayment, 'id', pId);
                  _labourPayments[pIndex] = updatedPayment;
              }
          }
      }

      _labour[index] = updated;
      
      // Sync Balances
      await _syncBalances(oldData, updated);
      notifyListeners();
    }
  }
  
  Future<List<Map<String, dynamic>>> getLabourPayments(String id) async {
    return await _dbHelper.query('labour_payments', where: 'labour_id = ?', whereArgs: [id]);
  }

  Future<void> addLabourPayment(String labourId, double amount, String date) async {
    final index = _labour.indexWhere((l) => l['id'] == labourId);
    if (index == -1) return;
    
    final worker = _labour[index];
    
    final payment = {
      'id': _generateId('PAY-LUR'),
      'labour_id': labourId,
      'amount': '₹${amount.toInt()}',
      'date': date,
    };
    await _dbHelper.insert('labour_payments', payment);
    _labourPayments.add(payment);
    
    // Sync Balances
    await _syncBalances(worker, worker);
    notifyListeners();
  }

  Future<void> deleteLabour(String id) async {
    final index = _labour.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _labour[index];
      await _dbHelper.delete('labour', 'id', id);
      _labour.removeAt(index);
      
      // Sync Balances
      await _syncBalances(oldData, null);
      notifyListeners();
    }
  }

  // VEHICLES
  Future<void> addVehicle(Map<String, dynamic> inputData) async {
    final data = Map<String, dynamic>.from(inputData);
    if (!data.containsKey('id')) data['id'] = _generateId('VEH');
    
    final dbData = {...data};
    // Ensure boolean values are converted to 1/0 for DB
    if (dbData['isOwn'] is bool) dbData['isOwn'] = dbData['isOwn'] ? 1 : 0;
    if (dbData['isRentedOut'] is bool) dbData['isRentedOut'] = dbData['isRentedOut'] ? 1 : 0;
    if (dbData['isOwnSite'] is bool) dbData['isOwnSite'] = dbData['isOwnSite'] ? 1 : 0;
    if (dbData['status'] is StatusType) dbData['status'] = dbData['status'].toString();
    
    try {
      await _dbHelper.insert('vehicles', dbData);
      
      // Ensure data added to list has boolean isOwn/isRentedOut for filters
      if (data['isOwn'] is int) data['isOwn'] = data['isOwn'] == 1;
      if (data['isRentedOut'] is int) data['isRentedOut'] = data['isRentedOut'] == 1;
      
      double paid = parseAmount(data['paid']);
      if (paid > 0) {
        final payment = {
          'id': _generateId('PAY-VEH'),
          'vehicle_id': data['id'],
          'amount': '₹${paid.toStringAsFixed(0)}',
          'date': data['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
        };
        await _dbHelper.insert('vehicle_payments', payment);
        _vehiclePayments.add(payment);
      }

      _vehicles.insert(0, data);
      
      // Unified Integration for Suppliers and Vehicles
      await _syncBalances(null, data);
    } catch (e) {
      debugPrint('Error adding vehicle to DB: $e');
      // Even if DB fails, ensure list has booleans for UI
      if (data['isOwn'] is int) data['isOwn'] = data['isOwn'] == 1;
      if (data['isRentedOut'] is int) data['isRentedOut'] = data['isRentedOut'] == 1;
    }

    notifyListeners();
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> newData, {bool skipSupplierSync = false}) async {
    final strId = id.toString().trim();
    final index = _vehicles.indexWhere((element) => element['id']?.toString().trim() == strId);
    if (index != -1) {
      final oldData = _vehicles[index];
      
      // Extract specific Payment Date if provided, otherwise default to now
      String? paymentDate = newData.remove('payment_date');
      
      final updated = {...oldData, ...newData};
      
      // Auto-recalculate balance and status
      double total = parseAmount(updated['total']);
      double paid = parseAmount(updated['paid']);
      double balance = total - paid;
      updated['balance'] = '₹${balance.toInt()}';
      updated['status'] = balance <= 0 ? StatusType.paid : StatusType.pending;

      // Ensure updated data in list has booleans
      if (updated['isOwn'] is int) updated['isOwn'] = updated['isOwn'] == 1;
      if (updated['isRentedOut'] is int) updated['isRentedOut'] = updated['isRentedOut'] == 1;
      
      final dbData = {...updated};
      if (dbData['isOwn'] is bool) dbData['isOwn'] = dbData['isOwn'] ? 1 : 0;
      if (dbData['isRentedOut'] is bool) dbData['isRentedOut'] = dbData['isRentedOut'] ? 1 : 0;
      if (dbData['isOwnSite'] is bool) dbData['isOwnSite'] = dbData['isOwnSite'] ? 1 : 0;
      if (dbData['status'] is StatusType) dbData['status'] = dbData['status'].toString();
      if (dbData['site'] != null && dbData['site'] is! String) dbData['site'] = dbData['site'].toString();

      try {
        await _dbHelper.update('vehicles', dbData, 'id', id);
        
        double newPaid = parseAmount(updated['paid']);
        double oldPaid = parseAmount(oldData['paid']);
        
        // Sync Payment Logs if paid amount changed
        if (newPaid != oldPaid) {
          if (newPaid <= 0) {
              await _dbHelper.delete('vehicle_payments', 'vehicle_id', id);
              _vehiclePayments.removeWhere((p) => p['vehicle_id'] == id);
          } else if (oldPaid <= 0 && newPaid > 0) {
              final payment = {
                'id': _generateId('PAY-VEH'),
                'vehicle_id': id,
                'amount': '₹${newPaid.toInt()}',
                'date': paymentDate ?? updated['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
              };
              await _dbHelper.insert('vehicle_payments', payment);
              _vehiclePayments.add(payment);
          } else {
              final pIndex = _vehiclePayments.indexWhere((p) => p['vehicle_id'] == id);
              if (pIndex != -1) {
                  final pId = _vehiclePayments[pIndex]['id'];
                  final updatedPayment = {
                    ..._vehiclePayments[pIndex],
                    'amount': '₹${newPaid.toInt()}',
                  };
                  if (paymentDate != null) updatedPayment['date'] = paymentDate;
                  await _dbHelper.update('vehicle_payments', updatedPayment, 'id', pId);
                  _vehiclePayments[pIndex] = updatedPayment;
              }
          }
        }
        
        _vehicles[index] = updated;
        
        // Unified Integration for Suppliers and Vehicles
        await _syncBalances(oldData, updated);
        
      } catch (e) {
        debugPrint('Error updating vehicle in DB: $e');
      }

      notifyListeners();
    }
  } // END updateVehicle
  
  Future<List<Map<String, dynamic>>> getVehiclePayments(String id) async {
    return await _dbHelper.query('vehicle_payments', where: 'vehicle_id = ?', whereArgs: [id]);
  }

  Future<void> deleteVehicle(String id) async {
    final strId = id.toString().trim();
    final index = _vehicles.indexWhere((element) => element['id']?.toString().trim() == strId);
    final intId = int.tryParse(strId);

    if (index != -1) {
      final oldData = _vehicles[index];
      
      if (intId != null) {
        await _dbHelper.rawDelete('vehicles', 'id = ? OR id = ?', [strId, intId]);
        await _dbHelper.rawDelete('vehicle_payments', 'vehicle_id = ? OR vehicle_id = ?', [strId, intId]);
      } else {
        await _dbHelper.rawDelete('vehicles', 'id = ?', [strId]);
        await _dbHelper.rawDelete('vehicle_payments', 'vehicle_id = ?', [strId]);
      }

      _vehicles.removeAt(index);
      _vehiclePayments.removeWhere((p) => p['vehicle_id']?.toString().trim() == strId || (intId != null && p['vehicle_id']?.toString().trim() == intId.toString()));
      
      // Sync balances AFTER removal from memory
      await _syncBalances(oldData, null);
      notifyListeners();
    } else {
      // Fallback: Delete directly from DB and update memory lists
      if (intId != null) {
        await _dbHelper.rawDelete('vehicles', 'id = ? OR id = ?', [strId, intId]);
        await _dbHelper.rawDelete('vehicle_payments', 'vehicle_id = ? OR vehicle_id = ?', [strId, intId]);
      } else {
        await _dbHelper.rawDelete('vehicles', 'id = ?', [strId]);
        await _dbHelper.rawDelete('vehicle_payments', 'vehicle_id = ?', [strId]);
      }

      _vehicles.removeWhere((element) => element['id']?.toString().trim() == strId || (intId != null && element['id']?.toString().trim() == intId.toString()));
      _vehiclePayments.removeWhere((p) => p['vehicle_id']?.toString().trim() == strId || (intId != null && p['vehicle_id']?.toString().trim() == intId.toString()));
      notifyListeners();
    }
  }

  // VEHICLE REGISTRY
  Future<void> addRegisteredVehicle(Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('VREG');
    await _dbHelper.insert('vehicle_registry', data);
    _vehicleRegistry.insert(0, data);
    notifyListeners();
  }

  Future<void> updateRegisteredVehicle(String id, Map<String, dynamic> newData) async {
    final index = _vehicleRegistry.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final updated = {..._vehicleRegistry[index], ...newData};
      await _dbHelper.update('vehicle_registry', updated, 'id', id);
      _vehicleRegistry[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteRegisteredVehicle(String id) async {
    await _dbHelper.delete('vehicle_registry', 'id', id);
    _vehicleRegistry.removeWhere((element) => element['id'] == id);
    notifyListeners();
  }

  // CUSTOMERS
  Future<void> addCustomer(Map<String, dynamic> data) async {
    try {
      if (!data.containsKey('id')) data['id'] = _generateId('CUST');
      if (!data.containsKey('balance')) data['balance'] = '₹0';
      if (!data.containsKey('date')) data['date'] = DateFormat('dd MMM yyyy').format(DateTime.now());
      
      await _dbHelper.insert('customers', data);
      _customers.insert(0, data);
      
      // Sync in case there are existing vehicles tied to this name
      await _syncBalances(null, data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding customer: $e');
      rethrow;
    }
  }

  Future<void> updateCustomer(String id, Map<String, dynamic> newData) async {
    try {
      final index = _customers.indexWhere((element) => element['id'] == id);
      if (index != -1) {
        final oldData = _customers[index];
        final updated = {...oldData, ...newData};
        await _dbHelper.update('customers', updated, 'id', id);
        _customers[index] = updated;
        
        // Sync affected balances (e.g. if name changed)
        await _syncBalances(oldData, updated);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    final index = _customers.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _customers[index];
      await _dbHelper.delete('customers', 'id', id);
      _customers.removeAt(index);
      
      // Sync balances (e.g. if any vehicles were tied to this customer name)
      await _syncBalances(oldData, null);
      
      notifyListeners();
    }
  }

  Future<void> syncCustomerBalanceByName(String name) async {
    final index = _customers.indexWhere((element) => element['name'].toLowerCase().trim() == name.toLowerCase().trim());
    if (index == -1) return;

    final customer = _customers[index];
    
    // Use the dynamic ledger calculator for consistency
    final ledger = await getCustomerLedgerCategorized(name);
    
    double totalBilled = 0;
    double totalPaid = 0;

    // 1. Calculate from Unpaid List (These are bills/outstanding)
    for (var item in ledger['unpaid']!) {
       // Only add the 'balance' (amount) of unpaid items to total debt
       // Wait, it's safer to reconstruct from all items
    }
    
    // BETTER: Recalculate from all source entries
    // Total Billed = Vehicles Total + Site Expenses
    final vehicles = _vehicles.where((v) => v['customer']?.toString().toLowerCase().trim() == name.toLowerCase().trim());
    for (var v in vehicles) {
       totalBilled += parseAmount(v['total']);
       totalPaid += parseAmount(v['paid']); // Site level payments
    }

    final clientIncomes = _siteIncome.where((si) => si['client']?.toString().toLowerCase().trim() == name.toLowerCase().trim());
    for (var i in clientIncomes) {
       totalBilled += parseAmount(i['estimate']);
    }

    final clientSites = clientIncomes
        .map((i) => i['site']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();

    final expenses = _siteExpenses
        .where((e) => clientSites.contains(e['site']))
        .where((e) => e['category'] != 'Vehicle') // Exclude Vehicle (Maintenance)
        .where((e) => !_isDuplicateExpense(e));
    for (var e in expenses) {
        totalBilled += parseAmount(e['amount']);
        totalPaid += parseAmount(e['paid']);
    }

    // 2. Add Site Income Receipts (Received from Client)
    for (var i in clientIncomes) {
       final payments = await getIncomePayments(i['id']);
       for (var p in payments) {
          totalPaid += parseAmount(p['amount']);
       }
    }

    // 3. Add Generic Customer Payments (Requirement 1.iii)
    final genericPayments = _customerPayments.where((cp) => cp['customer_name']?.toString().toLowerCase().trim() == name.toLowerCase().trim());
    for (var gp in genericPayments) {
       totalPaid += parseAmount(gp['amount']);
    }

    final balanceAmt = totalBilled - totalPaid;

    final updated = {
       ...customer, 
       'balance': '₹${balanceAmt.toInt()}'
    };
    await _dbHelper.update('customers', updated, 'id', customer['id']);
    _customers[index] = updated;
    notifyListeners();
  }


  // SUPPLIERS
  Future<void> addSupplier(Map<String, dynamic> data) async {
    final String name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
       bool exists = _suppliers.any((s) => (s['name'] ?? '').toString().trim().toLowerCase() == name.toLowerCase());
       if (exists) {
          throw Exception("Supplier '$name' already exists!");
       }
    }

    if (!data.containsKey('id')) data['id'] = _generateId('SUP');
    await _dbHelper.insert('suppliers', data);
    
    double paid = parseAmount(data['paid']);
    if (paid > 0) {
      final payment = {
        'id': _generateId('PAY-SUP'),
        'supplier_id': data['id'],
        'amount': '₹${paid.toStringAsFixed(0)}',
        'date': data['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      };
      await _dbHelper.insert('supplier_payments', payment);
      _supplierPayments.add(payment);
    }

    _suppliers.insert(0, data);
    
    // Sync Balance
    await syncSupplierBalanceByName(data['name']);
    notifyListeners();
  }
  
  Future<void> updateSupplier(String id, Map<String, dynamic> newData) async {
     final index = _suppliers.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _suppliers[index];
      final updated = {...oldData, ...newData};
      await _dbHelper.update('suppliers', updated, 'id', id);
      
      _suppliers[index] = updated;
      
      // Sync Balances
      await _syncBalances(oldData, updated);
      notifyListeners();
    }
  }

  Future<void> recordSupplierPayment(String supplierId, double amount, String date, {bool isDiscount = false, String? notes}) async {
    final index = _suppliers.indexWhere((s) => s['id'] == supplierId);
    if (index == -1) return;
    
    final supplier = _suppliers[index];
    
    final payment = {
      'id': _generateId('PAY-SUP'),
      'supplier_id': supplierId,
      'amount': '₹${amount.toInt()}',
      'date': date,
      'type': isDiscount ? 'Discount' : 'Payment',
      'notes': notes ?? (isDiscount ? 'Discount Received' : 'Payment Made'),
    };
    await _dbHelper.insert('supplier_payments', payment);
    _supplierPayments.add(payment);
    
    // Trigger Sync (Both will be supplier as it's the same entity being affected)
    await _syncBalances(supplier, supplier);
    notifyListeners();
  }
  
  Future<List<Map<String, dynamic>>> getSupplierPayments(String id) async {
    return await _dbHelper.query('supplier_payments', where: 'supplier_id = ?', whereArgs: [id]);
  }

  Future<void> updateSupplierPayment(String id, Map<String, dynamic> newData) async {
    final index = _supplierPayments.indexWhere((p) => p['id'].toString() == id.toString());
    // Always update in DB
    await _dbHelper.update('supplier_payments', newData, 'id', id);
    String? supplierName;
    if (index != -1) {
      _supplierPayments[index] = {..._supplierPayments[index], ...newData};
      final supplierId = _supplierPayments[index]['supplier_id']?.toString();
      final supplier = _suppliers.firstWhere((s) => s['id'].toString() == supplierId, orElse: () => {});
      if (supplier.isNotEmpty) {
         supplierName = supplier['name'];
      }
    }
    if (supplierName != null) {
      await syncSupplierBalanceByName(supplierName);
    }
    notifyListeners();
  }

  Future<void> deleteSupplierPayment(dynamic id) async {
    final strId = id.toString();
    final index = _supplierPayments.indexWhere(
      (p) => p['id'].toString() == strId
    );
    
    String? supplierId;
    String? supplierName;
    if (index != -1) {
      supplierId = _supplierPayments[index]['supplier_id']?.toString();
      final supplier = _suppliers.firstWhere((s) => s['id'].toString() == supplierId, orElse: () => {});
      if (supplier.isNotEmpty) {
         supplierName = supplier['name'];
      }
      _supplierPayments.removeAt(index);
    }

    // Delete from DB handling both int and string types
    final dynamic queryId = int.tryParse(strId) ?? strId;
    await _dbHelper.delete('supplier_payments', 'id', queryId);

    // Sync balances if we know the supplier
    if (supplierName != null) {
      await syncSupplierBalanceByName(supplierName);
    } else {
      _supplierPayments = List.from(await _dbHelper.query('supplier_payments'));
      await syncAllSupplierBalances();
    }
    notifyListeners();
  }



  Future<void> deleteSupplier(String id) async {
    final index = _suppliers.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _suppliers[index];
      await _dbHelper.delete('suppliers', 'id', id);
      _suppliers.removeAt(index);
      
      // Sync balances (Recalculate any remaining transactions for this supplier name)
      await _syncBalances(oldData, null);
      
      notifyListeners();
    }
  }

  // DRIVERS
  Future<void> processMonthlySalaries() async {
    final now = DateTime.now();
    for (var driver in _drivers) {
      final type = driver['type']?.toString();
      final empType = driver['emp_type']?.toString();
      final driverId = driver['id']?.toString();
      final isPaused = (driver['pause_salary'] == 1 || driver['pause_salary'] == true || driver['pause_salary']?.toString() == '1');
      if (isPaused) continue;

      if (type == 'Monthly') {
        final salaryStr = driver['salary']?.toString() ?? driver['earnings']?.toString() ?? '0';
        final salaryVal = parseAmount(salaryStr);
        if (salaryVal <= 0) continue;

        DateTime startDate;
        try {
          startDate = DateFormat('dd MMM yyyy').parse(driver['date'] ?? '');
        } catch (_) {
          startDate = DateTime(now.year, now.month, 1);
        }

        DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);

        DateTime endMonth = DateTime(now.year, now.month, 1);
        final joinedMonth = currentMonth;

        if (empType == 'Temporary') {
          // Temporary monthly drivers get salary credited ONLY for their joined month.
          // Auto-credit does not continue for future months.
          endMonth = joinedMonth;
        }

        // Remove any invalid M-SAL entries prior to joinedMonth
        final invalidPayments = _driverPayments.where((p) {
          if (p['driver_id']?.toString() != driverId || p['type'] != 'Work') return false;
          final id = p['id']?.toString() ?? '';
          if (!id.startsWith('M-SAL-')) return false;
          try {
            final pDate = DateFormat('dd MMM yyyy').parse(p['date'] ?? '');
            final pMonth = DateTime(pDate.year, pDate.month, 1);
            if (pMonth.isBefore(joinedMonth)) return true;
            return false;
          } catch (_) {
            return false;
          }
        }).toList();

        for (var inv in invalidPayments) {
          await _dbHelper.delete('driver_payments', 'id', inv['id']);
          _driverPayments.removeWhere((p) => p['id'] == inv['id']);
        }

        while (!currentMonth.isAfter(endMonth)) {
          final monthKey = DateFormat('yyyy-MM').format(currentMonth);
          String dateStr = DateFormat('dd MMM yyyy').format(currentMonth);
          if (currentMonth.year == joinedMonth.year && 
              currentMonth.month == joinedMonth.month && 
              driver['date'] != null && 
              driver['date'].toString().trim().isNotEmpty) {
            dateStr = driver['date'].toString().trim();
          }
          final workId = 'M-SAL-$driverId-$monthKey';
          final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;

          final existing = await _dbHelper.query('driver_payments', where: 'id = ?', whereArgs: [workId]);
          if (existing.isEmpty) {
            final payment = {
              'id': workId,
              'driver_id': driverId,
              'amount': '₹${salaryVal.toInt()}',
              'date': dateStr,
              'type': 'Work',
            };
            await _dbHelper.insert('driver_payments', payment);
            _driverPayments.add(payment);
          } else if (isCurrentMonth || empType == 'Temporary') {
            final formattedAmt = '₹${salaryVal.toInt()}';
            Map<String, dynamic> updateData = {};
            if (existing.first['amount'] != formattedAmt) updateData['amount'] = formattedAmt;
            if (currentMonth.year == joinedMonth.year && currentMonth.month == joinedMonth.month && driver['date'] != null) {
               final curJoiningDate = driver['date'].toString().trim();
               if (curJoiningDate.isNotEmpty && existing.first['date'] != curJoiningDate) {
                 updateData['date'] = curJoiningDate;
               }
            }
            if (updateData.isNotEmpty) {
              await _dbHelper.update('driver_payments', updateData, 'id', workId);
              final idx = _driverPayments.indexWhere((p) => p['id'] == workId);
              if (idx != -1) {
                _driverPayments[idx] = {..._driverPayments[idx], ...updateData};
              }
            }
          }

          currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
        }

        await syncDriverBalanceById(driverId!);
      }
    }
  }

  Future<void> creditDriverMonthlySalary(String driverId, DateTime monthDate, double amount, {DateTime? creditDate}) async {
    final strDriverId = driverId.toString();
    final monthKey = DateFormat('yyyy-MM').format(monthDate);
    final targetDate = creditDate ?? (monthDate.month == DateTime.now().month && monthDate.year == DateTime.now().year ? DateTime.now() : DateTime(monthDate.year, monthDate.month, 1));
    final dateStr = DateFormat('dd MMM yyyy').format(targetDate);
    final workId = 'M-SAL-$strDriverId-$monthKey';
    final formattedAmt = '₹${amount.toInt()}';

    final existingIndex = _driverPayments.indexWhere((p) => p['id'] == workId);
    if (existingIndex != -1) {
      await _dbHelper.update('driver_payments', {'amount': formattedAmt, 'date': dateStr}, 'id', workId);
      _driverPayments[existingIndex] = {
        ..._driverPayments[existingIndex],
        'amount': formattedAmt,
        'date': dateStr,
        'type': 'Work',
      };
    } else {
      final payment = {
        'id': workId,
        'driver_id': strDriverId,
        'amount': formattedAmt,
        'date': dateStr,
        'type': 'Work',
      };
      await _dbHelper.insert('driver_payments', payment);
      _driverPayments.add(payment);
    }

    await syncDriverBalanceById(strDriverId);
    notifyListeners();
  }

  String? getLastCreditedSalaryMonth(String driverId) {
    final strId = driverId.toString().trim();
    final mSalEntries = _driverPayments.where((p) {
      final pDriverId = (p['driver_id'] ?? '').toString().trim();
      final type = p['type']?.toString() ?? '';
      final id = p['id']?.toString() ?? '';
      return pDriverId == strId && type == 'Work' && id.startsWith('M-SAL-');
    }).toList();

    if (mSalEntries.isEmpty) return null;

    mSalEntries.sort((a, b) {
      try {
        final da = DateFormat('dd MMM yyyy').parse(a['date'] ?? '');
        final db = DateFormat('dd MMM yyyy').parse(b['date'] ?? '');
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });

    try {
      final latestDateStr = mSalEntries.first['date']?.toString() ?? '';
      final d = DateFormat('dd MMM yyyy').parse(latestDateStr);
      return DateFormat('MMM yyyy').format(d);
    } catch (_) {
      return null;
    }
  }

  Future<void> addDriver(Map<String, dynamic> inputData) async {
    final data = Map<String, dynamic>.from(inputData);
    if (!data.containsKey('id')) data['id'] = _generateId('DRV');
    
    final dbDriver = {...data};
    dbDriver.remove('advance_date');
    if (dbDriver['pause_salary'] is bool) dbDriver['pause_salary'] = (dbDriver['pause_salary'] as bool) ? 1 : 0;
    if (dbDriver['status'] is StatusType) dbDriver['status'] = dbDriver['status'].toString();

    await _dbHelper.insert('drivers', dbDriver);
    
    double advanceAmt = parseAmount(data['advance_amount'] ?? data['advance']);
    String advanceDate = data['advance_date'] ?? dbDriver['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now());

    if (advanceAmt > 0) {
      final payment = {
        'id': _generateId('PAY-DRV'),
        'driver_id': data['id'].toString(),
        'amount': '₹${advanceAmt.toInt()}',
        'date': advanceDate,
        'type': 'Payment',
        'mode': 'Give Advance',
      };
      await _dbHelper.insert('driver_payments', payment);
      _driverPayments.add(payment);
    } else {
      double paid = parseAmount(data['paid']);
      if (paid > 0) {
        final payment = {
          'id': _generateId('PAY-DRV'),
          'driver_id': data['id'].toString(),
          'amount': '₹${paid.toInt()}',
          'date': dbDriver['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          'type': 'Payment',
          'mode': 'Cash',
        };
        await _dbHelper.insert('driver_payments', payment);
        _driverPayments.add(payment);
      }
    }

    final memoryDriver = {...data};
    if (memoryDriver['status'] is String) {
        memoryDriver['status'] = _parseStatus(memoryDriver['status']);
    }
    
    _drivers.insert(0, memoryDriver);
    
    // Auto-process monthly salary credit if Monthly type
    await processMonthlySalaries();
    await syncDriverBalanceById(memoryDriver['id'].toString());
    await _syncBalances(null, memoryDriver);
    notifyListeners();
  }

  Future<void> updateDriver(String id, Map<String, dynamic> newData) async {
    final strId = id.toString();
    final index = _drivers.indexWhere((element) => element['id'].toString() == strId);
    if (index != -1) {
      final oldData = _drivers[index];
      double oldAdv = parseAmount(oldData['advance_amount'] ?? oldData['advance']);
      double newAdv = parseAmount(newData['advance_amount'] ?? newData['advance']);
      double diff = newAdv - oldAdv;

      if (diff > 0) {
        final advDate = newData['advance_date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now());
        final payment = {
          'id': _generateId('PAY-DRV'),
          'driver_id': strId,
          'amount': '₹${diff.toInt()}',
          'date': advDate,
          'type': 'Payment',
          'mode': 'Give Advance',
        };
        await _dbHelper.insert('driver_payments', payment);
        _driverPayments.add(payment);
      }

      final updated = {...oldData, ...newData};
      
      final dbData = {...updated};
      dbData.remove('advance_date');
      if (dbData['pause_salary'] is bool) dbData['pause_salary'] = (dbData['pause_salary'] as bool) ? 1 : 0;
      if (dbData['status'] is StatusType) dbData['status'] = dbData['status'].toString();
      
      await _dbHelper.update('drivers', dbData, 'id', strId);
      _drivers[index] = updated;
      
      await processMonthlySalaries();
      await syncDriverBalanceById(strId);
      await _syncBalances(oldData, updated);
      notifyListeners();
    }
  }

  Future<void> updateDriverAdvance(String driverId, double newAdvance, {String? advanceDate}) async {
    final strDriverId = driverId.toString();
    final index = _drivers.indexWhere((d) => d['id'].toString() == strDriverId);
    if (index != -1) {
      final driver = _drivers[index];
      double currentAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
      final formattedAdv = '₹${newAdvance.toInt()}';
      final updated = {
        ...driver,
        'advance_amount': formattedAdv,
      };
      await _dbHelper.update('drivers', {'advance_amount': formattedAdv}, 'id', driver['id']);
      _drivers[index] = updated;

      double diff = newAdvance - currentAdv;
      final targetDate = advanceDate ?? DateFormat('dd MMM yyyy').format(DateTime.now());

      if (diff > 0) {
        final payment = {
          'id': _generateId('PAY-DRV'),
          'driver_id': strDriverId,
          'amount': '₹${diff.toInt()}',
          'date': targetDate,
          'type': 'Payment',
          'mode': 'Give Advance',
        };
        await _dbHelper.insert('driver_payments', payment);
        _driverPayments.add(payment);
      } else if (newAdvance > 0 && currentAdv == 0) {
        final payment = {
          'id': _generateId('PAY-DRV'),
          'driver_id': strDriverId,
          'amount': '₹${newAdvance.toInt()}',
          'date': targetDate,
          'type': 'Payment',
          'mode': 'Give Advance',
        };
        await _dbHelper.insert('driver_payments', payment);
        _driverPayments.add(payment);
      }

      await syncDriverBalanceById(strDriverId);
      notifyListeners();
    }
  }

  double getDriverAdvanceGiven(String driverId) {
    final strId = driverId.toString().trim();
    final driver = _drivers.firstWhere(
      (d) => (d['id'] ?? '').toString().trim() == strId,
      orElse: () => {},
    );
    double initialAdvField = parseAmount(driver['advance_amount'] ?? driver['advance']);

    double advFromPayments = _driverPayments.where((p) {
      final pDriverId = (p['driver_id'] ?? '').toString().trim();
      final mode = (p['mode'] ?? '').toString().trim().toLowerCase();
      final type = (p['type'] ?? '').toString().trim();
      final isGiveAdv = mode == 'give advance' || 
                        mode == 'advance' || 
                        mode.contains('give advance') || 
                        mode == 'advance box given' ||
                        mode.contains('அட்வான்ஸ் வழங்குதல்');
      return pDriverId == strId && (type == 'Payment' || type == 'Payment Paid') && isGiveAdv;
    }).fold(0.0, (sum, p) => sum + parseAmount(p['amount']));

    return advFromPayments > initialAdvField ? advFromPayments : initialAdvField;
  }

  double getDriverAdvanceDeducted(String driverId) {
    final strId = driverId.toString().trim();
    return _driverPayments.where((p) {
      final pDriverId = (p['driver_id'] ?? '').toString().trim();
      final mode = (p['mode'] ?? '').toString().trim().toLowerCase();
      return pDriverId == strId && (mode == 'deduct from advance' || mode.contains('deduct') || mode.contains('கழித்தல்'));
    }).fold(0.0, (sum, p) => sum + parseAmount(p['amount']));
  }

  double getDriverRemainingAdvance(Map<String, dynamic> driver) {
    final driverId = (driver['id'] ?? '').toString().trim();
    double totalAdvGiven = getDriverAdvanceGiven(driverId);
    double deducted = getDriverAdvanceDeducted(driverId);
    double remaining = totalAdvGiven - deducted;
    return remaining < 0 ? 0.0 : remaining;
  }

  double getDriverInitialAdvance(Map<String, dynamic> driver) {
    final driverId = (driver['id'] ?? '').toString().trim();
    return getDriverAdvanceGiven(driverId);
  }

  Future<void> addDriverPayment(String driverId, double amount, DateTime date, {String mode = 'Cash', String? time}) async {
    final strDriverId = driverId.toString();

    final now = DateTime.now();
    final timeStr = time ?? DateFormat('hh:mm a').format(now);
    final cleanMode = mode.trim().isEmpty ? 'Cash' : mode.trim();

    final isGiveAdvance = cleanMode == 'Give Advance' || cleanMode == 'Advance' || cleanMode.toLowerCase().contains('give advance');

    if (isGiveAdvance) {
      final dIndex = _drivers.indexWhere((element) => element['id'].toString() == strDriverId);
      if (dIndex != -1) {
        final driver = _drivers[dIndex];
        final currentAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
        final newAdv = currentAdv + amount;
        final formattedAdv = '₹${newAdv.toInt()}';
        await _dbHelper.update('drivers', {'advance_amount': formattedAdv}, 'id', driver['id']);
        _drivers[dIndex] = {...driver, 'advance_amount': formattedAdv};
      }
    }

    // 1. Log Payment
    final payment = {
      'id': _generateId('PAY-DRV'),
      'driver_id': strDriverId,
      'amount': '₹${amount.toInt()}',
      'date': DateFormat('dd MMM yyyy').format(date),
      'time': timeStr,
      'type': 'Payment',
      'mode': cleanMode,
    };
    await _dbHelper.insert('driver_payments', payment);
    _driverPayments.add(payment);

    final index = _drivers.indexWhere((element) => element['id'].toString() == strDriverId);
    if (index != -1) {
      final driver = _drivers[index];
      await syncDriverBalanceById(strDriverId);
      await _syncBalances(driver, driver);
    } else {
      await syncDriverBalanceById(strDriverId);
    }

    notifyListeners();
  }

  Future<void> deleteDriverPayment(String paymentId) async {
    final index = _driverPayments.indexWhere((p) => p['id'] == paymentId);
    if (index != -1) {
      final p = _driverPayments[index];
      final driverId = p['driver_id']?.toString();
      final modeStr = (p['mode'] ?? '').toString();
      final isGiveAdvance = modeStr == 'Give Advance' || modeStr == 'Advance' || modeStr.toLowerCase().contains('give advance');

      if (isGiveAdvance && driverId != null) {
        final dIndex = _drivers.indexWhere((d) => d['id'].toString() == driverId.toString());
        if (dIndex != -1) {
          final driver = _drivers[dIndex];
          final currentAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
          final payAmt = parseAmount(p['amount']);
          final newAdv = (currentAdv - payAmt) < 0 ? 0.0 : (currentAdv - payAmt);
          final formattedAdv = '₹${newAdv.toInt()}';
          await _dbHelper.update('drivers', {'advance_amount': formattedAdv}, 'id', driver['id']);
          _drivers[dIndex] = {...driver, 'advance_amount': formattedAdv};
        }
      }

      await _dbHelper.delete('driver_payments', 'id', paymentId);
      _driverPayments.removeAt(index);
      if (driverId != null) {
        await syncDriverBalanceById(driverId);
      }
      notifyListeners();
    }
  }

  Future<void> updateDriverPayment(
    String paymentId, {
    required String driverId,
    required double amount,
    required DateTime date,
    String mode = 'Cash',
    String? time,
  }) async {
    final index = _driverPayments.indexWhere((p) => p['id']?.toString() == paymentId.toString());
    if (index == -1) return;

    final oldPayment = _driverPayments[index];
    final oldDriverId = oldPayment['driver_id']?.toString();
    final oldAmount = parseAmount(oldPayment['amount']);
    final oldMode = (oldPayment['mode'] ?? '').toString();
    final isOldGiveAdv = oldMode == 'Give Advance' || oldMode == 'Advance' || oldMode.toLowerCase().contains('give advance');

    final strDriverId = driverId.toString();
    final cleanMode = mode.trim().isEmpty ? 'Cash' : mode.trim();
    final isNewGiveAdv = cleanMode == 'Give Advance' || cleanMode == 'Advance' || cleanMode.toLowerCase().contains('give advance');

    // Reverse old advance if it was Give Advance
    if (isOldGiveAdv && oldDriverId != null) {
      final dIndex = _drivers.indexWhere((d) => d['id'].toString() == oldDriverId.toString());
      if (dIndex != -1) {
        final driver = _drivers[dIndex];
        final currentAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
        final newAdv = (currentAdv - oldAmount) < 0 ? 0.0 : (currentAdv - oldAmount);
        final formattedAdv = '₹${newAdv.toInt()}';
        await _dbHelper.update('drivers', {'advance_amount': formattedAdv}, 'id', driver['id']);
        _drivers[dIndex] = {...driver, 'advance_amount': formattedAdv};
      }
    }

    // Apply new advance if it is Give Advance
    if (isNewGiveAdv) {
      final dIndex = _drivers.indexWhere((d) => d['id'].toString() == strDriverId.toString());
      if (dIndex != -1) {
        final driver = _drivers[dIndex];
        final currentAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
        final newAdv = currentAdv + amount;
        final formattedAdv = '₹${newAdv.toInt()}';
        await _dbHelper.update('drivers', {'advance_amount': formattedAdv}, 'id', driver['id']);
        _drivers[dIndex] = {...driver, 'advance_amount': formattedAdv};
      }
    }

    final timeStr = time ?? oldPayment['time'] ?? DateFormat('hh:mm a').format(DateTime.now());
    final updatedPayment = {
      ...oldPayment,
      'driver_id': strDriverId,
      'amount': '₹${amount.toInt()}',
      'date': DateFormat('dd MMM yyyy').format(date),
      'time': timeStr,
      'mode': cleanMode,
    };

    await _dbHelper.update('driver_payments', updatedPayment, 'id', paymentId);
    _driverPayments[index] = updatedPayment;

    if (oldDriverId != null) {
      await syncDriverBalanceById(oldDriverId);
    }
    if (strDriverId != oldDriverId) {
      await syncDriverBalanceById(strDriverId);
    }

    notifyListeners();
  }
  
  Future<List<Map<String, dynamic>>> getDriverPayments(String id) async {
    return await _dbHelper.query('driver_payments', where: 'driver_id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDriverAttendance(String date) async {
    return await _dbHelper.query('driver_attendance', where: 'date = ?', whereArgs: [date]);
  }

  Future<void> markBulkAttendance(List<Map<String, dynamic>> attendanceList) async {
    Set<String> affectedDriverIds = {};
    for (var item in attendanceList) {
      if (item['driver_id'] != null) affectedDriverIds.add(item['driver_id'].toString());

      final driverId = item['driver_id']?.toString();
      if (driverId != null) {
        final driver = _drivers.firstWhere((d) => d['id'].toString() == driverId, orElse: () => {});
        if (driver.isNotEmpty && driver['type'] == 'Daily') {
          if (item['status'] == 'Present') {
            double dailyWage = parseAmount(driver['salary'] ?? driver['earnings']);
            item['earnings'] = '₹${dailyWage.toInt()}';
          } else {
            item['earnings'] = '₹0';
          }
        }
      }

      // Check if entry exists for this driver and date
      final existing = await _dbHelper.query('driver_attendance', 
        where: 'driver_id = ? AND date = ?', 
        whereArgs: [item['driver_id'], item['date']]);

      try {
        if (existing.isNotEmpty) {
          String validId = existing.first['id'];
          await _dbHelper.update('driver_attendance', item, 'id', validId);
          if (existing.length > 1) {
            for (int i = 1; i < existing.length; i++) {
              await _dbHelper.delete('driver_attendance', 'id', existing[i]['id']);
            }
          }
        } else {
          if (!item.containsKey('id')) item['id'] = _generateId('ATT');
          await _dbHelper.insert('driver_attendance', item);
        }
      } catch (e) {
        debugPrint('Error marking attendance: $e');
      }
    }

    _driverAttendance = List.from(await _dbHelper.query('driver_attendance'));
    for (var dId in affectedDriverIds) {
        await syncDriverBalanceById(dId);
    }
    notifyListeners();
  }

  Future<void> deleteDriver(String id) async {
    final index = _drivers.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _drivers[index];
      await _dbHelper.delete('drivers', 'id', id);
      _drivers.removeAt(index);
      
      // Sync Balances
      await _syncBalances(oldData, null);
      notifyListeners();
    }
  }
  
  Future<Map<String, List<Map<String, dynamic>>>> getDriverLedgerCategorized(String driverId) async {
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> allWorkEntries = [];
    List<Map<String, dynamic>> unpaidList = [];

    // 1. Get Driver Info
    final driver = _drivers.firstWhere((d) => d['id'].toString() == driverId.toString(), orElse: () => {});
    if (driver.isEmpty) return {'paid': [], 'unpaid': [], 'work': []};

    // 2. Fetch All Earnings (Work & Attendance Entries)
    
    // A. Attendance Earnings & Status
    final attendanceResult = await _dbHelper.query('driver_attendance', where: 'driver_id = ?', whereArgs: [driverId]);
    for (var row in attendanceResult) {
       double amt = parseAmount(row['earnings']);
       String status = row['status']?.toString() ?? 'Present';
       allWorkEntries.add({
          'id': row['id'],
          'date': row['date'],
          'title': status == 'Present' ? 'Present' : 'Absent',
          'status': status,
          'description': status == 'Present' ? 'Attendance (Present)' : 'Attendance (Absent)',
          'amount': '₹${amt.toInt()}',
          'amount_raw': amt,
          'type': 'Attendance',
          'mode': '-',
       });
    }

    // B. Manual Work Entries and Payments from Payments Table
    final allPayments = await _dbHelper.query('driver_payments', where: 'driver_id = ?', whereArgs: [driverId]);
    for (var row in allPayments) {
       final type = row['type']?.toString() ?? 'Payment';
       if (type == 'Work') {
          final salaryCreditItem = {
             'id': row['id'],
             'date': row['date'],
             'title': 'Monthly Salary Credit',
             'status': 'Salary',
             'description': 'Salary Credit',
             'amount': row['amount'],
             'amount_raw': parseAmount(row['amount']),
             'type': 'Work',
             'mode': 'Monthly Credit',
          };
          allWorkEntries.add(salaryCreditItem);
          // Note: salaryCreditItem is Work/Earnings, so it is added to allWorkEntries only, not paidList
       } else {
          String modeVal = (row['mode'] != null && row['mode'].toString().trim().isNotEmpty) 
              ? row['mode'].toString().trim() 
              : 'Cash';
          if (modeVal == 'Advance Box Given') modeVal = 'Give Advance';
          paidList.add({
             'id': row['id'],
             'amount': row['amount'],
             'date': row['date'],
             'title': 'Payment Paid',
             'status': 'Paid',
             'mode': modeVal,
             'description': 'Mode: $modeVal',
             'type': 'Payment',
          });
       }
     }

    // C. Vehicle Trip Work Logs Assigned to Driver
    final driverName = (driver['name'] ?? '').toString().trim();
    if (driverName.isNotEmpty) {
      final matchingVehicleWork = _vehicles.where((v) {
        final dName = (v['driver'] ?? '').toString().trim();
        return dName.toLowerCase() == driverName.toLowerCase() || dName.toLowerCase() == driverId.toString().toLowerCase();
      }).toList();

      for (var v in matchingVehicleWork) {
        double rAmt = parseAmount(v['rent_amount']);
        double bAmt = parseAmount(v['batta'] ?? v['batta_amount']);
        double totalAmt = parseAmount(v['total']);
        if (totalAmt <= 0) totalAmt = rAmt + bAmt;

        String vNo = v['number'] ?? 'Vehicle';
        String vType = v['type'] ?? '';
        String titleStr = vType.isNotEmpty ? '$vNo ($vType)' : vNo;
        
        String custName = (v['customer'] ?? '').toString().trim();
        String siteName = (v['site'] ?? '').toString().trim();

        // Infer Customer Address if site is General or empty
        if (siteName.isEmpty || siteName.toLowerCase() == 'general') {
          if (custName.isNotEmpty) {
            try {
              final custObj = _customers.firstWhere(
                (c) => (c['name'] ?? '').toString().toLowerCase().trim() == custName.toLowerCase(),
                orElse: () => {},
              );
              if (custObj.isNotEmpty && custObj['address'] != null && custObj['address'].toString().trim().isNotEmpty) {
                siteName = custObj['address'].toString().trim();
              }
            } catch (_) {}
          }
        }
        if (siteName.isEmpty) siteName = 'General';

        String desc = 'Site: $siteName';
        if (custName.isNotEmpty) {
          desc += ' • Customer: $custName';
        }
        if (bAmt > 0) {
          desc += ' • Batta: ₹${bAmt.toInt()}';
        }

        allWorkEntries.add({
          'id': 'V-LOG-${v['id']}',
          'date': v['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          'title': titleStr,
          'status': 'Vehicle Duty',
          'description': desc,
          'amount': '₹${totalAmt.toInt()}',
          'amount_raw': totalAmt,
          'type': 'VehicleWork',
          'mode': '-',
        });
      }
    }

    // 3. Sort Work Entries by Date (Oldest First) for FIFO balance calculations
    allWorkEntries.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        return da.compareTo(db);
      } catch (_) { return 0; }
    });

    double totalMoneyPaid = paidList.fold(0.0, (sum, p) => sum + parseAmount(p['amount']));
    double runningPaid = totalMoneyPaid;

    for (var work in allWorkEntries) {
        double amount = work['amount_raw'] ?? 0.0;
        if (runningPaid >= amount) {
           runningPaid -= amount;
        } else if (runningPaid > 0) {
           double pending = amount - runningPaid;
           unpaidList.add({ ...work, 'amount': '₹${pending.toInt()}', 'raw_balance': pending });
           runningPaid = 0;
        } else {
           unpaidList.add({ ...work, 'amount': '₹${amount.toInt()}', 'raw_balance': amount });
        }
    }

    _sortByDateDesc(paidList);
    _sortByDateDesc(allWorkEntries);
    _sortByDateDesc(unpaidList);

    return {
      'paid': paidList, 
      'work': allWorkEntries, 
      'unpaid': unpaidList 
    };
  }
  
  // INCOME
  Future<void> addIncome(Map<String, dynamic> inputData) async {
    final data = Map<String, dynamic>.from(inputData);
    if (!data.containsKey('id')) data['id'] = _generateId('INC');
    
    final dbData = {...data};
    if (dbData['isProfit'] is bool) dbData['isProfit'] = dbData['isProfit'] ? 1 : 0;
    if (!dbData.containsKey('status')) dbData['status'] = 'Active'; 
    if (!dbData.containsKey('estimate')) dbData['estimate'] = dbData['received'] ?? '₹0';
    
    await _dbHelper.insert('site_income', dbData);
    
    double recv = parseAmount(data['received']);
    if (recv > 0) {
      final payment = {
        'id': _generateId('PAY-INC'),
        'income_id': data['id'],
        'amount': '₹${recv.toStringAsFixed(0)}',
        'date': data['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      };
      await _dbHelper.insert('income_payments', payment);
      _incomePayments.add(payment); // Fix: Update local list
    }

    data['status'] = dbData['status'];
    _siteIncome.insert(0, data);
    await _syncBalances(null, data);
    notifyListeners();
  }
  
  Future<void> updateIncome(String id, Map<String, dynamic> newData) async {
    final index = _siteIncome.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _siteIncome[index];
      final updated = {...oldData, ...newData};
      
      final dbData = {...updated};
      if (dbData['isProfit'] is bool) dbData['isProfit'] = dbData['isProfit'] ? 1 : 0;
      if (!dbData.containsKey('estimate')) dbData['estimate'] = dbData['received'] ?? '₹0';

      await _dbHelper.update('site_income', dbData, 'id', id);
      
      double newRecv = parseAmount(updated['received']);
      double oldRecv = parseAmount(oldData['received']);
      double diff = newRecv - oldRecv;
      
      if (diff > 0) {
        final payment = {
          'id': _generateId('PAY-INC'),
          'income_id': id,
          'amount': '₹${diff.toStringAsFixed(0)}',
          'date': newData['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
        };
        await _dbHelper.insert('income_payments', payment);
        _incomePayments.add(payment);
      } else if (diff < 0) {
        // Fix for Problem 1: Handle decreased income
        if (newRecv == 0) {
          await _dbHelper.delete('income_payments', 'income_id', id);
          _incomePayments.removeWhere((p) => p['income_id'] == id);
        } else {
          // Simplest sync: reset payments to match the single new total
          await _dbHelper.delete('income_payments', 'income_id', id);
          _incomePayments.removeWhere((p) => p['income_id'] == id);
          final payment = {
            'id': _generateId('PAY-INC'),
            'income_id': id,
            'amount': '₹${newRecv.toStringAsFixed(0)}',
            'date': updated['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          };
          await _dbHelper.insert('income_payments', payment);
          _incomePayments.add(payment);
        }
      }

      _siteIncome[index] = updated;
      await _syncBalances(oldData, updated);
      notifyListeners();
    }
  }
  
  Future<List<Map<String, dynamic>>> getIncomePayments(String id) async {
    return await _dbHelper.query('income_payments', where: 'income_id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getSiteLedger(String siteName) async {
    final categorized = await getSiteLedgerCategorized(siteName);
    List<Map<String, dynamic>> all = [...categorized['paid']!, ...categorized['unpaid']!];
    // Sort all by date
     all.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        return db.compareTo(da);
      } catch (_) { return 0; }
    });
    return all;
  }

  Future<List<Map<String, dynamic>>> getExpensePayments(String id) async {
    return await _dbHelper.query('site_expense_payments', where: 'expense_id = ?', whereArgs: [id]);
  }

  Future<void> deleteExpenseSubPayment(String subPaymentId) async {
    final sub = _siteExpensePayments.firstWhere((p) => p['id'].toString() == subPaymentId.toString(), orElse: () => {});
    await _dbHelper.delete('site_expense_payments', 'id', subPaymentId);
    _siteExpensePayments.removeWhere((p) => p['id'].toString() == subPaymentId.toString());
    if (sub.isNotEmpty) {
      final expId = sub['expense_id'];
      final exp = _siteExpenses.firstWhere((e) => e['id'].toString() == expId.toString(), orElse: () => {});
      final supName = exp['supplier'] ?? exp['supplier_name'];
      if (supName != null && supName.toString().isNotEmpty) {
        await syncSupplierBalanceByName(supName.toString());
      }
    }
    notifyListeners();
  }

  Future<void> updateExpenseSubPayment(String subPaymentId, Map<String, dynamic> updated) async {
    await _dbHelper.update('site_expense_payments', updated, 'id', subPaymentId);
    final idx = _siteExpensePayments.indexWhere((p) => p['id'].toString() == subPaymentId.toString());
    if (idx != -1) {
      _siteExpensePayments[idx] = {..._siteExpensePayments[idx], ...updated};
      final expId = _siteExpensePayments[idx]['expense_id'];
      final exp = _siteExpenses.firstWhere((e) => e['id'].toString() == expId.toString(), orElse: () => {});
      final supName = exp['supplier'] ?? exp['supplier_name'];
      if (supName != null && supName.toString().isNotEmpty) {
        await syncSupplierBalanceByName(supName.toString());
      }
    }
    notifyListeners();
  }


  Future<void> addExpensePayment(String expenseId, Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('EXPP');
    data['expense_id'] = expenseId;
    await _dbHelper.insert('site_expense_payments', data);
    _siteExpensePayments.add(data);
    
    // Update the parent expense
    final expenseIndex = _siteExpenses.indexWhere((e) => e['id'] == expenseId);
    if (expenseIndex != -1) {
      final expense = _siteExpenses[expenseIndex];
      double addAmt = parseAmount(data['amount']);
      double currentPaid = parseAmount(expense['paid']);
      double newPaid = currentPaid + addAmt;
      
      // updateExpense handles the list update and triggers _syncBalances
      await updateExpense(expenseId, {'paid': '₹${newPaid.toInt()}'}, skipPaymentSync: true);

    }
    notifyListeners();
  }

  Future<Map<String, List<Map<String, dynamic>>>> getSiteLedgerCategorized(String siteName) async {
    final income = _siteIncome.firstWhere((i) => i['site'] == siteName, orElse: () => {});
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> unpaidList = [];

    // 1. Income
    if (income.isNotEmpty) {
      // Paid Income (Receipts)
      final payments = await getIncomePayments(income['id']);
      for (var p in payments) {
        paidList.add({
          'amount': p['amount'],
          'date': p['date'],
          'billDate': income['date'] ?? p['date'],
          'type': 'Income',
          'description': 'Receipt Received',
        });
      }

      // Unpaid Income (Pending from Client)
      double pending = parseAmount(income['pending']);
      if (pending > 0) {
        unpaidList.add({
          'id': income['id'],
          'amount': '₹${pending.toInt()}',
          'date': income['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
          'type': 'Income',
          'description': 'Site Outstanding Balance',
        });
      }
    }

    final expenses = _siteExpenses.where((e) => e['site'] == siteName && !_isDuplicateExpense(e)).toList();
    final siteVehicles = _vehicles.where((v) => v['site'] == siteName).toList();

    // 4. Collect unique suppliers to fetch FIFO unpaid statuses
    final Set<String> relevantSuppliers = {};
    for (var e in expenses) {
      if (e['supplier'] != null && e['supplier'].toString().trim().isNotEmpty) {
        relevantSuppliers.add(e['supplier'].toString().trim());
      }
    }
    for (var v in siteVehicles) {
      if (v['supplier'] != null && v['supplier'].toString().trim().isNotEmpty) {
        relevantSuppliers.add(v['supplier'].toString().trim());
      }
    }

    final Map<String, Set<String>> unpaidMap = {};
    for (var s in relevantSuppliers) {
      unpaidMap[s] = await getSupplierUnpaidIds(s);
    }

    // 2. Expenses (site_expenses)
    for (var e in expenses) {
      final String? supplier = e['supplier']?.toString().trim();
      bool isPaidInLedger = parseAmount(e['paid']) >= parseAmount(e['amount']) || e['status'] == StatusType.paid;

      double total = parseAmount(e['amount']);
      double paid = parseAmount(e['paid']);
      double balance = total - paid;

      bool isSupplierPaid = false;
      if (supplier != null && supplier.isNotEmpty && unpaidMap.containsKey(supplier)) {
        isSupplierPaid = !unpaidMap[supplier]!.contains(e['id'].toString());
      } else {
        // Fallback for No Supplier: Follow Client Payment status (paid >= total)
        isSupplierPaid = parseAmount(e['paid']) >= parseAmount(e['amount']) || e['status'] == StatusType.paid;
      }

      // Site Ledger tab movement now follows the Expense settlement status
      if (!isSupplierPaid) {
        unpaidList.add({
          ...e,
          'id': e['id'],
          'amount': '₹${balance.toInt()}',
          'date': e['date'],
          'type': 'Expense',
          'isSupplierPaid': isSupplierPaid,
          'description': '${e['category']}: ${e['title']}',
        });
      }

      // Paid Tab (Show historical payments or settled entries)
      final pRecords = await getExpensePayments(e['id']);
      if (isSupplierPaid) {
         paidList.add({
            ...e,
            'amount': '₹${total.toInt()}',
            'date': e['date'],
            'billDate': e['date'],
            'type': 'Expense',
            'isSupplierPaid': true,
            'description': '${e['category']}: ${e['title']}',
         });
      } else {
        for (var p in pRecords) {
          paidList.add({
            'amount': p['amount'],
            'date': p['date'],
            'billDate': e['date'],
            'type': 'Expense',
            'description': '${e['category']}: ${e['title']} (Partial Pay)',
          });
        }
      }
    }

    // 3. Vehicles (Expenses for this Site)
    for (var v in siteVehicles) {
       final String? supplier = v['supplier']?.toString().trim();
       final bool isOwn = v['isOwn'] == true || v['isOwn'] == 1;
       bool isPaidInLedger = parseAmount(v['paid']) >= parseAmount(v['total']) || v['status'] == StatusType.paid;

       final bool isRentedOut = v['isRentedOut'] == true || v['isRentedOut'] == 1;
       final bool isEntryIncome = isOwn && isRentedOut;

       double total = parseAmount(v['total']);
       double paid = parseAmount(v['paid']);
       double balance = total - paid;
       
       bool isSupplierPaid = false;
       if (supplier != null && supplier.isNotEmpty && unpaidMap.containsKey(supplier)) {
         isSupplierPaid = !unpaidMap[supplier]!.contains(v['id'].toString());
       } else {
         // Own Vehicle or No Supplier: Follow Client Payment status
         isSupplierPaid = parseAmount(v['paid']) >= parseAmount(v['total']) || v['status'] == StatusType.paid;
       }

       if (!isSupplierPaid) {
          unpaidList.add({
            ...v,
            'id': v['id'],
            'amount': '₹${balance.toInt()}',
            'date': v['date'],
            'type': isEntryIncome ? 'Income' : 'Vehicle',
            'isSupplierPaid': isSupplierPaid,
            'description': '${v['number']} (${v['type']})',
          });
       }

       final pRecords = await _dbHelper.query('vehicle_payments', where: 'vehicle_id = ?', whereArgs: [v['id']]);
       if (isSupplierPaid) {
          paidList.add({
            ...v,
            'amount': '₹${total.toInt()}',
            'date': v['date'],
            'billDate': v['date'],
            'type': isEntryIncome ? 'Income' : 'Vehicle',
            'isSupplierPaid': true,
            'description': '${v['number']} (${v['type']})',
          });
       } else {
          for (var p in pRecords) {
            paidList.add({
              'amount': p['amount'],
              'date': p['date'],
              'billDate': v['date'],
              'type': isEntryIncome ? 'Income' : 'Vehicle',
              'description': '${v['number']} (${v['type']}) (Partial)',
            });
          }
       }
    }

    // 4. Labour Records (Advances for this Site)
    final siteLabour = _labour.where((l) => l['site'] == siteName).toList();
    for (var l in siteLabour) {
       double advance = parseAmount(l['advance']);
       double balance = parseAmount(l['balance']);
       
       if (advance > 0) {
          paidList.add({
            'amount': '₹${advance.toInt()}',
            'date': l['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
            'billDate': l['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
            'type': 'Labour',
            'description': 'Labour Advance: ${l['name']}',
          });
       }
       if (balance > 0) {
          unpaidList.add({
            'id': l['id'],
            'amount': '₹${balance.toInt()}',
            'date': l['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
            'type': 'Labour',
            'description': 'Labour Owed: ${l['name']}',
          });
       }
    }

    _sortByDateDesc(paidList);
    _sortByDateDesc(unpaidList);

    return {'paid': paidList, 'unpaid': unpaidList};
  }


  Future<List<Map<String, dynamic>>> getSupplierBills(String supplierName) async {
    List<Map<String, dynamic>> allBills = [];

    // Group A: Categorical Expenses
    final expenses = await getSupplierExpenses(supplierName);
    for (var e in expenses) {
      allBills.add({
         ...e,
         'bill_amount': parseAmount(e['amount']),
         'source_type': 'Expense',
         'description': '${e['title'] ?? e['category'] ?? 'Fuel'}',
      });
    }

    // Group B: Vehicle Materials (Fuel/Cement/etc.)
    final vehicleEntries = _vehicles.where((v) => v['supplier']?.toString().toLowerCase().trim() == supplierName.toLowerCase().trim()).toList();
    for (var v in vehicleEntries) {
        double buyCost = (double.tryParse(v['quantity']?.toString() ?? '0') ?? 0) * (double.tryParse(v['buy_price']?.toString() ?? '0') ?? 0);
        if (buyCost <= 0) buyCost = parseAmount(v['material_amount']);
        if (buyCost <= 0) continue;

        allBills.add({
           ...v,
           'bill_amount': buyCost,
           'source_type': 'Vehicle',
           'description': '${v['material_name'] ?? 'Fuel'} - ${v['number']}',
        });
    }

    allBills.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        return db.compareTo(da); // Descending
      } catch (_) { return 0; }
    });
    
    return allBills;
  }

  Future<Map<String, List<Map<String, dynamic>>>> getBunkLedgerCategorized(String supplierName) async {
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> unpaidList = [];

    final supplier = _suppliers.firstWhere(
      (s) => s['name'].toString().toLowerCase().trim() == supplierName.toLowerCase().trim(), 
      orElse: () => {}
    );
    
    List<Map<String, dynamic>> ledgerPayments = await getSupplierPayments(supplier['id']);
    double totalMoneyPaid = await _getTotalSupplierPayments(supplier['id'], supplierName);

    // 2. Gather All Potential Bills (Expenses + Vehicle Materials)
    List<Map<String, dynamic>> allBills = [];

    // Group A: Categorical Expenses
    final expenses = await getSupplierExpenses(supplierName);
    for (var e in expenses) {
      final String vNo = (e['vehicle_no'] ?? '').toString().trim();
      final String vDisplay = getVehicleDisplayName(vNo);

      String vehicleDesc = vDisplay.isNotEmpty ? vDisplay : (vNo.isNotEmpty ? vNo : '');
      final titleStr = (e['title'] ?? '').toString();
      if (titleStr.contains('Bulk Diesel Storage Tank Purchase') || titleStr.toLowerCase().contains('storage tank') || (e['notes'] ?? '').toString().toLowerCase().contains('storage tank')) {
        vehicleDesc = 'Storage Tank';
      }
      if (vehicleDesc.isEmpty) {
        vehicleDesc = e['category'] ?? 'Fuel';
      }

      String userNotes = (e['notes'] ?? e['description'] ?? '').toString().trim();
      if (userNotes.toLowerCase() == vehicleDesc.toLowerCase()) {
        userNotes = '';
      }

      allBills.add({
         ...e,
         'bill_amount': parseAmount(e['amount']),
         'source_type': 'Expense',
         'vehicle_no': vNo.isNotEmpty ? vNo : (e['vehicle_no'] ?? ''),
         'vehicle_display': vehicleDesc,
         'title': 'Fuel: $vehicleDesc',
         'description': userNotes.isNotEmpty ? userNotes : vehicleDesc,
         'user_description': userNotes,
      });
    }

    // Group B: Vehicle Materials (Fuel/Cement/etc.)
    final vehicleEntries = _vehicles.where((v) => v['supplier']?.toString().toLowerCase().trim() == supplierName.toLowerCase().trim()).toList();
    for (var v in vehicleEntries) {
        double buyCost = (double.tryParse(v['quantity']?.toString() ?? '0') ?? 0) * (double.tryParse(v['buy_price']?.toString() ?? '0') ?? 0);
        if (buyCost <= 0) buyCost = parseAmount(v['material_amount']);
        if (buyCost <= 0) continue;

        final String vNo = (v['number'] ?? '').toString().trim();
        final String vDisplay = getVehicleDisplayName(vNo);
        final String matName = v['material_name'] ?? 'Fuel';
        String userNotes = (v['description'] ?? v['notes'] ?? '').toString().trim();

        allBills.add({
           ...v,
           'bill_amount': buyCost,
           'source_type': 'Vehicle',
           'vehicle_no': vNo,
           'vehicle_display': vDisplay.isNotEmpty ? vDisplay : vNo,
           'title': '$matName: ${vDisplay.isNotEmpty ? vDisplay : vNo}',
           'description': userNotes.isNotEmpty ? userNotes : matName,
           'user_description': userNotes,
        });
    }

    // 3. Sort Bills by Date (Oldest First) for Running Balance Calculation
    allBills.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        int cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        // Secondary Sort: ID (Timestamp based) to ensure stable FIFO for same-day entries
        return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
      } catch (_) { return 0; }
    });

    // 4. Categorize Bills based on Total Ledger Payments (FIFO approach)
    double runningPaid = totalMoneyPaid;

    for (var bill in allBills) {
        double amount = bill['bill_amount'];
        
        if (runningPaid >= amount) {
           // Fully PAID by money we actually sent to the supplier
           runningPaid -= amount;
        } else if (runningPaid > 0) {
           // Partially Paid
           double pending = amount - runningPaid;
            unpaidList.add({
               'id': bill['id'],
               'amount': '₹${pending.toInt()}',
               'date': bill['date'],
               'title': bill['description'],
               'vehicle_no': bill['number'] ?? '',
               'type': bill['source_type'],
               'description': '${bill['description']} (Partial)',
               'quantity': bill['quantity'],
               'unit': bill['unit'],
               'material_name': bill['material_name'],
            });
            runningPaid = 0;
         } else {
            // Fully UNPAID
            unpaidList.add({
               'id': bill['id'],
               'amount': '₹${amount.toInt()}',
               'date': bill['date'],
               'title': bill['description'],
               'vehicle_no': bill['number'] ?? '',
               'type': bill['source_type'],
               'description': bill['description'],
               'quantity': bill['quantity'],
               'unit': bill['unit'],
               'material_name': bill['material_name'],
            });
         }
      }

    // 5. Build Paid Tab (Historical History)
    // A. Direct Ledger Payments (Bulk settlements)
    for (var p in ledgerPayments) {
        final bool isDisc = (p['type'] ?? '').toString() == 'Discount' || (p['notes'] ?? '').toString().toLowerCase().contains('discount');
        paidList.add({
          'id': p['id'],
          'amount': p['amount'],
          'date': p['date'],
          'title': isDisc ? 'Discount Received' : 'Payment Made',
          'type': isDisc ? 'Discount' : 'Payment',
          'sub_type': 'supplier_payment',
          'description': p['notes'] ?? (isDisc ? 'Discount Allowed' : 'Ledger Settlement'),
        });
    }


    // B. Site Expense Payments (Individual bill payments)
    for (var e in expenses) {
      final subPayments = await getExpensePayments(e['id']);
      if (subPayments.isEmpty && parseAmount(e['paid']) > 0) {
        paidList.add({
          'id': e['id'],
          'amount': e['paid'],
          'date': e['date'],
          'type': 'Expense Payment',
          'sub_type': 'initial_paid',
          'description': 'For: ${e['title']}',
        });
      } else {
        for (var sp in subPayments) {
          paidList.add({
            'id': sp['id'],
            'amount': sp['amount'],
            'date': sp['date'],
            'type': 'Expense Payment',
            'sub_type': 'sub_payment',
            'description': 'For: ${e['title']}',
          });
        }
      }
    }


    // C. Vehicle Payments (Individual trip payments) - REMOVED PER USER REQUEST
    // These are Customer->Owner payments, NOT Owner->Supplier payments.
    // Showing them here confuses the user as "Supplier Payments".
    // Only direct 'ledgerPayments' or specific 'expense bills' payments should be shown.



    _sortByDateDesc(paidList);
    _sortByDateDesc(unpaidList);

    return {
       'paid': paidList, 
       'unpaid': unpaidList,
       'all_bills': allBills,
       'actual_payments': ledgerPayments,
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> getMechanicLedgerCategorized(String supplierName) async {
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> unpaidList = [];

    // 1. Get All Actual Payments for this Mechanic (Supplier)
    final supplier = _suppliers.firstWhere(
      (s) => s['name'].toString().toLowerCase().trim() == supplierName.toLowerCase().trim(), 
      orElse: () => {}
    );
    
    List<Map<String, dynamic>> ledgerPayments = await getSupplierPayments(supplier['id']);
    double totalMoneyPaid = await _getTotalSupplierPayments(supplier['id'], supplierName);

    // 2. Gather All Potential Bills
    List<Map<String, dynamic>> allBills = [];

    // Group A: Categorical Expenses (Maintenance)
    final expenses = await getSupplierExpenses(supplierName);
    for (var e in expenses) {
      final String vNo = (e['vehicle_no'] ?? '').toString().trim();
      final String vDisplay = getVehicleDisplayName(vNo);
      String desc = vDisplay.isNotEmpty ? vDisplay : (e['title'] ?? e['category'] ?? 'Maintenance');

      allBills.add({
         ...e,
         'bill_amount': parseAmount(e['amount']),
         'source_type': 'Expense',
         'vehicle_no': vNo.isNotEmpty ? vNo : (e['vehicle_no'] ?? ''),
         'vehicle_display': desc,
         'title': 'Maintenance: $desc',
         'description': desc,
      });
    }

    // Group B: Vehicle Maintenance (Parts/Service)
    final vehicleEntries = _vehicles.where((v) => v['supplier']?.toString().toLowerCase().trim() == supplierName.toLowerCase().trim()).toList();
    for (var v in vehicleEntries) {
        // STRICT LOGIC: Supplier Bill = Buy Price * Quantity
        double qty = double.tryParse(v['quantity']?.toString() ?? '0') ?? 0;
        double buyPrice = double.tryParse(v['buy_price']?.toString() ?? '0') ?? 0;
        
        double buyCost = 0;
        if (qty > 0 && buyPrice > 0) {
           buyCost = qty * buyPrice;
        } else {
           bool isOwn = v['isOwn'] == true || v['isOwn'] == 1;
           if (!isOwn) {
              buyCost = parseAmount(v['material_amount']);
           }
        }

        if (buyCost <= 0) continue;

        final String vNo = (v['number'] ?? '').toString().trim();
        final String vDisplay = getVehicleDisplayName(vNo);
        final String matName = v['material_name'] ?? 'Maintenance';

        allBills.add({
           ...v,
           'bill_amount': buyCost,
           'source_type': 'Vehicle',
           'vehicle_no': vNo,
           'vehicle_display': vDisplay.isNotEmpty ? vDisplay : vNo,
           'title': '$matName: ${vDisplay.isNotEmpty ? vDisplay : vNo}',
           'description': '$matName - ${vDisplay.isNotEmpty ? vDisplay : vNo}',
        });
    }

    // 3. Sort Bills by Date (Oldest First)
    allBills.sort((a, b) {
      try {
        DateTime da = DateFormat('dd MMM yyyy').parse(a['date']);
        DateTime db = DateFormat('dd MMM yyyy').parse(b['date']);
        int cmp = da.compareTo(db);
        if (cmp != 0) return cmp;
        // Secondary Sort: ID (Timestamp based) to ensure stable FIFO for same-day entries
        return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
      } catch (_) { return 0; }
    });

    // 4. Categorize Bills based on Total Ledger Payments (FIFO)
    double runningPaid = totalMoneyPaid;

    for (var bill in allBills) {
        double amount = bill['bill_amount'];
        
        if (runningPaid >= amount) {
           runningPaid -= amount;
        } else if (runningPaid > 0) {
           double pending = amount - runningPaid;
            unpaidList.add({
               'id': bill['id'],
               'amount': '₹${pending.toInt()}',
               'date': bill['date'],
               'title': bill['description'],
               'vehicle_no': bill['number'] ?? '',
               'type': bill['source_type'],
               'description': '${bill['description']} (Partial)',
               'quantity': bill['quantity'],
               'unit': bill['unit'],
               'material_name': bill['material_name'],
            });
            runningPaid = 0;
         } else {
            unpaidList.add({
               'id': bill['id'],
               'amount': '₹${amount.toInt()}',
               'date': bill['date'],
               'title': bill['description'],
               'vehicle_no': bill['number'] ?? '',
               'type': bill['source_type'],
               'description': bill['description'],
               'quantity': bill['quantity'],
               'unit': bill['unit'],
               'material_name': bill['material_name'],
            });
         }
      }

    // 5. Build Paid Tab (Historical History)
    // A. Direct Ledger Payments (Bulk settlements)
    for (var p in ledgerPayments) {
        final bool isDisc = (p['type'] ?? '').toString() == 'Discount' || (p['notes'] ?? '').toString().toLowerCase().contains('discount');
        paidList.add({
          'id': p['id'],
          'amount': p['amount'],
          'date': p['date'],
          'title': isDisc ? 'Discount Received' : 'Payment Made',
          'type': isDisc ? 'Discount' : 'Payment',
          'sub_type': 'supplier_payment',
          'description': p['notes'] ?? (isDisc ? 'Discount Allowed' : 'Ledger Settlement'),
        });
    }

    // B. Site Expense Payments (Individual bill payments)
    for (var e in expenses) {
      final subPayments = await getExpensePayments(e['id']);
      if (subPayments.isEmpty && parseAmount(e['paid']) > 0) {
        paidList.add({
          'amount': e['paid'],
          'date': e['date'],
          'type': 'Expense Payment',
          'description': 'Initial Payment: ${e['title']}',
        });
      } else {
        for (var sp in subPayments) {
          paidList.add({
            'amount': sp['amount'],
            'date': sp['date'],
            'type': 'Expense Payment',
            'description': 'For: ${e['title']}',
          });
        }
      }
    }


    // C. Vehicle Payments (Individual trip payments) - REMOVED PER USER REQUEST



    _sortByDateDesc(paidList);
    _sortByDateDesc(unpaidList);

    return {
       'paid': paidList, 
       'unpaid': unpaidList,
       'all_bills': allBills,
       'actual_payments': ledgerPayments,
    };
  }

  Future<Set<String>> getSupplierUnpaidIds(String supplierName) async {
    final supplier = _suppliers.firstWhere(
      (s) => s['name'].toString().toLowerCase().trim() == supplierName.toLowerCase().trim(), 
      orElse: () => {}
    );
    if (supplier.isEmpty) return {};

    final material = (supplier['material'] ?? '').toString().toLowerCase();
    Map<String, List<Map<String, dynamic>>> ledger;
    
    if (material.contains('mechanic') || material.contains('workshop') || material.contains('garage')) {
      ledger = await getMechanicLedgerCategorized(supplierName);
    } else {
      ledger = await getBunkLedgerCategorized(supplierName);
    }

    final Set<String> unpaidIds = {};
    for (var item in ledger['unpaid']!) {
       if (item['id'] != null) unpaidIds.add(item['id'].toString());
    }
    return unpaidIds;
  }
  Future<Map<String, List<Map<String, dynamic>>>> getCustomerLedgerCategorized(String customerName) async {
    List<Map<String, dynamic>> allBills = [];
    List<Map<String, dynamic>> allPayments = [];
    List<Map<String, dynamic>> unpaidList = [];

    // 1. Filter vehicles for this customer (Case-Insensitive & Trimmed)
    final customerVehicles = _vehicles.where((v) => 
      v['customer']?.toString().toLowerCase().trim() == customerName.toLowerCase().trim()
    ).toList();

    for (var v in customerVehicles) {
      double rAmt = parseAmount(v['rent_amount']);
      double bAmt = parseAmount(v['batta'] ?? v['batta_amount']);
      double mAmt = parseAmount(v['material_amount']);
      double total = parseAmount(v['total']);
      if (total <= 0) {
        total = rAmt + bAmt + mAmt;
      }
      
      double paid = parseAmount(v['paid']);
      double balance = total - paid;
      bool isFullyPaid = balance <= 0 || v['status'] == StatusType.paid;
      
      final entry = {
        'id': v['id'],
        'date': v['date'],
        'title': '${v['type'] ?? 'Vehicle'} - ${v['number']}',
        'description': '${v['duration'] ?? '0'} ${v['rate_type'] ?? 'Day'} @ ${v['rate'] ?? '0'}',
        'bill_amount': total,   
        'paid': paid,      
        'balance': balance, 
        'raw_balance': balance,
        'vehicle_no': v['number'],
        'number': v['number'],
        'total': '₹${total.toInt()}',
        'paid': '₹${paid.toInt()}',
        'type': v['type'],
        'source': 'Vehicle',
        'quantity': v['quantity'],
        'unit': v['unit'],
        'rate': v['rate'],
        'duration': v['duration'],
        'rate_type': v['rate_type'],
        'material_name': v['material_name'],
        'material_amount': v['material_amount'],
        'batta': v['batta'],
        'batta_amount': v['batta_amount'],
        'bill_no': v['bill_no'],
        'rent_amount': v['rent_amount'],
        'manual_desc': v['manual_desc'],
        'site': v['site'],
        'customer': v['customer'],
        'isOwn': v['isOwn'],
        'isRentedOut': v['isRentedOut'],
        'supplier': v['supplier'],
        'unit_price': v['unit_price'],
        'buy_price': v['buy_price'],
      };

      allBills.add(entry);
      if (!isFullyPaid) {
        unpaidList.add(entry);
      }
      
      // Add individual vehicle payments to allPayments
      final vPayments = await getVehiclePayments(v['id']);
      if (vPayments.isEmpty && paid > 0) {
          allPayments.add({
             'id': 'VPAI-${v['id']}',
             'amount': v['paid'],
             'date': v['date'],
             'title': 'Initial Payment',
             'description': 'Vehicle: ${v['number']}',
             'type': 'Payment',
          });
      } else {
          for (var p in vPayments) {
              allPayments.add({
                 'id': p['id'],
                 'amount': p['amount'],
                 'date': p['date'],
                 'title': 'Vehicle Payment',
                 'description': 'Vehicle: ${v['number']}',
                 'type': 'Payment',
              });
          }
      }
    }

    // 2. Identify all sites belonging to this client and add their categorical expenses
    // REMOVED PER USER REQUEST: "inga vechicle entry mattum tha irukanum"
    // The user ONLY wants Vehicle Entries in this Customer Ledger.
    // Site Expenses (Material/Labour etc) should NOT mix here unless they are part of a Vehicle Trip (which are already in customerVehicles).
    
    // final clientSites = ... (Removed)
    // final expenses = ... (Removed)
    // for (var e in expenses) ... (Removed)

    // 3. Include Site Income Contracts and Receipts
    final clientIncomes = _siteIncome.where((i) => i['client']?.toString().toLowerCase().trim() == customerName.toLowerCase().trim());
    for (var i in clientIncomes) {
       // A. THE CONTRACT/BILL
       double est = parseAmount(i['estimate']);
       if (est > 0) {
          final entry = {
            'id': 'EST-${i['id']}',
            'date': i['date'] ?? '',
            'title': 'Contract: ${i['site']}',
            'description': i['work_type'] ?? 'Site Work',
            'bill_amount': est,
            'paid': parseAmount(i['received']),
            'balance': est - parseAmount(i['received']),
            'type': 'Site',
            'source': 'Site',
          };
          allBills.add(entry);
          if (parseAmount(i['pending']) > 0) {
             unpaidList.add(entry);
          }
       }

       // B. THE PAYMENTS
       final payments = await getIncomePayments(i['id']);
       for (var p in payments) {
          allPayments.add({
            'id': p['id'],
            'amount': p['amount'],
            'date': p['date'],
            'title': 'Income Receipt',
            'description': 'Site: ${i['site']}',
            'type': 'Income',
          });
       }
    }

    // 4. Include Generic Customer Payments (Requirement 1.iii)
    final genericPayments = _customerPayments.where((cp) => cp['customer_name']?.toString().toLowerCase().trim() == customerName.toLowerCase().trim());
    for (var gp in genericPayments) {
       final bool isDisc = gp['type'] == 'Discount' || (gp['notes'] ?? '').toString().toLowerCase().contains('discount');
       allPayments.add({
         'id': gp['id'],
         'amount': gp['amount'],
         'date': gp['date'],
         'title': isDisc ? 'Discount Given' : 'Payment Received',
         'description': gp['notes'] ?? (isDisc ? 'Discount Given' : 'Generic Payment'),
         'type': isDisc ? 'Discount' : 'CustomerPayment',
       });
    }

    _sortByDateDesc(allPayments);
    _sortByDateDesc(unpaidList);
    _sortByDateDesc(allBills);

    return {
      'bills': allBills, 
      'unpaid': unpaidList,
      'payments': allPayments 
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> getLabourLedgerCategorized(String name) async {
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> unpaidList = [];

    // 1. Filter labour entries for this name
    final entries = _labour.where((l) => l['name']?.toString().toLowerCase().trim() == name.toLowerCase().trim()).toList();

    for (var l in entries) {
      double advance = parseAmount(l['advance']); // Paid
      double balance = parseAmount(l['balance']); // Pending
      double total = advance + balance;
      bool isFullyPaid = balance <= 0;

      final entry = {
        'id': l['id'],
        'date': l['date'] ?? '',
        'title': 'Work Entry',
        'description': l['site'] ?? 'General',
        'amount': '₹${total.toInt()}',
        'paid': '₹${advance.toInt()}',
        'balance': '₹${balance.toInt()}',
        'raw_balance': balance,
        'type': 'Labour',
        'isLabourEntry': true,
      };

      if (!isFullyPaid) {
        unpaidList.add(entry);
      }
      if (advance > 0 || isFullyPaid) {
        paidList.add(entry);
      }
    }

    // 2. Add individual payments from history as independent records in Paid tab
    // Actually our Mark as Paid adds payments here. 
    // But since Labour table is "Consolidated" (Total Owed vs Total Paid), 
    // the history is already reflected in the entries above if we treat them correctly.
    // However, to show a "Ledger", we should show specific payment dates.
    
    for (var l in entries) {
       final payments = await _dbHelper.query('labour_payments', where: 'labour_id = ?', whereArgs: [l['id']]);
       for (var p in payments) {
          paidList.add({
            'amount': p['amount'],
            'date': p['date'],
            'title': 'Payment Paid',
            'description': 'Ref ID: ${p['id']}',
            'type': 'Payment',
          });
       }
    }

    // 3. Add transactions from site_expenses (Category Labour)
    final siteExpenses = _siteExpenses.where((e) => 
      e['category'] == 'Labour' && e['title']?.toString().toLowerCase().trim() == name.toLowerCase().trim()
    );

    for (var e in siteExpenses) {
        double total = parseAmount(e['amount']);
        double paid = parseAmount(e['paid']);
        double balance = total - paid;
        bool isFullyPaid = balance <= 0 || e['status'] == StatusType.paid;

        final isSelectedDate = e['date'] == formattedSelectedDate;

        if (!isFullyPaid) {
          unpaidList.add({
              'id': e['id'],
              'date': e['date'] ?? '',
              'title': (e['material_name'] != null && e['material_name'].toString().isNotEmpty) ? e['material_name'] : 'Labour Work',
              'description': e['site'] ?? 'General',
              'amount': e['amount'] ?? '₹0',
              'paid': e['paid'] ?? '₹0',
              'balance': '₹${balance.toInt()}',
              'raw_balance': balance,
              'type': 'Expense',
          });
        }

        // Add to paid list if any payment made
        if (paid > 0) {
            paidList.add({
                'amount': e['paid'],
                'date': e['date'],
                'title': 'Partial Payment',
                'description': 'For Work on ${e['date']}',
                'type': 'Payment',
            });
        }
    }

    _sortByDateDesc(paidList);
    _sortByDateDesc(unpaidList);

    return {'paid': paidList, 'unpaid': unpaidList};
  }


  Future<Map<String, List<Map<String, dynamic>>>> getOtherLedgerCategorized(String title) async {
    List<Map<String, dynamic>> paidList = [];
    List<Map<String, dynamic>> unpaidList = [];

    // Filter site expenses for this specific title and 'Other' category
    final expenses = _siteExpenses.where((e) => 
      e['category'] == 'Other' && e['title']?.toString().toLowerCase().trim() == title.toLowerCase().trim()
    );

    for (var e in expenses) {
      double total = parseAmount(e['amount']);
      double paid = parseAmount(e['paid']);
      double balance = total - paid;
      bool isFullyPaid = balance <= 0 || e['status'] == StatusType.paid;

      final entry = {
        'id': e['id'],
        'date': e['date'] ?? '',
        'title': e['title'] ?? 'Other Expense',
        'description': e['site'] ?? 'General',
        'site': e['site'] ?? 'General', // Added
        'desc_text': e['material_name'] ?? '', // Added
        'amount': e['amount'] ?? '₹0',
        'paid': e['paid'] ?? '₹0',
        'balance': '₹${balance.toInt()}',
        'raw_balance': balance,
        'type': 'Expense',
      };

      if (!isFullyPaid) {
        unpaidList.add(entry);
      }
      if (paid > 0 || isFullyPaid) {
        paidList.add(entry);
      }
      
      // Also fetch payments for this specific expense
      final payments = await getExpensePayments(e['id']);
      for (var p in payments) {
          paidList.add({
            'amount': p['amount'],
            'date': p['date'],
            'title': 'Payment Made',
            'description': 'For: ${e['title']}',
            'site': e['site'] ?? 'General',
            'desc_text': '',
            'type': 'Payment',
          });
      }
    }

    _sortByDateDesc(paidList);
    _sortByDateDesc(unpaidList);

    return {'paid': paidList, 'unpaid': unpaidList};
  }

  Future<List<String>> getOtherUnpaidIds(String title) async {
     final result = await getOtherLedgerCategorized(title);
     return result['unpaid']!.map((e) => e['id'].toString()).toList();
  }


  
  Future<void> deleteIncome(String id) async {
    final index = _siteIncome.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final oldData = _siteIncome[index];
      await _dbHelper.delete('site_income', 'id', id);
      _siteIncome.removeAt(index);
      
      // Also delete all expenses related to this site name
      if (oldData['site'] != null) {
         await deleteSiteExpenses(oldData['site']);
      }
      
      // Recalculate relevant balances
      await _syncBalances(oldData, null);
      
      notifyListeners();
    }
  }

  // EXPENSES
  Future<List<Map<String, dynamic>>> getSupplierExpenses(String supplierName) async {
    final results = await _dbHelper.query('site_expenses', 
      where: 'LOWER(TRIM(supplier)) = LOWER(TRIM(?))', 
      whereArgs: [supplierName]);
    return results.where((e) => !_isDuplicateExpense(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getSupplierMaterials(String supplierId) async {
     return await _dbHelper.query('supplier_materials', where: 'supplier_id = ?', whereArgs: [supplierId]);
  }
  
  Future<void> addExpense(Map<String, dynamic> inputData) async {
    final data = Map<String, dynamic>.from(inputData);
    if (!data.containsKey('id')) data['id'] = _generateId('EXP');
    if (data['supplier'] != null) data['supplier'] = data['supplier'].toString().trim(); // Normalize

    // Auto-Infer Site for Vehicle Expenses
    if (data['category'] == 'Vehicle' && (data['site'] == null || data['site'].toString().isEmpty) && data['vehicle_no'] != null) {
       try {
         final activeVehicle = _vehicles.firstWhere(
            (v) => v['number'] == data['vehicle_no'] && (v['status'] == StatusType.active || v['status'] == 'Active'),
            orElse: () => _vehicles.firstWhere((v) => v['number'] == data['vehicle_no'], orElse: () => {})
         );
         
         if (activeVehicle.isNotEmpty && activeVehicle['site'] != null) {
            data['site'] = activeVehicle['site'];
         }
       } catch (e) {
         print('Error inferring site: $e');
       }
    }

    double total = parseAmount(data['amount']);
    double paid = parseAmount(data['paid']);
    StatusType status = StatusType.paid;
    if (paid < total && paid > 0) {
      status = StatusType.partial;
    } else if (paid <= 0 && total > 0) {
      status = StatusType.pending;
    }
    data['status'] = status;

    final dbData = {...data};
    dbData['status'] = status.toString();

    await _dbHelper.insert('site_expenses', dbData);
    
    if (paid > 0) {
      final payment = {
        'id': _generateId('PAREXP'),
        'expense_id': data['id'],
        'amount': '₹${paid.toInt()}',
        'date': data['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      };
      await _dbHelper.insert('site_expense_payments', payment);
      _siteExpensePayments.add(payment);
    }

    _siteExpenses.insert(0, data);
    await _syncBalances(null, data);
    notifyListeners();
  }
  
  Future<void> updateExpense(String id, Map<String, dynamic> newData, {bool skipPaymentSync = false}) async {
    final strId = id.toString().trim();
    final index = _siteExpenses.indexWhere((element) => element['id']?.toString().trim() == strId);
    if (index != -1) {
      final oldData = _siteExpenses[index];
      var merged = {...oldData, ...newData};

      // Auto-Infer Site if missing (Fix for existing sync issues)
      if (merged['category'] == 'Vehicle' && (merged['site'] == null || merged['site'].toString().isEmpty) && merged['vehicle_no'] != null) {
         try {
           final activeVehicle = _vehicles.firstWhere(
              (v) => v['number'] == merged['vehicle_no'] && (v['status'] == StatusType.active || v['status'] == 'Active'),
              orElse: () => _vehicles.firstWhere((v) => v['number'] == merged['vehicle_no'], orElse: () => {})
           );
           if (activeVehicle.isNotEmpty && activeVehicle['site'] != null) {
              merged['site'] = activeVehicle['site'];
              newData['site'] = activeVehicle['site']; // Update input map too
           }
         } catch (_) {}
      }



      // Recalculate Status
      double total = parseAmount(merged['amount']);
      double paid = parseAmount(merged['paid']);
      StatusType status = StatusType.paid;
      if (paid < total && paid > 0) {
        status = StatusType.partial;
      } else if (paid <= 0 && total > 0) {
        status = StatusType.pending;
      }
      merged['status'] = status;

      final dbData = {...merged};
      dbData['status'] = status.toString();

      await _dbHelper.update('site_expenses', dbData, 'id', strId);
      _siteExpenses[index] = merged;

      // Sync Payment Logs if paid amount changed and not skipped
      double oldPaid = parseAmount(oldData['paid']);
      if (!skipPaymentSync && paid != oldPaid) {
          final bool hasExistingPayment = _siteExpensePayments.any((p) => p['expense_id']?.toString().trim() == strId);
          if (paid <= 0) {
              await _dbHelper.delete('site_expense_payments', 'expense_id', strId);
              _siteExpensePayments.removeWhere((p) => p['expense_id']?.toString().trim() == strId);
          } else if (!hasExistingPayment) {
              final payment = {
                'id': _generateId('PAREXP'),
                'expense_id': strId,
                'amount': '₹${paid.toInt()}',
                'date': merged['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
              };
              await _dbHelper.insert('site_expense_payments', payment);
              _siteExpensePayments.add(payment);
          } else {
              final pIndex = _siteExpensePayments.indexWhere((p) => p['expense_id']?.toString().trim() == strId);
              if (pIndex != -1) {
                  final pId = _siteExpensePayments[pIndex]['id'];
                  final updatedPayment = {
                    ..._siteExpensePayments[pIndex],
                    'amount': '₹${paid.toInt()}',
                    'date': merged['date'] ?? _siteExpensePayments[pIndex]['date'],
                  };
                  await _dbHelper.update('site_expense_payments', updatedPayment, 'id', pId);
                  _siteExpensePayments[pIndex] = updatedPayment;
              }
          }
      }
      
      // Update integration balances
      await _syncBalances(oldData, merged);
      
      final supName = merged['supplier'] ?? merged['supplier_name'] ?? oldData['supplier'] ?? oldData['supplier_name'];
      if (supName != null && supName.toString().isNotEmpty) {
        await syncSupplierBalanceByName(supName.toString());
      }

      notifyListeners();
    }
  }


  Future<List<Map<String, dynamic>>> getVehicleExpenses(String vehicleNo) async {
    return await _dbHelper.query('site_expenses', where: 'vehicle_no = ?', whereArgs: [vehicleNo]);
  }


    
  Future<void> deleteExpense(String id) async {
    final strId = id.toString().trim();
    int index = _siteExpenses.indexWhere((element) => element['id']?.toString().trim() == strId);
    final intId = int.tryParse(strId);
    if (index == -1 && intId != null) {
      index = _siteExpenses.indexWhere((element) => element['id']?.toString().trim() == intId.toString());
    }

    final Map<String, dynamic> oldData = index != -1 ? _siteExpenses[index] : {};

    final supplier = (oldData['supplier'] ?? '').toString().trim();
    final title = (oldData['title'] ?? '').toString().trim();
    bool isInternalTankDispense = strId.startsWith('EXP_TANK_') || 
                                  supplier == 'Storage Tank' || 
                                  title.contains('Tank Dispense') || 
                                  oldData['is_internal_issue'] == 1 || 
                                  oldData['is_internal_issue'] == '1';

    if (isInternalTankDispense) {
      double litersToRefund = double.tryParse(oldData['liters']?.toString() ?? oldData['quantity']?.toString() ?? '0') ?? 0.0;
      if (litersToRefund <= 0) {
        final match = RegExp(r'\((\d+(?:\.\d+)?)\s*L').firstMatch(title);
        if (match != null) {
          litersToRefund = double.tryParse(match.group(1) ?? '0') ?? 0.0;
        }
      }
      
      if (litersToRefund > 0) {
        final tanks = await _dbHelper.query('fuel_tanks');
        if (tanks.isNotEmpty) {
          final tankId = tanks.first['id'];
          final current = (tanks.first['current_liters'] as num?)?.toDouble() ?? 0.0;
          await _dbHelper.update('fuel_tanks', {'current_liters': current + litersToRefund}, 'id', tankId.toString());
        }
      }

      // Delete matching record from fuel_issues table
      final vNo = (oldData['vehicle_no'] ?? '').toString().trim();
      final date = (oldData['date'] ?? '').toString().trim();

      int? directIssueId;
      if (strId.startsWith('EXP_TANK_')) {
        directIssueId = int.tryParse(strId.replaceFirst('EXP_TANK_', ''));
      }

      bool deletedIssue = false;
      if (directIssueId != null) {
        final count = await _dbHelper.delete('fuel_issues', 'id', directIssueId);
        if (count > 0) deletedIssue = true;
      }

      if (!deletedIssue) {
        final issues = await _dbHelper.query('fuel_issues');
        for (var issue in issues) {
          final iVNo = (issue['vehicle_number'] ?? '').toString().trim();
          final iDate = (issue['date'] ?? '').toString().trim();
          final iLiters = (issue['liters'] as num?)?.toDouble() ?? 0.0;

          bool dateMatches = date.isEmpty || iDate.isEmpty || iDate == date || iDate.contains(date) || date.contains(iDate);
          bool vNoMatches = vNo.isEmpty || iVNo.toLowerCase() == vNo.toLowerCase();
          bool litersMatches = litersToRefund <= 0 || (iLiters - litersToRefund).abs() < 0.2;

          if (vNoMatches && litersMatches && dateMatches) {
            final issueId = issue['id'];
            await _dbHelper.delete('fuel_issues', 'id', issueId);
            deletedIssue = true;
            break;
          }
        }

        if (!deletedIssue) {
          final issues = await _dbHelper.query('fuel_issues');
          for (var issue in issues) {
            final iVNo = (issue['vehicle_number'] ?? '').toString().trim();
            final iLiters = (issue['liters'] as num?)?.toDouble() ?? 0.0;

            bool vNoMatches = vNo.isEmpty || iVNo.toLowerCase() == vNo.toLowerCase();
            bool litersMatches = litersToRefund <= 0 || (iLiters - litersToRefund).abs() < 0.2;

            if (vNoMatches && litersMatches) {
              final issueId = issue['id'];
              await _dbHelper.delete('fuel_issues', 'id', issueId);
              deletedIssue = true;
              break;
            }
          }
        }
      }
      await fetchFuelTankData();
    }

    // Delete Parent Expense in DB (handle int vs string ID)
    if (intId != null) {
      await _dbHelper.rawDelete('site_expenses', 'id = ? OR id = ?', [strId, intId]);
      await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ? OR expense_id = ?', [strId, intId]);
    } else {
      await _dbHelper.rawDelete('site_expenses', 'id = ?', [strId]);
      await _dbHelper.rawDelete('site_expense_payments', 'expense_id = ?', [strId]);
    }
    
    // Update Memory Lists
    _siteExpenses.removeWhere((e) => e['id']?.toString().trim() == strId || (intId != null && e['id']?.toString().trim() == intId.toString()));
    _siteExpensePayments.removeWhere((p) => p['expense_id']?.toString().trim() == strId || (intId != null && p['expense_id']?.toString().trim() == intId.toString()));

    // Sync balances AFTER removal from memory
    if (oldData.isNotEmpty) {
      await _syncBalances(oldData, null);
    }

    notifyListeners();
  }

  Future<void> deleteSiteExpenses(String siteName) async {
     // Find all expenses for this site
     final expensesToDelete = _siteExpenses.where((e) => e['site'] == siteName).toList();
     
     for (var e in expensesToDelete) {
        await deleteExpense(e['id']);
     }
     notifyListeners();
  }

  Future<void> markExpensesAsPaid(List<String> ids, String date) async {
    for (var id in ids) {
       // Check if it's a Labour Table Entry or a Standard Expense
       if (id.startsWith('LBR')) {
          final index = _labour.indexWhere((l) => l['id'] == id);
          if (index != -1) {
             final balance = parseAmount(_labour[index]['balance']);
             if (balance > 0) {
                await addLabourPayment(id, balance, date);
             }
          }
       } else {
          final index = _siteExpenses.indexWhere((e) => e['id'] == id);
          if (index != -1) {
            final oldData = _siteExpenses[index];
            final amount = parseAmount(oldData['amount']);
            final paid = parseAmount(oldData['paid']);
            final pending = amount - paid;
            
            if (pending > 0) {
              await addExpensePayment(id, {
                'amount': '₹${pending.toInt()}',
                'date': date,
              });
            }
          }
       }
    }
    notifyListeners();
  }


  /// Unified helper to sync all affected entity balances when any record changes.
  /// Unified helper to sync all affected entity balances when any record changes.
  Future<void> _syncBalances(Map<String, dynamic>? oldData, Map<String, dynamic>? newData) async {
    final Set<String> affectedSuppliers = {};
    final Set<String> affectedCustomers = {};
    final Set<String> affectedDrivers = {};
    final Set<String> affectedSites = {};
    final Set<String> affectedLabourIds = {};

    // 1. Identify Affected Entities (including reverse lookup for IDs)
    void process(Map<String, dynamic>? d) {
      if (d == null) return;
      
      // A. Suppliers
      String? supName = d['supplier']?.toString();
      // If it's the supplier object itself
      if (supName == null && (d.containsKey('material') || d.containsKey('contact'))) {
          supName = d['name']?.toString();
      }
      // If it's a payment record with ID only
      if (supName == null && d['supplier_id'] != null) {
          final sup = _suppliers.firstWhere((s) => s['id'] == d['supplier_id'], orElse: () => {});
          if (sup.isNotEmpty) supName = sup['name'];
      }
      if (supName != null) affectedSuppliers.add(supName.toLowerCase().trim());

      // B. Customers / Clients
      String? custName = d['customer']?.toString() ?? d['client']?.toString();
      // If it's the customer object itself
      if (custName == null && d.containsKey('phone') && d.containsKey('address')) {
          custName = d['name']?.toString();
      }
      // If it's a payment/income record with ID only
      if (custName == null && d['income_id'] != null) {
          final inc = _siteIncome.firstWhere((i) => i['id'] == d['income_id'], orElse: () => {});
          if (inc.isNotEmpty) custName = inc['client'];
      }
      if (custName == null && d['vehicle_id'] != null) {
          final veh = _vehicles.firstWhere((v) => v['id'] == d['vehicle_id'], orElse: () => {});
          if (veh.isNotEmpty) custName = veh['customer'];
      }
      if (custName != null) affectedCustomers.add(custName.toLowerCase().trim());

      // C. Drivers
      if (d['driver_id'] != null) {
        affectedDrivers.add(d['driver_id'].toString());
      } else if (d['id']?.toString().startsWith('DRV') == true) {
        affectedDrivers.add(d['id'].toString());
      }

      // D. Labour
      if (d['labour_id'] != null) {
        affectedLabourIds.add(d['labour_id'].toString());
      } else if (d['id']?.toString().startsWith('LBR') == true) {
        affectedLabourIds.add(d['id'].toString());
      }

      // E. Sites
      if (d['site'] != null) {
         affectedSites.add(d['site'].toString().trim());
      }
      // Site Income object
      if (d['id'] != null && d.containsKey('client') && d.containsKey('estimate')) {
         affectedSites.add("ID:${d['id']}");
      }
      // Site payment/expense sub-links
      if (d['income_id'] != null) affectedSites.add("ID:${d['income_id']}");
      if (d['expense_id'] != null) {
          final exp = _siteExpenses.firstWhere((e) => e['id'] == d['expense_id'], orElse: () => {});
          if (exp.isNotEmpty) affectedSites.add(exp['site'].toString().trim());
      }
    }

    process(oldData);
    process(newData);

    // 2. Propagate Site Changes to Customers (Critically needed for Site Expenses)
    for (var site in affectedSites) {
       final String? sName = site.startsWith("ID:") ? null : site;
       final String? sId = site.startsWith("ID:") ? site.substring(3) : null;
       
       final siteClients = _siteIncome.where((i) => 
          (sName != null && i['site']?.toString().toLowerCase().trim() == sName.toLowerCase().trim()) ||
          (sId != null && i['id'].toString() == sId)
       ).map((i) => i['client']?.toString()).where((c) => c != null);
       
       for (var c in siteClients) {
          affectedCustomers.add(c!.toLowerCase().trim());
       }
    }

    // 3. Perform Recalculations
    for (var s in affectedSuppliers) {
      await syncSupplierBalanceByName(s);
    }
    for (var d in affectedDrivers) {
      await syncDriverBalanceById(d);
    }
    for (var l in affectedLabourIds) {
      await syncLabourBalanceById(l);
    }
    
    // Site Income Sync
    for (var site in affectedSites) {
       if (site.startsWith("ID:")) {
          await syncSiteBalanceById(site.substring(3));
       } else {
          final siteObjs = _siteIncome.where((i) => i['site']?.toString().toLowerCase().trim() == site.toLowerCase().trim());
          for (var o in siteObjs) {
            await syncSiteBalanceById(o['id']);
          }
       }
    }
    
    // Finally Sync Customers (Must be last so site income state is finalized)
    for (var c in affectedCustomers) {
      await syncCustomerBalanceByName(c);
    }

    notifyListeners();
  }

  // --- RECALCULATION HELPERS ---

  Future<double> _getTotalSupplierPayments(String id, String name) async {

    double total = 0;
    
    // 1. General Ledger Payments
    final supplierPayments = await getSupplierPayments(id);
    for (var p in supplierPayments) {
      total += parseAmount(p['amount']);
    }
    
    // 2. Aggregate payments from Site Expenses
    final expenses = _siteExpenses.where((e) => e['supplier']?.toString().toLowerCase().trim() == name.toLowerCase().trim());
    for (var e in expenses) {
      total += parseAmount(e['paid']);
    }
    
    // 3. Aggregate payments from Vehicles ?? (REMOVED)
    // The 'paid' column in vehicles table usually represents money RECEIVED from Customer (Income).
    // It should NOT be counted as money paid TO the Supplier.
    // Supplier payments for vehicle materials must be made explicitly via Supplier Ledger (supplier_payments).
    
    // final vehicles = _vehicles.where((v) => v['supplier']?.toString().toLowerCase().trim() == name.toLowerCase().trim());
    // for (var v in vehicles) total += parseAmount(v['paid']);

    return total;
  }

  /// Recalculates completely one supplier's balance from scratch.
  Future<void> syncSupplierBalanceByName(String name) async {
    final sIndex = _suppliers.indexWhere((s) => s['name'].toLowerCase().trim() == name.toLowerCase().trim());
    if (sIndex == -1) return;
    
    final s = _suppliers[sIndex];
    
    final bills = await getSupplierBills(s['name']);
    double totalPurchases = bills.fold(0.0, (sum, b) => sum + parseAmount(b['bill_amount']));
    if (totalPurchases <= 0) {
      totalPurchases = parseAmount(s['total'] ?? s['balance'] ?? s['advance']);
    }

    double totalPaid = await _getTotalSupplierPayments(s['id'], s['name']);
    
    final updatedData = {
        'total': '₹${totalPurchases.toInt()}',
        'paid': '₹${totalPaid.toInt()}',
        'balance': '₹${(totalPurchases - totalPaid).toInt()}',
    };
    
    await _dbHelper.update('suppliers', updatedData, 'id', s['id']);
    _suppliers[sIndex] = {...s, ...updatedData};
    notifyListeners();
  }

  Future<void> syncDriverBalanceById(String id) async {
    final strId = id.toString();
    final index = _drivers.indexWhere((d) => d['id'].toString() == strId);
    if (index == -1) return;

    final driver = _drivers[index];

    // Ensure initial advance payment is recorded if driver has advance_amount > 0
    final initialAdv = parseAmount(driver['advance_amount'] ?? driver['advance']);
    if (initialAdv > 0) {
      final existingAdvPayments = _driverPayments.where((p) {
        final pDriverId = (p['driver_id'] ?? '').toString().trim();
        final mode = (p['mode'] ?? '').toString().trim();
        final isAdv = mode == 'Give Advance' || mode == 'Advance' || mode.toLowerCase().contains('give advance') || mode == 'Advance Box Given';
        return pDriverId == strId && isAdv;
      }).toList();

      double totalGiveAdv = existingAdvPayments.fold(0.0, (sum, p) => sum + parseAmount(p['amount']));
      if (initialAdv > totalGiveAdv) {
        double missingAmt = initialAdv - totalGiveAdv;
        String advDate = driver['date'] ?? DateFormat('dd MMM yyyy').format(DateTime.now());
        final payment = {
          'id': _generateId('PAY-DRV'),
          'driver_id': strId,
          'amount': '₹${missingAmt.toInt()}',
          'date': advDate,
          'type': 'Payment',
          'mode': 'Give Advance',
        };
        await _dbHelper.insert('driver_payments', payment);
        _driverPayments.add(payment);
      }
    }
    double totalEarnings = 0;
    double totalPaid = 0;

    final intId = int.tryParse(strId);

    // 1. Sum Earnings from Attendance
    final attendanceResult = await _dbHelper.query(
      'driver_attendance', 
      where: intId != null ? 'driver_id = ? OR driver_id = ?' : 'driver_id = ?', 
      whereArgs: intId != null ? [strId, intId] : [strId]
    );
    for (var row in attendanceResult) {
       totalEarnings += parseAmount(row['earnings']);
    }

    // 2. Sum From driver_payments (Separate Work vs Payment vs Give Advance)
    final paymentsResult = await _dbHelper.query(
      'driver_payments', 
      where: intId != null ? 'driver_id = ? OR driver_id = ?' : 'driver_id = ?', 
      whereArgs: intId != null ? [strId, intId] : [strId]
    );
    for (var row in paymentsResult) {
       final type = row['type']?.toString() ?? 'Payment';
       final amount = parseAmount(row['amount']);
       final mode = (row['mode'] ?? '').toString().trim();
       final isGiveAdvance = mode == 'Give Advance' || mode == 'Advance' || mode.toLowerCase().contains('give advance') || mode == 'Advance Box Given';
       if (type == 'Work') {
          totalEarnings += amount;
       } else if (!isGiveAdvance) {
          totalPaid += amount;
       }
    }

    final totalAdvGiven = getDriverAdvanceGiven(strId);
    final formattedAdv = '₹${totalAdvGiven.toInt()}';

    final updated = {
       ...driver,
       'advance_amount': formattedAdv,
       'earnings': '₹${totalEarnings.toInt()}',
       'paid': '₹${totalPaid.toInt()}',
       'balance': '₹${(totalEarnings - totalPaid).toInt()}',
       'status': (totalEarnings - totalPaid) <= 0 ? StatusType.paid : StatusType.pending,
    };

    final dbData = {...updated};
    dbData.remove('advance_date');
    dbData.remove('advance');
    dbData['status'] = updated['status'].toString();

    await _dbHelper.update('drivers', dbData, 'id', driver['id']);
    _drivers[index] = updated;
    notifyListeners();
  }

  Future<void> syncLabourBalanceById(String id) async {
     final index = _labour.indexWhere((l) => l['id'] == id);
     if (index == -1) return;
     
     final labour = _labour[index];
     
     // Calculate Total Owed from:
     // A. Initial setup balance (from labour table)
     // B. All work entries (from site_expenses category=Labour)
     double totalWork = parseAmount(labour['advance']) + parseAmount(labour['balance']);
     
     // Add dynamically from site_expenses
     final name = labour['name']?.toString().toLowerCase().trim() ?? '';
     final siteTransactions = _siteExpenses.where((e) => 
         e['category'] == 'Labour' && e['title']?.toString().toLowerCase().trim() == name
     );
     for (var e in siteTransactions) {
         totalWork += parseAmount(e['amount']);
     }

     double totalPaid = 0;
     final payments = await _dbHelper.query('labour_payments', where: 'labour_id = ?', whereArgs: [id]);
     for (var p in payments) {
        totalPaid += parseAmount(p['amount']);
     }
     
     // Include payments recorded in site_expenses too
     for (var e in siteTransactions) {
         totalPaid += parseAmount(e['paid']);
     }
     
     double newBalance = totalWork - totalPaid;
     if (newBalance < 0) newBalance = 0; // Prevent negative balance

     final updated = {
       ...labour, 
       'advance': '₹${totalPaid.toInt()}', 
       'balance': '₹${newBalance.toInt()}'
     };
     
     await _dbHelper.update('labour', updated, 'id', id);
     _labour[index] = updated;
     notifyListeners();
  }

  Future<void> syncSiteBalanceById(String id) async {
     final index = _siteIncome.indexWhere((s) => s['id'] == id);
     if (index == -1) return;
     
     final site = _siteIncome[index];
     double totalReceived = 0;
     
     final payments = await _dbHelper.query('income_payments', where: 'income_id = ?', whereArgs: [id]);
     for (var p in payments) {
        totalReceived += parseAmount(p['amount']);
     }
     
     double estimate = parseAmount(site['estimate']);
     double pending = estimate - totalReceived;
     
     final updated = {
        ...site,
        'received': '₹${totalReceived.toInt()}',
        'pending': '₹${(pending > 0 ? pending : 0).toInt()}',
        'status': (site['status'].toString().trim() == 'Completed' || pending <= 0) ? 'Completed' : 'Active',
        'isProfit': (site['isProfit'] == true || site['isProfit'] == 1) ? 1 : 0,
     };
     
     await _dbHelper.update('site_income', updated, 'id', id);
     _siteIncome[index] = updated;
     notifyListeners();
  }

  /// One-time fix to sync all supplier balances from their transaction history.
  Future<void> syncAllSupplierBalances() async {
    // 1. Suppliers
    for (int i = 0; i < _suppliers.length; i++) {
        await syncSupplierBalanceByName(_suppliers[i]['name']);
    }
    // 2. Customers
    for (int i = 0; i < _customers.length; i++) {
        await syncCustomerBalanceByName(_customers[i]['name']);
    }
    // 3. Drivers
    await processMonthlySalaries();
    for (int i = 0; i < _drivers.length; i++) {
        await syncDriverBalanceById(_drivers[i]['id']);
    }
    // 4. Labour
    for (int i = 0; i < _labour.length; i++) {
        await syncLabourBalanceById(_labour[i]['id']);
    }
    // 5. Site Income
    for (int i = 0; i < _siteIncome.length; i++) {
        await syncSiteBalanceById(_siteIncome[i]['id']);
    }
    notifyListeners();
  }

  // TRANSACTIONS
  Future<void> addTransaction(String title, String subtitle, String amount, bool isExpense) async {
    final tx = {
      'title': title,
      'subtitle': subtitle,
      'amount': amount,
      'date': 'Just now',
      'status': StatusType.pending,
      'isExpense': isExpense,
    };
    
    final dbTx = {
      ...tx,
      'status': StatusType.pending.toString(),
      'isExpense': isExpense ? 1 : 0,
    };
    
    await _dbHelper.insert('transactions', dbTx);
    _recentTransactions.insert(0, tx);
    notifyListeners();
  }


  // --- AUTHENTICATION ---
  Future<bool> login(String username, String password) async {
    // 0. Hardcoded Recovery for Admin
    if (username == 'admin' && password == 'admin') {
       final db = await _dbHelper.database;
       final List<Map<String, dynamic>> check = await db.query('users', where: 'username = ?', whereArgs: ['admin']);
       if (check.isEmpty) {
          // Auto-Repair: User deleted DB but app is running? Or DB corruption. Re-add admin.
          await db.insert('users', {'username': 'admin', 'password': 'admin', 'role': 'admin'});
       }
       return true;
    }

    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
    );
    return result.isNotEmpty;
  }



  Future<void> addVehiclePayment(String id, double amount, String date) async {
    final index = _vehicles.indexWhere((element) => element['id'] == id);
    if (index != -1) {
      final v = _vehicles[index];
      double currentPaid = parseAmount(v['paid']);
      double newPaid = currentPaid + amount;
      
      try {
        // Delegate completely to updateVehicle which handles DB update + Payment Logging (if paid changes)
        // Pass 'payment_date' so it logs with the correct backdated time.
        await updateVehicle(id, {
          'paid': '₹${newPaid.toInt()}',
          'payment_date': date,
        });
      } catch (e) {
        debugPrint('Error in addVehiclePayment: $e');
      }
    }
  }


  // --- BACKUP & CONNECTIVITY ---
  final GoogleDriveService _driveService = GoogleDriveService();

  Future<bool> checkConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      // Also check if credentials exist
      final clientId = await getSetting('google_client_id');
      final clientSecret = await getSetting('google_client_secret');
      final hasCreds = (clientId != null && clientId.isNotEmpty) && (clientSecret != null && clientSecret.isNotEmpty);
      
      return hasInternet && hasCreds;
    } catch (_) {
      return false;
    }
  }

  Future<void> authenticateDrive(String clientId, String clientSecret) async {
    await _driveService.authenticate(clientId, clientSecret);
    notifyListeners();
  }

  Future<String?> cloudBackup() async {
    // 1. Authenticate if needed
    if (!_driveService.isAuthenticated) {
      final clientId = await getSetting('google_client_id');
      final clientSecret = await getSetting('google_client_secret');
      if (clientId == null || clientSecret == null) return "Missing Credentials";
      await _driveService.authenticate(clientId, clientSecret);
    }

    try {
      // 2. Get active live DB path
      final dbPath = await _dbHelper.getDbFilePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) return "Database file not found";

      // 3. Create Local Backup Copy First
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(docDir.path, 'JarvisBackups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = join(backupDir.path, 'backup_$timestamp.db');
      final tempBackup = await dbFile.copy(backupPath);

      // 4. Upload to Drive
      final error = await _driveService.uploadBackup(tempBackup);
      if (error != null) return error;

      // 5. Update Last Backup Time
      await setSetting('last_backup', timestamp);
      return null;
    } catch (e) {
      return "Cloud Backup Failed: $e";
    }
  }

  Future<List<drive.File>> listCloudBackups() async {
    // Authenticate if needed
    if (!_driveService.isAuthenticated) {
      final clientId = await getSetting('google_client_id');
      final clientSecret = await getSetting('google_client_secret');
      if (clientId != null && clientSecret != null) {
        await _driveService.authenticate(clientId, clientSecret);
      } else {
        return [];
      }
    }
    return await _driveService.listBackups();
  }

  Future<String?> cloudRestore(String fileId) async {
    try {
      // 1. Download to Temp
      final docDir = await getApplicationDocumentsDirectory();
      final restorePath = join(docDir.path, 'restore_temp.db');
      
      final file = await _driveService.downloadBackup(fileId, restorePath);
      if (file == null) return "Download Failed";

      // 2. Close DB
      await _dbHelper.close();
      
      // 3. Replace Active DB File
      final dbPath = await _dbHelper.getDbFilePath();
      final currentDb = File(dbPath);
      if (await currentDb.exists()) {
        await currentDb.delete();
      }

      await file.copy(dbPath);
      
      // 4. Reload Data
      await _initData();
      
      return null;
    } catch (e) {
      return "Restore Failed: $e";
    }
  }

  Future<String?> backupDatabase() async {
    try {
      // 1. Get current active DB path
      final dbPath = await _dbHelper.getDbFilePath();
      final dbFile = File(dbPath);
      
      if (!await dbFile.exists()) return "Database file not found";

      // 2. Get Backup Folder (Documents/JarvisBackups)
      final docDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(join(docDir.path, 'JarvisBackups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 3. Create Backup File Name with Timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupPath = join(backupDir.path, 'backup_$timestamp.db');

      // 4. Copy
      await dbFile.copy(backupPath);
      
      // 5. Update Last Backup Time Setting
      await setSetting('last_backup', timestamp);
      
      return null; // Success
    } catch (e) {
      return "Backup Failed: ${e.toString()}";
    }
  }


  Future<String?> getLastBackupTime() async {
    final ts = await getSetting('last_backup');
    if (ts == null) return null;
    try {
      final year = ts.substring(0, 4);
      final month = ts.substring(4, 6);
      final day = ts.substring(6, 8);
      final hour = ts.substring(9, 11);
      final minute = ts.substring(11, 13);
      return "$day-$month-$year $hour:$minute";
    } catch (_) {
      return ts;
    }
  }
  Future<void> addToRegistry(Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('VEH');
    await _dbHelper.insert('vehicle_registry', data);
    _vehicleRegistry.add(data);
    notifyListeners();
  }

  Future<void> updateInRegistry(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('vehicle_registry', data, 'id', id);
    final index = _vehicleRegistry.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      _vehicleRegistry[index] = {..._vehicleRegistry[index], ...data};
      notifyListeners();
    }
  }

  Future<void> removeFromRegistry(String id) async {
    await _dbHelper.delete('vehicle_registry', 'id', id);
    _vehicleRegistry.removeWhere((v) => v['id'] == id);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getAttendanceForMonth(int month, int year) async {
    final targetMonYear = DateFormat('MMM yyyy').format(DateTime(year, month));
    final suffix = '% $targetMonYear';
    return await _dbHelper.query('driver_attendance', where: 'date LIKE ?', whereArgs: [suffix]);
  }

  Future<void> _refreshSupplierMaterialString(String supplierId) async {
    final materials = await getSupplierMaterials(supplierId);
    final uniqueNames = materials.map((m) => m['material_name'].toString()).toSet().toList();
    final combined = uniqueNames.join(', ');
    await updateSupplier(supplierId, {'material': combined});
  }

  Future<void> addSupplierMaterial(Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('MAT');
    await _dbHelper.insert('supplier_materials', data);
    if (data['supplier_id'] != null) {
      await _refreshSupplierMaterialString(data['supplier_id']);
    } else {
      notifyListeners();
    }
  }

  Future<void> updateSupplierMaterial(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('supplier_materials', data, 'id', id);
    if (data['supplier_id'] != null) {
      await _refreshSupplierMaterialString(data['supplier_id']);
    } else {
      notifyListeners();
    }
  }

  Future<void> deleteSupplierMaterial(String id) async {
    final matList = await _dbHelper.query('supplier_materials', where: 'id = ?', whereArgs: [id]);
    String? supplierId;
    if (matList.isNotEmpty) {
      supplierId = matList.first['supplier_id'];
    }
    await _dbHelper.delete('supplier_materials', 'id', id);
    if (supplierId != null) {
      await _refreshSupplierMaterialString(supplierId);
    } else {
      notifyListeners();
    }
  }

  // CUSTOMER PAYMENTS
  Future<void> addCustomerPayment(Map<String, dynamic> data) async {
    if (!data.containsKey('id')) data['id'] = _generateId('CPAY');
    await _dbHelper.insert('customer_payments', data);
    _customerPayments.add(data);
    if (data['customer_name'] != null) {
      await syncCustomerBalanceByName(data['customer_name']);
    }
    notifyListeners();
  }

  Future<void> updateCustomerPayment(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('customer_payments', data, 'id', id);
    final index = _customerPayments.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      final oldPath = _customerPayments[index];
      _customerPayments[index] = {...oldPath, ...data};
      if (oldPath['customer_name'] != null) await syncCustomerBalanceByName(oldPath['customer_name']);
      if (data['customer_name'] != null && data['customer_name'] != oldPath['customer_name']) {
        await syncCustomerBalanceByName(data['customer_name']);
      }
    }
    notifyListeners();
  }

  Future<void> deleteCustomerPayment(String id) async {
    final index = _customerPayments.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      final oldPath = _customerPayments[index];
      await _dbHelper.delete('customer_payments', 'id', id);
      _customerPayments.removeAt(index);
      if (oldPath['customer_name'] != null) await syncCustomerBalanceByName(oldPath['customer_name']);
    }
    notifyListeners();
  }

  Future<void> updateIncomePayment(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('income_payments', data, 'id', id);
    final index = _incomePayments.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      _incomePayments[index] = {..._incomePayments[index], ...data};
      final incId = _incomePayments[index]['income_id'];
      if (incId != null) await syncSiteBalanceById(incId);
    }
    notifyListeners();
  }

  Future<void> updateVehiclePayment(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('vehicle_payments', data, 'id', id);
    final index = _vehiclePayments.indexWhere((p) => p['id'] == id);
    if (index != -1) {
      _vehiclePayments[index] = {..._vehiclePayments[index], ...data};
      final vId = _vehiclePayments[index]['vehicle_id'];
      if (vId != null) {
        final v = _vehicles.firstWhere((v) => v['id'] == vId, orElse: () => {});
        if (v.isNotEmpty && v['customer'] != null) await syncCustomerBalanceByName(v['customer']);
      }
    }
    notifyListeners();
  }

  Future<void> updateAttendance(String id, Map<String, dynamic> data) async {
    await _dbHelper.update('driver_attendance', data, 'id', id);
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getVehicleSummaryData(DateTimeRange? range, bool includeMaterialProfit) async {
    final List<Map<String, dynamic>> summaryList = [];

    // Filter vehicles by date range
    var filteredVehicles = _vehicles;
    if (range != null) {
      filteredVehicles = _vehicles.where((v) {
        if (v['date'] == null) return false;
        try {
          final date = DateFormat('dd MMM yyyy').parse(v['date'].toString());
          return date.isAfter(range.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(range.end.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Filter vehicle expenses
    var filteredExpenses = _siteExpenses.where((e) => e['category'] == 'Vehicle').toList();
    if (range != null) {
      filteredExpenses = filteredExpenses.where((e) {
        if (e['date'] == null) return false;
        try {
          final date = DateFormat('dd MMM yyyy').parse(e['date'].toString());
          return date.isAfter(range.start.subtract(const Duration(days: 1))) &&
                 date.isBefore(range.end.add(const Duration(days: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Get all unique vehicle numbers (including all registered vehicles from Vehicle Registry, excluding Storage Tank)
    final Set<String> vehicleNos = {};
    bool isTank(String name) => name.toLowerCase().contains('storage tank') || name.toLowerCase().contains('bulk storage');

    for (var reg in _vehicleRegistry) {
      final numStr = (reg['number'] ?? reg['vehicle_no'] ?? reg['name'])?.toString().trim();
      if (numStr != null && numStr.isNotEmpty && !isTank(numStr)) {
        vehicleNos.add(numStr);
      }
    }
    for (var v in filteredVehicles) {
      final numStr = v['number']?.toString().trim();
      if (numStr != null && numStr.isNotEmpty && !isTank(numStr)) {
        vehicleNos.add(numStr);
      }
    }
    for (var e in filteredExpenses) {
      final numStr = e['vehicle_no']?.toString().trim();
      if (numStr != null && numStr.isNotEmpty && !isTank(numStr)) {
        vehicleNos.add(numStr);
      }
    }

    for (String vNo in vehicleNos) {
      final vTrips = filteredVehicles.where((v) => v['number']?.toString().trim() == vNo).toList();
      final vExpenses = filteredExpenses.where((e) => e['vehicle_no']?.toString().trim() == vNo).toList();

      double tripIncome = 0; // Gross income (Total)
      double rentIncome = 0; // Trip Cost (Rent)
      double battaIncome = 0; // Batta Amount
      double materialExpense = 0; // Material Buy Cost (buy_price * Qty)
      double materialSell = 0; // Material Sell Cost (unit_price * Qty)
      double fuelExpense = 0;
      double maintenanceExpense = 0;

      int totalTrips = vTrips.length;
      List<Map<String, dynamic>> materialsBreakdown = [];

      for (var trip in vTrips) {
        tripIncome += parseAmount(trip['total']);
        rentIncome += parseAmount(trip['rent_amount'] ?? trip['total']);
        battaIncome += parseAmount(trip['batta_amount'] ?? trip['batta']);

        final materialName = trip['material_name']?.toString().trim();
        final qty = parseAmount(trip['quantity']);

        if (materialName != null && materialName.isNotEmpty && qty > 0) {
            double buy = parseAmount(trip['buy_price']);
            double sell = parseAmount(trip['unit_price']);
            
            materialExpense += buy * qty;
            materialSell += sell * qty;
            materialsBreakdown.add({
              'name': materialName,
              'qty': qty,
              'buy': buy,
              'sell': sell,
              'cost': sell * qty, // Material Cost is Sell Price
              'buy_cost': buy * qty, // Used internally for expense calculations
              'date': trip['date'],
            });
        }
      }

      for (var exp in vExpenses) {
         double amt = parseAmount(exp['amount']);
         final desc = exp['description']?.toString().toLowerCase() ?? '';
         final sup = exp['supplier']?.toString().toLowerCase() ?? '';
         final title = exp['title']?.toString().toLowerCase() ?? '';
         final matName = exp['material_name']?.toString().toLowerCase() ?? '';

         bool isFuel = title.contains('fuel') || title.contains('diesel') || title.contains('petrol') || title.contains('tank dispense') ||
                       desc.contains('fuel') || desc.contains('diesel') || desc.contains('petrol') || desc.contains('bunk') ||
                       sup.contains('fuel') || sup.contains('diesel') || sup.contains('petrol') || sup.contains('bunk') || sup.contains('storage tank') ||
                       matName.contains('fuel') || matName.contains('diesel');

         if (isFuel) {
           fuelExpense += amt;
         } else {
           maintenanceExpense += amt;
         }
      }

      double totalExpense = fuelExpense + maintenanceExpense + materialExpense;
      double netProfit = tripIncome - totalExpense;

      summaryList.add({
        'vehicle_no': vNo,
        'total_trips': totalTrips,
        'trip_income': tripIncome, // Gross Income (total)
        'rent_income': rentIncome, // Trip Cost (rent)
        'batta_income': battaIncome, // Batta Amount
        'fuel_expense': fuelExpense,
        'maintenance_expense': maintenanceExpense,
        'material_expense': materialExpense, // Buy Cost (expense)
        'material_sell': materialSell, // Sell Cost (Material Cost column)
        'total_expense': totalExpense,
        'net_profit': netProfit,
        'materials_breakdown': materialsBreakdown,
        'trips': vTrips,
        'expenses': vExpenses,
      });
    }

    return summaryList;
  }
}



