import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import '../data/data_provider.dart';
import '../data/database_helper.dart';
// Or LoginScreen for logout
import 'login_screen.dart';

class SystemDiagnosticsScreen extends StatefulWidget {
  const SystemDiagnosticsScreen({super.key});

  @override
  State<SystemDiagnosticsScreen> createState() => _SystemDiagnosticsScreenState();
}

class _SystemDiagnosticsScreenState extends State<SystemDiagnosticsScreen> {
  bool _checking = true;
  bool _internetOk = false;
  bool _dbOk = false;
  bool _driveOk = false;
  String? _dbError;

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() => _checking = true);

    // 1. Internet
    try {
      final result = await InternetAddress.lookup('google.com');
      _internetOk = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      _internetOk = false;
    }

    // 2. Database
    try {
      final db = await DatabaseHelper().database;
      _dbOk = db.isOpen;
    } catch (e) {
      _dbOk = false;
      _dbError = e.toString();
    }

    // 3. Drive (Mock check for setting)
    try {
      final provider = Provider.of<DataProvider>(context, listen: false);
      final clientId = await provider.getSetting('google_client_id');
      final clientSecret = await provider.getSetting('google_client_secret');
      _driveOk = clientId != null && clientId.isNotEmpty && clientSecret != null && clientSecret.isNotEmpty;
    } catch (_) {
      _driveOk = false;
    }

    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Hacker/System feel
      appBar: AppBar(
        title: const Text('AANDAVAR DIAGNOSTICS'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.greenAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_checking)
              const LinearProgressIndicator(color: Colors.greenAccent),
            const SizedBox(height: 20),
            _buildCheckItem('Internet Connection', _internetOk),
            _buildCheckItem('Database Integrity', _dbOk, error: _dbOk ? null : _dbError),
            _buildCheckItem('Cloud/Drive Sync', _driveOk),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton('DEV BRANDING', Icons.code, _showDevBranding),
                _buildActionButton('BIZ SETTINGS', Icons.business, _showBizSettings),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('SYSTEM LOGOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                   Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool status, {String? error}) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            trailing: Icon(
              status ? Icons.check_circle : Icons.warning,
              color: status ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SelectableText(
                'Error: $error',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Future<void> _showDevBranding() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    String? name = await provider.getSetting('dev_name');
    String? contact = await provider.getSetting('dev_contact');
    String? email = await provider.getSetting('dev_email');
    String? logoPath = await provider.getSetting('dev_logo_path');

    final nameCtrl = TextEditingController(text: name);
    final contactCtrl = TextEditingController(text: contact);
    final emailCtrl = TextEditingController(text: email);
    
    // Local state for the dialog
    String? currentLogoPath = logoPath;

    if (!mounted) return;

    await showDialog(
      context: context, 
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Developer Branding'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Developer Name')),
                  const SizedBox(height: 16),
                  
                  // Logo Selection
                  Row(
                    children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: currentLogoPath != null && File(currentLogoPath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(currentLogoPath!), fit: BoxFit.cover),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate),
                          label: const Text('Add Photo'),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(type: FileType.image);
                            if (result != null && result.files.single.path != null) {
                              final sourceFile = File(result.files.single.path!);
                              // Copy to App Doc Dir
                              final appDir = await getApplicationDocumentsDirectory();
                              final fileName = 'dev_logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourceFile.path)}';
                              final savedImage = await sourceFile.copy('${appDir.path}/$fileName');
                              
                              setState(() {
                                currentLogoPath = savedImage.path;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (currentLogoPath != null)
                     Padding(
                       padding: const EdgeInsets.only(top: 4),
                       child: Text(
                         p.basename(currentLogoPath!),
                         style: const TextStyle(fontSize: 10, color: Colors.grey),
                         maxLines: 1, overflow: TextOverflow.ellipsis,
                       ),
                     ),

                  const SizedBox(height: 16),
                  TextField(controller: contactCtrl, decoration: const InputDecoration(labelText: 'Contact Number')),
                  const SizedBox(height: 12),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email / Website')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () {
                  provider.setSetting('dev_name', nameCtrl.text);
                  if (currentLogoPath != null) provider.setSetting('dev_logo_path', currentLogoPath!);
                  provider.setSetting('dev_contact', contactCtrl.text);
                  provider.setSetting('dev_email', emailCtrl.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Developer Info Updated')));
                }, 
                child: const Text('SAVE')
              ),
            ],
          );
        }
      ),
    );
  }
  
  Future<void> _showBizSettings() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    
    String? name = await provider.getSetting('business_name');
    String? logoPath = await provider.getSetting('business_logo_path');
    
    final nameCtrl = TextEditingController(text: name);
    
    // Local state for the dialog
    String? currentLogoPath = logoPath;

    if (!mounted) return;

    await showDialog(
      context: context, 
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Business Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Business Name')),
                  const SizedBox(height: 16),
                  
                  // Logo Selection
                  Row(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[900],
                        ),
                        child: currentLogoPath != null && File(currentLogoPath!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(File(currentLogoPath!), fit: BoxFit.cover),
                              )
                            : const Icon(Icons.add_business, color: Colors.grey, size: 40),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Choose Logo'),
                              onPressed: () async {
                                try {
                                  final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                  if (result != null && result.files.single.path != null) {
                                    final sourceFile = File(result.files.single.path!);
                                    // Copy to App Doc Dir
                                    final appDir = await getApplicationDocumentsDirectory();
                                    final fileName = 'business_logo_${DateTime.now().millisecondsSinceEpoch}${p.extension(sourceFile.path)}';
                                    final savedImage = await sourceFile.copy('${appDir.path}/$fileName');
                                    
                                    setState(() {
                                      currentLogoPath = savedImage.path;
                                    });
                                  }
                                } catch (e) {
                                  debugPrint("Error picking file: $e");
                                }
                              },
                            ),
                            if (currentLogoPath != null)
                               Padding(
                                 padding: const EdgeInsets.only(top: 4),
                                 child: Text(
                                   p.basename(currentLogoPath!),
                                   style: const TextStyle(fontSize: 10, color: Colors.grey),
                                   textAlign: TextAlign.center,
                                   maxLines: 1, overflow: TextOverflow.ellipsis,
                                 ),
                               ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                onPressed: () {
                   if(nameCtrl.text.isNotEmpty) provider.setSetting('business_name', nameCtrl.text);
                   if(currentLogoPath != null) provider.setSetting('business_logo_path', currentLogoPath!);
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business Settings Saved')));
                }, 
                child: const Text('SAVE')
              ),
            ],
          );
        }
      ),
    );
  }
}
