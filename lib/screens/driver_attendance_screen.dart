import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';

class DriverAttendanceScreen extends StatefulWidget {
  const DriverAttendanceScreen({super.key});

  @override
  State<DriverAttendanceScreen> createState() => _DriverAttendanceScreenState();
}

class _DriverAttendanceScreenState extends State<DriverAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, bool> _attendanceStatus = {}; // driverId -> isPresent (Toggle 1)
  Map<String, bool> _attendanceStatus2 = {}; // driverId -> isPresent (Toggle 2) (Req 4)
  Map<String, String> _attendanceNotes = {}; // driverId -> notes (optional)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    final data = Provider.of<DataProvider>(context, listen: false);
    
    // Fetch existing attendance for this date
    final existing = await data.getDriverAttendance(dateStr);
    
    // Reset state
    _attendanceStatus = {};
    _attendanceNotes = {};

    // Populate from existing
    for (var record in existing) {
      _attendanceStatus[record['driver_id']] = record['status'] == 'Present';
      _attendanceStatus2[record['driver_id']] = record['status2'] == 'Present'; // Load Status 2
      if (record['notes'] != null) {
        _attendanceNotes[record['driver_id']] = record['notes'];
      }
    }

    // For any driver not in DB, default to Present (or Absent? usually Present is better default for bulk)
    // Actually, let's default to unchecked (Absent) so they check who is present.
    // Or if it's a workday, maybe default Present?
    // Let's default to FALSE (Absent) to require explicit action, or maybe TRUE?
    // User request: "present absent mattum podra mari"
    // Let's fetch all Monthly drivers.
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadAttendance();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<DataProvider>(
              builder: (context, data, child) {
                final activeDrivers = data.allDrivers.where((d) {
                  final status = d['status'];
                  final isInactive = status == 'Inactive' || 
                                     status.toString() == 'StatusType.inactive';
                  return !isInactive;
                }).toList();
                activeDrivers.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
                
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (activeDrivers.isEmpty) {
                  return const Center(child: Text('No active drivers found.'));
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: JarvisTheme.secondary.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Text(
                            'Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: JarvisTheme.secondary),
                           ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: activeDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = activeDrivers[index];
                          final driverId = driver['id'];
                          final isPresent = _attendanceStatus[driverId] ?? false; // Default False

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                   // Avatar
                                   CircleAvatar(
                                     backgroundColor: isPresent ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                     child: Icon(
                                       isPresent ? Icons.check : Icons.close,
                                       color: isPresent ? Colors.green : Colors.red,
                                     ),
                                   ),
                                   const SizedBox(width: 16),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(driver['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                         Text('${driver['type'] ?? 'Monthly'} • ${driver['contact'] ?? ''}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                       ],
                                     ),
                                   ),
                                    Column(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [
                                         Text(
                                           isPresent ? 'PRESENT' : 'ABSENT', 
                                           style: TextStyle(
                                             fontSize: 11, 
                                             fontWeight: FontWeight.bold, 
                                             color: isPresent ? Colors.green : Colors.red
                                           ),
                                         ),
                                         Switch(
                                           value: isPresent,
                                           activeThumbColor: Colors.green,
                                           activeTrackColor: Colors.green.withValues(alpha: 0.3),
                                           inactiveThumbColor: Colors.red,
                                           inactiveTrackColor: Colors.red.withValues(alpha: 0.3),
                                           onChanged: (val) {
                                             setState(() {
                                               _attendanceStatus[driverId] = val;
                                             });
                                           },
                                         ),
                                       ],
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
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveAttendance,
                icon: const Icon(Icons.save),
                label: const Text('SAVE ATTENDANCE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JarvisTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendance() async {
    final data = Provider.of<DataProvider>(context, listen: false);
    final dateStr = DateFormat('dd MMM yyyy').format(_selectedDate);
    
    final activeDrivers = data.allDrivers.where((d) {
      final status = d['status'];
      final isInactive = status == 'Inactive' || 
                         status.toString() == 'StatusType.inactive';
      return !isInactive;
    }).toList();
    
    List<Map<String, dynamic>> toSave = [];
    
    for (var driver in activeDrivers) {
      final id = driver['id'];
      final isPresent = _attendanceStatus[id] ?? false;
      final isPresent2 = _attendanceStatus2[id] ?? false;
      
      toSave.add({
        'driver_id': id,
        'date': dateStr,
        'status': isPresent ? 'Present' : 'Absent',
        'status2': isPresent2 ? 'Present' : 'Absent',
        'notes': _attendanceNotes[id] ?? ''
      });
    }
    
    await data.markBulkAttendance(toSave);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance Saved Successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }
}
