import 'package:flutter/material.dart';
import 'package:boxed_app/services/capsule_service.dart';

enum CapsuleLoadState {
  idle,
  loading,
  empty,
  ready,
  error,
}

class CapsuleController extends ChangeNotifier {
  CapsuleLoadState _state = CapsuleLoadState.idle;
  CapsuleLoadState get state => _state;

  List<Map<String, dynamic>> _capsules = [];
  List<Map<String, dynamic>> get capsules => _capsules;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }


  Future<void> loadCapsules(String userId) async {
    _state = CapsuleLoadState.loading;
    _error = null;
    _safeNotify();

    try {
      final result =
          await CapsuleService.fetchUserCapsules(userId);

      if (result.isEmpty) {
        _capsules = [];
        _state = CapsuleLoadState.empty;
      } else {
        _capsules = result;
        _state = CapsuleLoadState.ready;
      }
    } catch (e) {
      _error = e.toString();
      _state = CapsuleLoadState.error;
    }

    _safeNotify();
  }

  void clear() {
    _capsules = [];
    _state = CapsuleLoadState.idle;
    _error = null;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
