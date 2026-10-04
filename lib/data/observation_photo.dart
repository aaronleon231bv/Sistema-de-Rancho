import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

/// Stored with the observation, rather than referencing a temporary picker file.
class ObservationPhoto {
  const ObservationPhoto({required this.name, required this.bytes});

  static const maxBytes = 5 * 1024 * 1024;
  final String name;
  final Uint8List bytes;

  Map<String, dynamic> toJson() => {
    'name': name,
    'base64': base64Encode(bytes),
  };

  static ObservationPhoto? fromJson(dynamic value) {
    if (value is! Map || value['base64'] is! String) return null;
    try {
      return ObservationPhoto(
        name: value['name'] as String? ?? 'Fotografía',
        bytes: base64Decode(value['base64'] as String),
      );
    } on FormatException {
      return null;
    }
  }

  static Future<ObservationPhoto> fromFile(XFile file) async {
    if (await file.length() > maxBytes) {
      throw const FormatException(
        'La fotografía supera 5 MB. Selecciona una imagen más pequeña.',
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException(
        'Selecciona una fotografía válida de hasta 5 MB.',
      );
    }
    // Validate actual image data before replacing the current attachment.
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 1600,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    } catch (_) {
      throw const FormatException(
        'No se pudo leer la fotografía. Prueba con una imagen JPG o PNG.',
      );
    }
    return ObservationPhoto(name: file.name, bytes: bytes);
  }
}

Future<ObservationPhoto?> pickObservationPhoto() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 80,
    requestFullMetadata: false,
  );
  return file == null ? null : ObservationPhoto.fromFile(file);
}
