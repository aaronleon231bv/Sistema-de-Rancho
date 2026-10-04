import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const maxBackupBytes = 100 * 1024 * 1024;

Future<bool> saveBackupFile(String content) async {
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final result = await FilePicker.saveFile(
    dialogTitle: 'Guardar respaldo de la bitácora',
    fileName: 'bitacora-$stamp.json',
    type: FileType.custom,
    allowedExtensions: ['json'],
    bytes: Uint8List.fromList(utf8.encode(content)),
    mimeType: 'application/json',
  );
  return result != null;
}

Future<String?> pickBackupFile() async {
  final file = await FilePicker.pickFile(
    dialogTitle: 'Seleccionar respaldo de la bitácora',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (file == null) return null;
  if ((await file.length() ?? 0) > maxBackupBytes) {
    throw const FormatException('El respaldo supera el límite de 100 MB.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > maxBackupBytes) {
    throw const FormatException('El respaldo supera el límite de 100 MB.');
  }
  return utf8.decode(bytes);
}

Future<bool> saveReportFile(Uint8List bytes, String extension) async =>
    await FilePicker.saveFile(
      fileName: 'reporte-bitacora.$extension',
      bytes: bytes,
      dialogTitle: 'Guardar reporte de la bitácora',
      mimeType: extension == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ) !=
    null;
