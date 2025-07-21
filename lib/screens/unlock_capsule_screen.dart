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

      final privateKeyPem = await EncryptionService.getPrivateKey();

      if (privateKeyPem == null) {
        setState(() {
          error = 'Private key missing on this device.';
          loading = false;
        });
        return;
      }

      final aesKey = EncryptionService.decryptCapsuleKey(
        encryptedKeyBase64,
        privateKeyPem,
      );

      final memorySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .collection('memories')
          .get();

      final List<String> tempDecrypted = [];

      for (final doc in memorySnapshot.docs) {
        final encryptedBase64 = doc.data()['encryptedBytes'];
        if (encryptedBase64 == null) continue;

        try {
          final encryptedBytes = Uint8List.fromList(base64Decode(encryptedBase64));
          final decryptedBytes = EncryptionService.decryptDataAES(
            encryptedBytes,
            Uint8List.fromList(aesKey),
          );
          final result = utf8.decode(decryptedBytes);
          tempDecrypted.add(result);
        } catch (_) {
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text("🕰️ Capsule Memories", style: textTheme.titleMedium),
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.background,
        elevation: 0,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error!,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: decryptedMemories.length,
                  itemBuilder: (context, index) => Card(
                    color: colorScheme.surface,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.note, color: colorScheme.primary),
                      title: Text(
                        decryptedMemories[index],
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}
