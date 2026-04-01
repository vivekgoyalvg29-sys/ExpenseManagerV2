import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firestore_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._();

  factory ProfileService() => _instance;

  ProfileService._();

  static const String _activeProfileKey = 'active_profile_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentPhone => _auth.currentUser?.phoneNumber ?? '';

  /// Creates a new profile and sets it as the active profile.
  Future<String> createProfile(String name) async {
    final phone = _currentPhone;
    if (phone.isEmpty) throw Exception('Not logged in');

    final inviteCode = await generateInviteCode();
    final profileRef = _firestore.collection('profiles').doc();
    final profileId = profileRef.id;

    await profileRef.set({
      'name': name,
      'createdBy': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'inviteCode': inviteCode,
      'members': {phone: 'owner'},
    });

    await _firestore.collection('users').doc(phone).set({
      'activeProfileId': profileId,
      'profiles': FieldValue.arrayUnion([profileId]),
    }, SetOptions(merge: true));

    await switchProfile(profileId);
    return profileId;
  }

  /// Returns a stream of all profiles where the current user is a member.
  Stream<List<Map<String, dynamic>>> getMyProfiles() {
    final phone = _currentPhone;
    if (phone.isEmpty) return Stream.value([]);

    return _firestore
        .collection('profiles')
        .where('members.$phone', isGreaterThanOrEqualTo: '')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => <String, dynamic>{'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Switches the active profile and updates SharedPreferences + Firestore.
  Future<void> switchProfile(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
    // Clear cached doc IDs when profile changes
    FirestoreService().clearCaches();
    try {
      final phone = _currentPhone;
      if (phone.isNotEmpty) {
        await _firestore.collection('users').doc(phone).set(
          {'activeProfileId': profileId},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  /// Gets the active profile ID from SharedPreferences, falling back to Firestore.
  Future<String?> getActiveProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_activeProfileKey);
    if (cached != null && cached.isNotEmpty) return cached;

    final phone = _currentPhone;
    if (phone.isEmpty) return null;

    try {
      final doc = await _firestore.collection('users').doc(phone).get();
      if (doc.exists) {
        final activeId = doc.data()?['activeProfileId'] as String?;
        if (activeId != null && activeId.isNotEmpty) {
          await prefs.setString(_activeProfileKey, activeId);
          return activeId;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Returns the full profile document for the active profile.
  Future<Map<String, dynamic>?> getActiveProfile() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    try {
      final doc = await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user's role in the active profile.
  Future<String?> getCurrentUserRole() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    final phone = _currentPhone;
    if (phone.isEmpty) return null;
    try {
      final doc =
          await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      final members = doc.data()?['members'] as Map<String, dynamic>?;
      return members?[phone] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Joins a profile by its 6-character invite code. Returns the profile name.
  Future<String> joinProfileByCode(String inviteCode) async {
    final phone = _currentPhone;
    if (phone.isEmpty) throw Exception('Not logged in');

    final snap = await _firestore
        .collection('profiles')
        .where('inviteCode', isEqualTo: inviteCode.trim().toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('No profile found with this invite code');
    }

    final profileDoc = snap.docs.first;
    final profileId = profileDoc.id;
    final profileName =
        profileDoc.data()['name'] as String? ?? 'Shared Profile';

    // Check if user is already a member
    final members =
        profileDoc.data()['members'] as Map<String, dynamic>? ?? {};
    if (members.containsKey(phone)) {
      return profileName; // Already a member
    }

    await profileDoc.reference.update({'members.$phone': 'viewer'});

    await _firestore.collection('users').doc(phone).set({
      'profiles': FieldValue.arrayUnion([profileId]),
    }, SetOptions(merge: true));

    return profileName;
  }

  /// Updates the profile name. Only owners can call this.
  Future<void> updateProfileName(String profileId, String newName) async {
    final myRole = await getCurrentUserRole();
    if (myRole != 'owner') {
      throw PermissionException('Only the owner can rename this profile');
    }
    await _firestore.collection('profiles').doc(profileId).update({'name': newName});
  }

  /// Updates a member's role. Only owners can call this.
  Future<void> updateMemberRole(
    String profileId,
    String memberPhone,
    String role,
  ) async {
    final myRole = await getCurrentUserRole();
    if (myRole != 'owner') {
      throw PermissionException('Only the owner can change member roles');
    }
    await _firestore
        .collection('profiles')
        .doc(profileId)
        .update({'members.$memberPhone': role});
  }

  /// Removes a member from a profile. Only owners can call this.
  Future<void> removeMember(String profileId, String memberPhone) async {
    final myRole = await getCurrentUserRole();
    if (myRole != 'owner') {
      throw PermissionException('Only the owner can remove members');
    }
    await _firestore.collection('profiles').doc(profileId).update({
      'members.$memberPhone': FieldValue.delete(),
    });
    try {
      await _firestore.collection('users').doc(memberPhone).update({
        'profiles': FieldValue.arrayRemove([profileId]),
      });
    } catch (_) {}
  }

  /// Removes the current user from a profile.
  Future<void> leaveProfile(String profileId) async {
    final phone = _currentPhone;
    if (phone.isEmpty) return;

    await _firestore.collection('profiles').doc(profileId).update({
      'members.$phone': FieldValue.delete(),
    });

    try {
      await _firestore.collection('users').doc(phone).update({
        'profiles': FieldValue.arrayRemove([profileId]),
      });
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_activeProfileKey);
    if (current == profileId) {
      await prefs.remove(_activeProfileKey);
    }
  }

  /// Deletes a profile entirely. Only owners can call this.
  Future<void> deleteProfile(String profileId) async {
    final myRole = await getCurrentUserRole();
    if (myRole != 'owner') {
      throw PermissionException('Only the owner can delete this profile');
    }

    final phone = _currentPhone;
    for (final col in ['transactions', 'budgets', 'accounts', 'categories']) {
      await _deleteSubcollection(profileId, col);
    }
    await _firestore.collection('profiles').doc(profileId).delete();

    try {
      await _firestore.collection('users').doc(phone).update({
        'profiles': FieldValue.arrayRemove([profileId]),
        'activeProfileId': FieldValue.delete(),
      });
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_activeProfileKey);
    if (current == profileId) {
      await prefs.remove(_activeProfileKey);
    }
  }

  /// Generates a unique 6-character alphanumeric invite code.
  Future<String> generateInviteCode() async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    while (true) {
      final code = String.fromCharCodes(
        Iterable.generate(
          6,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
      final snap = await _firestore
          .collection('profiles')
          .where('inviteCode', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return code;
    }
  }

  Future<void> _deleteSubcollection(
    String profileId,
    String collectionName,
  ) async {
    final col = _firestore
        .collection('profiles')
        .doc(profileId)
        .collection(collectionName);
    QuerySnapshot<Map<String, dynamic>> snap;
    do {
      snap = await col.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == 400);
  }
}
