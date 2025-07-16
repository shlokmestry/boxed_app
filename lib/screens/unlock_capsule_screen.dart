import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:boxed_app/services/encryption_service.dart';

class UnlockCapsuleScreen extends StatefulWidget {
  final String capsuleId;

  const UnlockCapsuleScreen({super.key, required this.capsuleId});

  @override
  State<UnlockCapsuleScreen> createState() => _UnlockCapsuleScreenState();
}

class _UnlockCapsuleScreenState extends State<UnlockCapsuleScreen> {
  List<String> decryptedMemories = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _unlockAndDecryptCapsule(widget.capsuleId);
  }

  Future<void> _unlockAndDecryptCapsule(String capsuleId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        setState(() {
          error = 'User not logged in';
          loading = false;
        });
        return;
      }

      // 🔒 STEP 1. Get capsule data
      final capsuleDoc = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .get();

      if (!capsuleDoc.exists) {
        setState(() {
          error = 'Capsule not found';
          loading = false;
        });
        return;
      }

      final capsuleData = capsuleDoc.data()!;
      final encryptedKeyBase64 = capsuleData['capsuleKeys']?[userId];

      if (encryptedKeyBase64 == null) {
        setState(() {
          error = 'You don’t have access to unlock this capsule.';
          loading = false;
        });
        return;
      }

      // 🔐 STEP 2. Get private key from secure storage
      final privateKeyPem = await EncryptionService.getPrivateKey();

      if (privateKeyPem == null) {
        setState(() {
          error = 'Private key missing on this device.';
          loading = false;
        });
        return;
      }

      // 🧠 STEP 3. Decrypt AES key
      final aesKey = EncryptionService.decryptCapsuleKey(
        encryptedKeyBase64,
        privateKeyPem,
      );

      // 📥 STEP 4. Fetch encrypted memories from subcollection
      final memorySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .collection('memories')
          .get();

      final List<String> tempDecrypted = [];

      for (final doc in memorySnapshot.docs) {
        final encryptedBase64 = doc.data()['encryptedBytes'];

        if (encryptedBase64 == null) continue;

        final encryptedBytes = Uint8List.fromList(base64Decode(encryptedBase64));
        final decryptedBytes = EncryptionService.decryptDataAES(
          encryptedBytes,
          Uint8List.fromList(aesKey),
        );

        try {
          final result = utf8.decode(decryptedBytes);
          tempDecrypted.add(result);
        } catch (e) {
          tempDecrypted.add('📁 [Binary/Media Memory]');
        }
      }

      setState(() {
        decryptedMemories = tempDecrypted;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Something went wrong: $e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('🕰️ Capsule Memories'),
        backgroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: decryptedMemories.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const Icon(Icons.note, color: Colors.white),
                    title: Text(
                      decryptedMemories[index],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
    );
  }
}
