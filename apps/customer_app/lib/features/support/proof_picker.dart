import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A file the customer chose to send with a ticket.
class PickedProof {
  const PickedProof({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Opens the device's file chooser. Tests replace it with a fixed answer.
typedef ProofPicker = Future<PickedProof?> Function();

final proofPickerProvider = Provider<ProofPicker>(
  (ref) => () async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'pdf', 'txt'],
      withData: true,
    );
    final file = picked?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    return PickedProof(name: file.name, bytes: bytes);
  },
);
