import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../theme.dart';
import '../data/data_provider.dart';

class PrintSettingsScreen extends StatefulWidget {
  const PrintSettingsScreen({super.key});

  @override
  State<PrintSettingsScreen> createState() => _PrintSettingsScreenState();
}

class _PrintSettingsScreenState extends State<PrintSettingsScreen> {
  final _ipController = TextEditingController();
  String _printerType = 'System'; // Default to System
  String _paperSize = '58mm';
  bool _autoPrint = false;
  bool _isLoading = true;
  
  List<Printer> _printers = [];
  Printer? _selectedPrinter;

  final List<String> _printerTypes = ['System', 'Network', 'Bluetooth', 'USB']; // Added System
  final List<String> _paperSizes = ['58mm', '80mm', 'A4'];

  @override
  void initState() {
    super.initState();
    _scanPrinters();
    _loadSettings();
  }
  
  Future<void> _scanPrinters() async {
    final printers = await Printing.listPrinters();
    setState(() {
      _printers = printers;
    });
  }

  Future<void> _loadSettings() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    // Load individual settings
    String? type = await provider.getSetting('printer_type');
    String? ip = await provider.getSetting('printer_ip');
    String? size = await provider.getSetting('paper_size');
    String? auto = await provider.getSetting('auto_print');
    
    // Load System Printer
    String? savedPrinterName = await provider.getSetting('selected_printer');

    if (mounted) {
      setState(() {
        if (type != null && _printerTypes.contains(type)) _printerType = type;
        if (ip != null) _ipController.text = ip;
        if (size != null && _paperSizes.contains(size)) _paperSize = size;
        if (auto != null) _autoPrint = auto == 'true';
        
        // Match Saved Printer
        if (savedPrinterName != null && _printers.isNotEmpty) {
           try {
             _selectedPrinter = _printers.firstWhere((p) => p.name == savedPrinterName);
           } catch (_) {}
        }
        
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DataProvider>(context, listen: false);

    await provider.setSetting('printer_type', _printerType);
    await provider.setSetting('printer_ip', _ipController.text);
    await provider.setSetting('paper_size', _paperSize);
    await provider.setSetting('auto_print', _autoPrint.toString());
    
    // Save Printer Selection
    if (_selectedPrinter != null) {
       await provider.setSetting('selected_printer', _selectedPrinter!.name);
       await provider.setSetting('selected_printer_url', _selectedPrinter!.url);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Print Settings Saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JarvisTheme.background,
      appBar: AppBar(
        title: const Text('PRINT SETTINGS'),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('CONFIGURATION'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _printerType,
                        decoration: const InputDecoration(labelText: 'Printer Type', border: OutlineInputBorder()),
                        items: _printerTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _printerType = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_printerType == 'System') ...[
                         if (_printers.isEmpty)
                           const Padding(
                             padding: EdgeInsets.only(bottom: 16),
                             child: Text('No printers found. Make sure drivers are installed.', style: TextStyle(color: Colors.red)),
                           ),
                         DropdownButtonFormField<Printer>(
                          initialValue: _selectedPrinter,
                          decoration: const InputDecoration(labelText: 'Select Printer', border: OutlineInputBorder()),
                          items: _printers.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                          onChanged: (val) => setState(() => _selectedPrinter = val),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_printerType == 'Network') ...[
                        TextField(
                          controller: _ipController,
                          decoration: const InputDecoration(
                            labelText: 'Printer IP Address',
                            border: OutlineInputBorder(),
                            hintText: '192.168.1.200'
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: _paperSize,
                        decoration: const InputDecoration(labelText: 'Paper Size', border: OutlineInputBorder()),
                        items: _paperSizes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _paperSize = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Auto Print Receipts'),
                        subtitle: const Text('Automatically print after saving entry'),
                        value: _autoPrint,
                        activeThumbColor: JarvisTheme.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _autoPrint = val),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: JarvisTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('SAVE SETTINGS'),
                        onPressed: _saveSettings,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.print),
                        label: const Text('TEST PRINT'),
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test print sent...')),
                           );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: JarvisTheme.textSecondary,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
