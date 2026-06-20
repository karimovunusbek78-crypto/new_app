import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Provider for managing Car Sell publication permissions.
/// 
/// States:
/// - null: Loading
/// - true: User has permission to publish car listings
/// - false: User needs permission
class CarSellPermissionNotifier extends ChangeNotifier {
  bool? _canPublish;

  bool? get canPublish => _canPublish;

  /// Loads the user's publication permission from Firestore.
  /// 
  /// Checks the 'canPublish' field in the users collection.
  /// Updates listeners when complete.
  Future<void> loadPermission() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Not logged in
    if (user == null) {
      _canPublish = false;
      notifyListeners();
      return;
    }
    
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _canPublish = snap.data()?['canPublish'] == true;
    } catch (e) {
      // Firestore error - assume no permission
      _canPublish = false;
    }
    
    notifyListeners();
  }

  /// Manually set the permission state (for testing or admin actions).
  void setPermission(bool value) {
    _canPublish = value;
    notifyListeners();
  }

  /// Refresh permission from Firestore.
  Future<void> refreshPermission() async {
    _canPublish = null;
    notifyListeners();
    await loadPermission();
  }
}