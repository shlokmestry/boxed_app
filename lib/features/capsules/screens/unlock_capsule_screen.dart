import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:boxed_app/core/services/boxed_encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';

class UnlockCapsuleScreen extends StatefulWidget {
  final String capsuleId;

  const UnlockCapsuleScreen({
    super.key,
    required this.capsuleId,
  });

  @override
  State<UnlockCapsuleScreen> createState() => _UnlockCapsuleScreenState();
}

class _UnlockCapsuleScreenState extends State<UnlockCapsuleScreen> {
  final List<String> _decryptedNotes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unlockAndDecrypt(widget.capsuleId);
  }

  Future<void> _unlockAndDecrypt(String capsuleId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not logged in';
          _loading = false;
        });
        return;
      }

      final capsuleDoc = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!capsuleDoc.exists) {
        setState(() {
          _error = 'Capsule not found';
          _loading = false;
        });
        return;
      }

      final capsuleData = capsuleDoc.data();
      if (capsuleData == null) {
        setState(() {
          _error = 'Capsule data empty';
          _loading = false;
        });
        return;
      }

      final capsuleKeys = capsuleData['capsuleKeys'];
      if (capsuleKeys is! Map) {
        setState(() {
          _error = 'capsuleKeys missing/invalid';
          _loading = false;
        });
        return;
      }

      final storedKeyValue = capsuleKeys[userId];
      if (storedKeyValue is! String || storedKeyValue.isEmpty) {
        setState(() {
          _error = 'You don’t have access to unlock this capsule.';
          _loading = false;
        });
        return;
      }

      // Decrypt capsule key (new format); fallback to legacy raw base64 bytes if needed.
      SecretKey capsuleKey;
      final userMasterKey = UserCryptoState.userMasterKeyOrNull;

      if (userMasterKey != null) {
        try {
          capsuleKey = await BoxedEncryptionService.decryptCapsuleKeyForUser(
            encryptedCapsuleKey: storedKeyValue,
            userMasterKey: userMasterKey,
          );
        } catch (_) {
          // Legacy fallback (old capsules stored raw base64 key bytes)
          capsuleKey = SecretKey(_tryBase64(storedKeyValue));
        }
      } else {
        // No master key loaded: only legacy fallback can work here.
        try {
          capsuleKey = SecretKey(_tryBase64(storedKeyValue));
        } catch (_) {
          setState(() {
            _error = 'Master key missing. Please log in again.';
            _loading = false;
          });
          return;
        }
      }

      // Load text memories and decrypt "content"
      final memorySnapshot = await FirebaseFirestore.instance
          .collection('capsules')
          .doc(capsuleId)
          .collection('memories')
          .where('type', isEqualTo: 'text')
          .orderBy('createdAt', descending: false)
          .get()
          .timeout(const Duration(seconds: 10));

      final List<String> out = [];

      for (final d in memorySnapshot.docs) {
        final data = d.data();
        final encrypted = (data['content'] ?? '').toString();
        if (encrypted.isEmpty) continue;

        try {
          final clear = await BoxedEncryptionService.decryptData(
            encryptedText: encrypted,
            capsuleKey: capsuleKey,
          );
          out.add(clear);
        } catch (_) {
          out.add('[Unable to decrypt]');
        }
      }

      if (!mounted) return;
      setState(() {
        _decryptedNotes
          ..clear()
          ..addAll(out);
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Loading timed out.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong: $e';
        _loading = false;
      });
    }
  }

  List<int> _tryBase64(String s) {
    // small helper so legacy fallback is explicit
    return List<int>.from(base64Decode(s));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text('Capsule Notes', style: textTheme.titleMedium),
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.background,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : (_decryptedNotes.isEmpty)
                  ? Center(
                      child: Text(
                        'No notes found.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.7),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _decryptedNotes.length,
                      itemBuilder: (context, index) => Card(
                        color: colorScheme.surface,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.note, color: colorScheme.primary),
                          title: Text(
                            _decryptedNotes[index],
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
