// memory_upload_service.dart

import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'encryption_service.dart';

class MemoryUploadService {
  static Future<String> uploadEncryptedMemory({
    required Uint8List plainData,
    required String capsuleId,
    required Uint8List aesKey,
    required String fileName, // e.g. note1.txt, image1.jpg
  }) async {
    final encData = EncryptionService.encryptDataAES(plainData, aesKey);
    final ref = FirebaseStorage.instance.ref().child("capsules/$capsuleId/$fileName");
    final uploadTask = await ref.putData(encData);
    return await uploadTask.ref.getDownloadURL();
  }
}
