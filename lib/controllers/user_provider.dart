import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  String _role = 'STAFF'; // Default fallback
  String _nama = '';
  StreamSubscription<User?>? _authSubscription;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProvider() {
    _initAuthListener();
  }

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  User? get currentUser => _currentUser;
  String get role => _role;
  String get nama => _nama;
  bool get isAdmin => _role == 'ADMIN';
  String get email => _currentUser?.email ?? '';

  // ==========================================================================
  // INIT LISTENER
  // ==========================================================================

  void _initAuthListener() {
    _authSubscription = _auth.authStateChanges().listen((User? user) async {
      _currentUser = user;

      if (user != null && user.email != null) {
        await _fetchUserData(user.email!);
      } else {
        _role = 'STAFF';
        _nama = '';
      }

      notifyListeners();
    });
  }

  // ==========================================================================
  // FETCH FIRESTORE USER DATA
  // ==========================================================================

  Future<void> _fetchUserData(String email) async {
    try {
      final doc = await _db.collection('users').doc(email).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _role = data['role'] as String? ?? 'STAFF';
        _nama = data['nama'] as String? ?? 'User Tidak Dikenal';
      } else {
        // Jika dokumen tidak ada, kita buatkan data default agar aplikasi tidak crash
        _role = 'STAFF';
        _nama = email.split('@').first; // Ambil nama dari email sementara
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      _role = 'STAFF';
    }
  }

  // ==========================================================================
  // LOGOUT
  // ==========================================================================

  Future<void> logout() async {
    await _auth.signOut();
    _currentUser = null;
    _role = 'STAFF';
    _nama = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
