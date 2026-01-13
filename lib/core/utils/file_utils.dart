import 'dart:typed_data';
import 'dart:io';

Future<Uint8List> fileToBytes(File file) async {
  return await file.readAsBytes();
}
