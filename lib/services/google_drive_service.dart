import 'dart:io';

// Actually, for Desktop, googleapis_auth with clientViaUserConsent is standard.
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;

class GoogleDriveService {
  // Scopes required for the app
  static final _scopes = [drive.DriveApi.driveFileScope];

  // Authenticated HTTP client
  AuthClient? _authClient;
  
  // Drive API instance
  drive.DriveApi? _driveApi;

  // Method to Authenticate
  Future<void> authenticate(String clientId, String clientSecret) async {
    print("GoogleDriveService: authenticate called");
    final identifier = ClientId(clientId, clientSecret);
    
    // This will print a URL to the console (or we can launch it)
    // For Desktop apps, we provide a callback to open the URL.
    try {
      print("GoogleDriveService: requesting consent...");
      _authClient = await clientViaUserConsent(identifier, _scopes, (url) {
        print("GoogleDriveService: opening URL -> $url");
        _launchURL(url);
      });
      print("GoogleDriveService: authenticated successfully");
      _driveApi = drive.DriveApi(_authClient!);
    } catch (e) {
      print("GoogleDriveService: authentication failed -> $e");
      rethrow;
    }
  }

  // Check if authenticated
  bool get isAuthenticated => _authClient != null;

  // Upload Backup
  Future<String?> uploadBackup(File file) async {
    if (_driveApi == null) return "Not Authenticated";

    try {
      final fileName = path.basename(file.path);
      
      final driveFile = drive.File();
      driveFile.name = fileName;
      // You can specify a folder ID here if you want to organize backups
      // driveFile.parents = ['appDataFolder']; // or specific folder ID
      
      final media = drive.Media(file.openRead(), await file.length());
      
      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );
      
      return null; // Success
    } catch (e) {
      return "Upload Failed: $e";
    }
  }

  // List Backups
  Future<List<drive.File>> listBackups() async {
    if (_driveApi == null) throw Exception("Not Authenticated");
    
    // Filter for files with 'backup_' in name
    final fileList = await _driveApi!.files.list(
      q: "name contains 'backup_'",
      $fields: "files(id, name, createdTime, size)",
      orderBy: "createdTime desc"
    );
    
    return fileList.files ?? [];
  }

  // Download Backup
  Future<File?> downloadBackup(String fileId, String savePath) async {
    if (_driveApi == null) throw Exception("Not Authenticated");

    final drive.Media? response = await _driveApi!.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media?;

    if (response == null) return null;

    final List<int> dataStore = [];
    await response.stream.listen((data) {
      dataStore.addAll(data);
    }).asFuture();

    final file = File(savePath);
    await file.writeAsBytes(dataStore);
    return file;
  }

  // Helper to open URL
  Future<void> _launchURL(String url) async {
    print("GoogleDriveService: _launchURL called with $url");
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      print("GoogleDriveService: launching URL...");
      await launchUrl(uri);
    } else {
      print("GoogleDriveService: could not launch URL");
      throw 'Could not launch $url';
    }
  }
}
