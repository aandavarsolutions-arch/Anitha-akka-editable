import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import '../widgets/dev_branding_badge.dart';

class DriverAttendanceReportScreen extends StatefulWidget {
  const DriverAttendanceReportScreen({super.key});

  @override
  State<DriverAttendanceReportScreen> createState() => _DriverAttendanceReportScreenState();
}

class _DriverAttendanceReportScreenState extends State<DriverAttendanceReportScreen> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = true;
  String _filterType = 'All'; // 'All', 'Daily', 'Monthly'
  Map<String, Map<int, String>> _attendanceData = {}; // driverId -> day -> status
  Map<String, Map<int, String>> _attendanceData2 = {}; // Req 4

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = Provider.of<DataProvider>(context, listen: false);
    final records = await data.getAttendanceForMonth(_selectedMonth.month, _selectedMonth.year);
    
    Map<String, Map<int, String>> mapped = {};
    Map<String, Map<int, String>> mapped2 = {};
    
    for (var record in records) {
       final dateStr = record['date'] as String;
       try {
         final date = DateFormat('dd MMM yyyy').parse(dateStr);
         final day = date.day;
         final driverId = record['driver_id'];
         
         if (!mapped.containsKey(driverId)) mapped[driverId] = {};
         mapped[driverId]![day] = record['status'] ?? 'Absent';

         if (!mapped2.containsKey(driverId)) mapped2[driverId] = {};
         mapped2[driverId]![day] = record['status2'] ?? 'Absent';
       } catch (e) {}
    }
    
    setState(() {
      _attendanceData = mapped;
      _attendanceData2 = mapped2;
      _isLoading = false;
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
    final activeDrivers = data.allDrivers.where((d) {
      final status = d['status'];
      final isInactive = status == 'Inactive' || status.toString() == 'StatusType.inactive';
      if (isInactive) return false;

      final type = (d['type'] ?? '').toString();
      if (_filterType == 'Monthly') {
        return type == 'Monthly';
      } else if (_filterType == 'Daily') {
        return type == 'Daily' || type == 'Daily Wages';
      }
      return true;
    }).toList();
    activeDrivers.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Report'),
        actions: [const DevBrandingBadge()],
      ),
      body: Column(
        children: [
          _buildMonthPicker(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.withValues(alpha: 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment<String>(value: 'All', label: Text('All Drivers')),
                    ButtonSegment<String>(value: 'Daily', label: Text('Daily Wages')),
                    ButtonSegment<String>(value: 'Monthly', label: Text('Monthly')),
                  ],
                  selected: {_filterType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _filterType = newSelection.first;
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : activeDrivers.isEmpty 
                ? Center(child: Text('No ${_filterType == 'All' ? '' : _filterType} Drivers Found'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sticky Header Row with fixed widths
                        Container(
                          color: Colors.grey[200],
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 150,
                                child: Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text('Driver Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              const SizedBox(
                                width: 45,
                                child: Center(
                                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                              ...List.generate(daysInMonth, (index) => SizedBox(
                                width: 32,
                                child: Center(
                                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              )),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        // Vertically Scrollable Body Rows
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: activeDrivers.map((driver) {
                                final driverId = driver['id'];
                                final map1 = _attendanceData[driverId] ?? {};
                                final map2 = _attendanceData2[driverId] ?? {};
                                final type = driver['type'] ?? 'Daily';
                                
                                int totalPresent = 0;
                                for (var v in map1.values) if (v == 'Present') totalPresent++;
                                for (var v in map2.values) if (v == 'Present') totalPresent++;

                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 150,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  driver['name'] ?? 'Unknown',
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: (type == 'Monthly' ? Colors.blue : Colors.orange).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  type == 'Monthly' ? 'M' : 'D',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: type == 'Monthly' ? Colors.blue[800] : Colors.orange[900],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 45,
                                        child: Center(
                                          child: Text(
                                            totalPresent.toString(),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ),
                                      ...List.generate(daysInMonth, (index) {
                                        final day = index + 1;
                                        final s1 = map1[day];
                                        final s2 = map2[day];
                                        int daily = 0;
                                        if (s1 == 'Present') daily++;
                                        if (s2 == 'Present') daily++;

                                        return SizedBox(
                                          width: 32,
                                          child: Center(
                                            child: daily > 0 
                                              ? Text(daily.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                                              : (s1 == 'Absent' || s2 == 'Absent') 
                                                ? const Icon(Icons.close, size: 14, color: Colors.red)
                                                : const Text('-', style: TextStyle(color: Colors.grey)),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: JarvisTheme.primary.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
          Text(DateFormat('MMMM yyyy').format(_selectedMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
        ],
      ),
    );
  }
}
