import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/data_provider.dart';
import '../theme.dart';
import 'package:intl/intl.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';

class VehicleSummaryScreen extends StatefulWidget {
  final bool isEmbedded;
  const VehicleSummaryScreen({super.key, this.isEmbedded = false});

  @override
  State<VehicleSummaryScreen> createState() => _VehicleSummaryScreenState();
}

class _VehicleSummaryScreenState extends State<VehicleSummaryScreen> {
  bool _includeMaterialProfit = false;
  List<Map<String, dynamic>> _summaryData = [];
  bool _isLoading = true;
  Set<String> _selectedVehicles = {};
  DateTimeRange? _lastRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final data = Provider.of<DataProvider>(context, listen: false);
    final results = await data.getVehicleSummaryData(data.selectedDateRange, _includeMaterialProfit);
    if (!mounted) return;
    setState(() {
      final existing = results.map((e) => e['vehicle_no'].toString()).toSet();
      if (_selectedVehicles.isEmpty || _selectedVehicles.length >= _summaryData.length) {
        _selectedVehicles = Set.from(existing);
      } else {
        _selectedVehicles = _selectedVehicles.intersection(existing);
        if (_selectedVehicles.isEmpty) {
          _selectedVehicles = Set.from(existing);
        }
      }
      _summaryData = results;
      _isLoading = false;
    });
  }

  Future<void> _generatePdfReport() async {
    if (_summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to generate report')));
      return;
    }

    final data = Provider.of<DataProvider>(context, listen: false);
    final businessName = await data.getSetting('business_name');
    final logoPath = await data.getLogoPath();

    final range = data.selectedDateRange;
    final dateStr = range != null 
        ? '${DateFormat('dd MMM yyyy').format(range.start)} to ${DateFormat('dd MMM yyyy').format(range.end)}'
        : 'All Time';

    double totalIncome = 0;
    double totalExpense = 0;
    double totalNetProfit = 0;

    final displayedData = _summaryData.where((v) => _selectedVehicles.contains(v['vehicle_no'])).toList();

    for (var v in displayedData) {
      totalIncome += (v['trip_income'] as num).toDouble();
      totalExpense += (v['total_expense'] as num).toDouble();
      totalNetProfit += (v['net_profit'] as num).toDouble();
    }

    Map<String, String> totalsMap = {
      'Total Income': 'Rs. ${totalIncome.toStringAsFixed(0)}',
      'Total Expenses': 'Rs. ${totalExpense.toStringAsFixed(0)}',
      'Net Profit': 'Rs. ${totalNetProfit.toStringAsFixed(0)}',
    };

    await PdfService.generateDetailedVehicleSummaryPdf(
      title: 'Vehicle Summary Report',
      subTitle: _selectedVehicles.length == _summaryData.length 
          ? 'Period: $dateStr' 
          : 'Vehicles: ${_selectedVehicles.join(', ')} | Period: $dateStr',
      summaryData: displayedData,
      includeMaterialProfit: true, // always true now, we will draw the columns
      totals: totalsMap,
      businessName: businessName,
      logoPath: logoPath,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Generated Successfully')));
    }
  }

  Future<void> _generateExcelReport() async {
    if (_summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to generate report')));
      return;
    }

    final data = Provider.of<DataProvider>(context, listen: false);
    final businessName = await data.getSetting('business_name');

    final range = data.selectedDateRange;
    final dateStr = range != null 
        ? '${DateFormat('dd MMM yyyy').format(range.start)} to ${DateFormat('dd MMM yyyy').format(range.end)}'
        : 'All Time';

    double totalIncome = 0;
    double totalExpense = 0;
    double totalNetProfit = 0;

    final displayedData = _summaryData.where((v) => _selectedVehicles.contains(v['vehicle_no'])).toList();

    for (var v in displayedData) {
      totalIncome += (v['trip_income'] as num).toDouble();
      totalExpense += (v['total_expense'] as num).toDouble();
      totalNetProfit += (v['net_profit'] as num).toDouble();
    }

    Map<String, String> totalsMap = {
      'Total Income': 'Rs. ${totalIncome.toStringAsFixed(0)}',
      'Total Expenses': 'Rs. ${totalExpense.toStringAsFixed(0)}',
      'Net Profit': 'Rs. ${totalNetProfit.toStringAsFixed(0)}',
    };

    await ExcelService.generateDetailedVehicleSummaryExcel(
      title: 'Vehicle Summary Report',
      subTitle: _selectedVehicles.length == _summaryData.length 
          ? 'Period: $dateStr' 
          : 'Vehicles: ${_selectedVehicles.join(', ')} | Period: $dateStr',
      summaryData: displayedData,
      includeMaterialProfit: true,
      totals: totalsMap,
      businessName: businessName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel Report Generated Successfully')));
    }
  }

  Future<void> _copySummaryToClipboard() async {
    if (_summaryData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to copy')));
      return;
    }

    try {
      final data = Provider.of<DataProvider>(context, listen: false);
      final businessName = await data.getSetting('business_name');
      final logoPath = await data.getLogoPath();

      final range = data.selectedDateRange;
      final dateStr = range != null 
          ? '${DateFormat('dd MMM yyyy').format(range.start)} to ${DateFormat('dd MMM yyyy').format(range.end)}'
          : 'All Time';

      double totalIncome = 0;
      double totalExpense = 0;
      double totalNetProfit = 0;

      final displayedData = _summaryData.where((v) => _selectedVehicles.contains(v['vehicle_no'])).toList();

      for (var v in displayedData) {
        totalIncome += (v['trip_income'] as num).toDouble();
        totalExpense += (v['total_expense'] as num).toDouble();
        totalNetProfit += (v['net_profit'] as num).toDouble();
      }

      Map<String, String> totalsMap = {
        'Total Income': 'Rs. ${totalIncome.toStringAsFixed(0)}',
        'Total Expenses': 'Rs. ${totalExpense.toStringAsFixed(0)}',
        'Net Profit': 'Rs. ${totalNetProfit.toStringAsFixed(0)}',
      };

      final pdfFile = await PdfService.getDetailedVehicleSummaryPdfFile(
        title: 'Vehicle Summary Report',
        subTitle: _selectedVehicles.length == _summaryData.length 
            ? 'Period: $dateStr' 
            : 'Vehicles: ${_selectedVehicles.join(', ')} | Period: $dateStr',
        summaryData: displayedData,
        includeMaterialProfit: true,
        totals: totalsMap,
        businessName: businessName,
        logoPath: logoPath,
      );

      await PdfService.copyPdfFileToClipboard(pdfFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('📋 PDF file copied to clipboard! Press Ctrl+V to paste.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error copying PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<DataProvider>(context);
    final range = data.selectedDateRange;

    if (_lastRange != range) {
      _lastRange = range;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }

    final dateStr = range != null 
        ? '${DateFormat('dd MMM yyyy').format(range.start)} - ${DateFormat('dd MMM yyyy').format(range.end)}'
        : 'All Time';

    double totalIncome = 0;
    double totalExpense = 0;
    double totalNetProfit = 0;

    final displayedData = _summaryData.where((v) => _selectedVehicles.contains(v['vehicle_no'])).toList();

    for (var v in displayedData) {
      totalIncome += (v['trip_income'] as num).toDouble();
      totalExpense += (v['total_expense'] as num).toDouble();
      totalNetProfit += (v['net_profit'] as num).toDouble();
    }

    final bodyContent = Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: JarvisTheme.surface,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => data.selectDateRange(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: JarvisTheme.primary.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, size: 16, color: JarvisTheme.primary),
                          const SizedBox(width: 6),
                          Text('Date: $dateStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          const Icon(Icons.edit, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: JarvisTheme.primary),
                        tooltip: 'Generate PDF Report',
                        onPressed: _isLoading ? null : _generatePdfReport,
                      ),
                      IconButton(
                        icon: const Icon(Icons.grid_on, color: Colors.green),
                        tooltip: 'Export Excel',
                        onPressed: _isLoading ? null : _generateExcelReport,
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy, color: JarvisTheme.primary),
                        tooltip: 'Copy Summary to Clipboard',
                        onPressed: _isLoading ? null : _copySummaryToClipboard,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: JarvisTheme.primary),
                        tooltip: 'Refresh Data',
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Filter Vehicle: ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _showVehicleFilterDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _selectedVehicles.length == _summaryData.length
                                    ? 'All Vehicles'
                                    : _selectedVehicles.isEmpty
                                        ? 'No Vehicles Selected'
                                        : _selectedVehicles.join(', '),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              color: JarvisTheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('OVERALL SUMMARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryStat('Income', totalIncome, Colors.white),
                        _buildSummaryStat('Expenses', totalExpense, Colors.orangeAccent),
                        _buildSummaryStat('Net Profit', totalNetProfit, totalNetProfit >= 0 ? Colors.greenAccent : Colors.redAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : displayedData.isEmpty 
                  ? const Center(child: Text('No data for selected period or vehicle'))
                  : ListView.builder(
                      itemCount: displayedData.length,
                      itemBuilder: (context, index) {
                        final item = displayedData[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ExpansionTile(
                            title: Text(item['vehicle_no'], style: const TextStyle(fontWeight: FontWeight.bold, color: JarvisTheme.primary)),
                            subtitle: Text('Net Profit: ₹${item['net_profit'].toStringAsFixed(0)}', style: TextStyle(color: item['net_profit'] >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total Trips:'),
                                        Text('${item['total_trips']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Gross Income (Rent+Batta+Material):'),
                                        Text('₹${item['trip_income'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Trip Cost (Rent):'),
                                        Text('₹${item['rent_income'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Batta Amount:'),
                                        Text('₹${((item['batta_income'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Material Expense (Buy):'),
                                        Text('₹${item['material_expense'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.orange)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Fuel Expenses:'),
                                        Text('₹${item['fuel_expense'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.orange)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Maintenance:'),
                                        Text('₹${item['maintenance_expense'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.orange)),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Net Profit:', style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text('₹${item['net_profit'].toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: item['net_profit'] >= 0 ? Colors.green : Colors.red)),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      );

      if (widget.isEmbedded) {
        return bodyContent;
      }

      return Scaffold(
        backgroundColor: JarvisTheme.background,
        appBar: AppBar(
          title: const Text('VEHICLE SUMMARY'),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Generate PDF Report',
              onPressed: _isLoading ? null : _generatePdfReport,
            ),
            IconButton(
              icon: const Icon(Icons.grid_on),
              tooltip: 'Export Excel',
              onPressed: _isLoading ? null : _generateExcelReport,
            ),
            IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                data.selectDateRange(context);
                await Future.delayed(const Duration(milliseconds: 500));
                _loadData();
              },
            ),
            if (range != null)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  data.clearDateRange();
                  _loadData();
                },
              ),
          ],
        ),
        body: bodyContent,
      );
  }

  Widget _buildSummaryStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  void _showVehicleFilterDialog(BuildContext context) {
    final allVehicles = _summaryData.map((e) => e['vehicle_no'].toString()).toList();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAllSelected = _selectedVehicles.length == allVehicles.length;
            
            return AlertDialog(
              title: const Text('Select Vehicles', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    CheckboxListTile(
                      title: const Text('All', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAllSelected,
                      activeColor: JarvisTheme.primary,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedVehicles = Set.from(allVehicles);
                          } else {
                            _selectedVehicles.clear();
                          }
                        });
                      },
                    ),
                    const Divider(),
                    ...allVehicles.map((vNo) {
                      final isSelected = _selectedVehicles.contains(vNo);
                      return CheckboxListTile(
                        title: Text(vNo),
                        value: isSelected,
                        activeColor: JarvisTheme.primary,
                        onChanged: (val) {
                          setDialogState(() {
                            if (val == true) {
                              _selectedVehicles.add(vNo);
                            } else {
                              _selectedVehicles.remove(vNo);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {}); // refresh screen with filtered selections
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: JarvisTheme.primary, foregroundColor: Colors.white),
                  child: const Text('APPLY'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
