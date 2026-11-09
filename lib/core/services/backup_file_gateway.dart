import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Moves backup files in and out of the app through the system file dialogs
/// (Storage Access Framework on Android, Files on iOS), so no storage
/// permission is needed. Kept separate so tests can substitute it.
class BackupFileGateway {
  const BackupFileGateway();

  /// Asks the user where to save [bytes]. Returns false if they cancelled.
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save Aegymer backup',
    );
    return uri != null;
  }

  /// Lets the user choose a backup file. Returns null if they cancelled.
  Future<Uint8List?> pick() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Choose an Aegymer backup');
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }
}
