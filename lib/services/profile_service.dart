import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'database_service.dart';
import 'firestore_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._();

  factory ProfileService() => _instance;

  ProfileService._();

  static const String _activeProfileKey = 'active_profile_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentPhone => _auth.currentUser?.phoneNumber ?? '';

  // ─── Deterministic default profile ID ─────────────────────────────────────

  /// Returns the deterministic Firestore document ID for a user's default profile.
  /// Derived from the phone number so it is known immediately at login, with
  /// zero network calls.
  static String defaultProfileId(String phone) => 'default_$phone';

  /// Derives a 6-char share code from the phone number without any network call.
  /// Used only for the default profile. Custom profiles still use random codes.
  static String _deriveShareCode(String phone) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var hash = phone.hashCode.abs();
    final code = StringBuffer();
    for (int i = 0; i < 6; i++) {
      code.write(chars[hash % 36]);
      hash = (hash * 31 + i + 1) % 2147483647;
    }
    return code.toString();
  }

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Ensures the default profile document exists in Firestore.
  ///
  /// Uses `set(merge: true)` so it is fully idempotent — safe to call on every
  /// login. With offline persistence enabled, the write is applied to the local
  /// Firestore cache immediately (no network needed), so the profile appears in
  /// the real-time stream essentially instantly.
  Future<void> ensureDefaultProfileExists() async {
    final phone = _currentPhone;
    if (phone.isEmpty) return;

    final profileId = defaultProfileId(phone);
    final shareCode = _deriveShareCode(phone);

    await _firestore.collection('profiles').doc(profileId).set(
      {
        'name': 'Default',
        'isDefault': true,
        'isShareable': false,
        'shareCode': shareCode,
        'shareCodeActive': false,
        'createdBy': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'members': {phone: 'owner'},
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(phone).set(
      {
        'activeProfileId': profileId,
        'profiles': FieldValue.arrayUnion([profileId]),
      },
      SetOptions(merge: true),
    );
  }

  // ─── Profile CRUD ──────────────────────────────────────────────────────────

  /// Creates a new non-default profile and switches to it.
  Future<String> createProfile(
    String name, {
    bool isShareable = false,
  }) async {
    final phone = _currentPhone;
    if (phone.isEmpty) throw Exception('Not logged in');

    final shareCode = await _generateShareCode();
    final profileRef = _firestore.collection('profiles').doc();
    final profileId = profileRef.id;

    await profileRef.set({
      'name': name,
      'isDefault': false,
      'isShareable': isShareable,
      'shareCode': shareCode,
      'shareCodeActive': isShareable,
      'createdBy': phone,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {phone: 'owner'},
    });

    await _firestore.collection('users').doc(phone).set(
      {
        'activeProfileId': profileId,
        'profiles': FieldValue.arrayUnion([profileId]),
      },
      SetOptions(merge: true),
    );

    await switchProfile(profileId);
    return profileId;
  }

  /// Returns a real-time stream of all profiles the current user is a member of.
  Stream<List<ProfileModel>> getMyProfiles() {
    final phone = _currentPhone;
    if (phone.isEmpty) return Stream.value([]);

    return _firestore
        .collection('profiles')
        .where('members.$phone', isGreaterThanOrEqualTo: '')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ProfileModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  /// Switches the active profile, clears all caches, and persists choice.
  ///
  /// Wiping SQLite here is intentional: the SQLite database is profile-agnostic
  /// and would otherwise serve the previous profile's data as a fallback while
  /// Firestore loads the new profile's data.
  Future<void> switchProfile(String profileId) async {
    // Clear the SQLite cache first so it can never bleed the old profile's data
    // into the new profile context. Firestore's own offline persistence handles
    // true offline scenarios correctly without SQLite.
    try {
      await DatabaseService.deleteAllData();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProfileKey, profileId);
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

  /// Returns the ProfileModel for the active profile.
  Future<ProfileModel?> getActiveProfile() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    try {
      final doc = await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      return ProfileModel.fromMap(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user's role in the active profile ('owner' or 'member').
  Future<String?> getCurrentUserRole() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    return getRoleInProfile(profileId);
  }

  /// Returns the current user's role in a specific profile ('owner' or 'member').
  Future<String?> getRoleInProfile(String profileId) async {
    final phone = _currentPhone;
    if (phone.isEmpty) return null;
    try {
      final doc =
          await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      final members = doc.data()?['members'] as Map<String, dynamic>?;
      final raw = members?[phone] as String?;
      if (raw == null) return null;
      return raw == 'owner' ? 'owner' : 'member';
    } catch (_) {
      return null;
    }
  }

  // ─── Sharing ───────────────────────────────────────────────────────────────

  /// Joins a profile by its share code. New members join with the 'member' role.
  Future<ProfileModel> joinProfileByCode(String code) async {
    final phone = _currentPhone;
    if (phone.isEmpty) throw Exception('Not logged in');

    final trimmed = code.trim().toUpperCase();

    // Always query the Firestore server so we're not limited to what the local
    // offline cache already has (the joining device has never seen the profile).
    const serverOptions = GetOptions(source: Source.server);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('profiles')
          .where('shareCode', isEqualTo: trimmed)
          .limit(1)
          .get(serverOptions);
    } catch (_) {
      // Server unreachable — fall back to local cache as a best-effort attempt
      snap = await _firestore
          .collection('profiles')
          .where('shareCode', isEqualTo: trimmed)
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) {
      // Try legacy inviteCode field
      try {
        final legacySnap = await _firestore
            .collection('profiles')
            .where('inviteCode', isEqualTo: trimmed)
            .limit(1)
            .get(serverOptions);
        if (legacySnap.docs.isNotEmpty) {
          snap = legacySnap;
        }
      } catch (_) {
        final legacySnap = await _firestore
            .collection('profiles')
            .where('inviteCode', isEqualTo: trimmed)
            .limit(1)
            .get();
        if (legacySnap.docs.isNotEmpty) {
          snap = legacySnap;
        }
      }
    }

    if (snap.docs.isEmpty) {
      throw Exception(
        'No profile found with code "$trimmed". '
        'Make sure the code is correct and that the profile owner '
        'has sharing enabled.',
      );
    }

    final profileDoc = snap.docs.first;
    final data = profileDoc.data();
    final profileId = profileDoc.id;

    // Validate the code is currently active (only enforced for shareCode-based
    // profiles; legacy inviteCode profiles do not have this flag).
    final isShareCodeBased = data.containsKey('shareCode');
    if (isShareCodeBased) {
      final isActive = data['shareCodeActive'] as bool? ?? false;
      if (!isActive) {
        throw Exception(
          'This share code is not active. '
          'Ask the profile owner to enable sharing in Manage Profiles.',
        );
      }
    }

    final model = ProfileModel.fromMap(profileId, data);

    // Already a member — return as-is
    if (model.members.containsKey(phone)) {
      return model;
    }

    // Atomic write to prevent race conditions; all joiners are 'member'
    await _firestore.runTransaction((tx) async {
      final ref = _firestore.collection('profiles').doc(profileId);
      tx.update(ref, {'members.$phone': 'member'});
    });

    await _firestore.collection('users').doc(phone).set(
      {'profiles': FieldValue.arrayUnion([profileId])},
      SetOptions(merge: true),
    );

    return ProfileModel.fromMap(profileId, {
      ...data,
      'members': {...model.members, phone: 'member'},
    });
  }

  /// Renames a profile. Owner-only.
  Future<void> updateProfileName(String profileId, String newName) async {
    final role = await getRoleInProfile(profileId);
    if (role != 'owner') {
      throw Exception('Only the owner can rename this profile');
    }
    await _firestore
        .collection('profiles')
        .doc(profileId)
        .update({'name': newName});
  }

  /// Toggles the sharable state of a profile. Owner-only.
  /// When disabling, removes all non-owner members and notifies them.
  Future<void> toggleShareable(String profileId, bool isShareable) async {
    final phone = _currentPhone;
    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    if (!doc.exists) throw Exception('Profile not found');

    final data = doc.data()!;
    final members = data['members'] as Map<String, dynamic>? ?? {};
    if (members[phone] != 'owner') {
      throw Exception('Only the owner can change profile settings');
    }

    if (!isShareable) {
      // Revoking: atomically remove non-owner members and notify them
      final nonOwnerPhones = members.entries
          .where((e) => e.value != 'owner')
          .map((e) => e.key)
          .toList();

      final updatedMembers = Map<String, dynamic>.from(members);
      for (final mp in nonOwnerPhones) {
        updatedMembers.remove(mp);
      }

      final profileName = data['name']?.toString() ?? 'Profile';
      final batch = _firestore.batch();

      batch.update(_firestore.collection('profiles').doc(profileId), {
        'isShareable': false,
        'shareCodeActive': false,
        'members': updatedMembers,
      });

      for (final mp in nonOwnerPhones) {
        batch.set(
          _firestore.collection('users').doc(mp),
          {
            'profiles': FieldValue.arrayRemove([profileId]),
            'revokedProfiles': FieldValue.arrayUnion([
              {'id': profileId, 'name': profileName},
            ]),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
    } else {
      await _firestore.collection('profiles').doc(profileId).update({
        'isShareable': true,
        'shareCodeActive': true,
      });
    }
  }

  // ─── Membership ────────────────────────────────────────────────────────────

  /// Removes a member from a profile and notifies them. Owner-only.
  Future<void> removeMember(String profileId, String memberPhone) async {
    final myRole = await getRoleInProfile(profileId);
    if (myRole != 'owner') {
      throw Exception('Only the owner can remove members');
    }

    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    final profileName = doc.data()?['name']?.toString() ?? 'Profile';

    final batch = _firestore.batch();
    batch.update(_firestore.collection('profiles').doc(profileId), {
      'members.$memberPhone': FieldValue.delete(),
    });
    batch.set(
      _firestore.collection('users').doc(memberPhone),
      {
        'profiles': FieldValue.arrayRemove([profileId]),
        'revokedProfiles': FieldValue.arrayUnion([
          {'id': profileId, 'name': profileName},
        ]),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Leaves a shared profile. Non-owner only — owner must delete instead.
  Future<void> leaveProfile(String profileId) async {
    final phone = _currentPhone;
    if (phone.isEmpty) return;

    final role = await getRoleInProfile(profileId);
    if (role == 'owner') {
      throw Exception('Owner cannot leave. Delete the profile instead.');
    }

    await _firestore.collection('profiles').doc(profileId).update({
      'members.$phone': FieldValue.delete(),
    });

    await _firestore.collection('users').doc(phone).set(
      {'profiles': FieldValue.arrayRemove([profileId])},
      SetOptions(merge: true),
    );

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_activeProfileKey);
    if (current == profileId) {
      await _switchToDefaultProfile();
    }
  }

  /// Deletes a profile and all its data. Owner-only. Cannot delete default profile.
  Future<void> deleteProfile(String profileId) async {
    final phone = _currentPhone;
    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    if (!doc.exists) throw Exception('Profile not found');

    final data = doc.data()!;
    final members = data['members'] as Map<String, dynamic>? ?? {};
    if (members[phone] != 'owner') {
      throw Exception('Only the owner can delete this profile');
    }
    if (data['isDefault'] as bool? ?? false) {
      throw Exception('The default profile cannot be deleted');
    }

    final profileName = data['name']?.toString() ?? 'Profile';
    final nonOwnerPhones = members.entries
        .where((e) => e.value != 'owner')
        .map((e) => e.key)
        .toList();

    // Notify collaborators before deleting
    if (nonOwnerPhones.isNotEmpty) {
      final batch = _firestore.batch();
      for (final mp in nonOwnerPhones) {
        batch.set(
          _firestore.collection('users').doc(mp),
          {
            'profiles': FieldValue.arrayRemove([profileId]),
            'revokedProfiles': FieldValue.arrayUnion([
              {'id': profileId, 'name': profileName},
            ]),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }

    // Delete subcollections then the profile document
    for (final col in ['transactions', 'budgets', 'accounts', 'categories']) {
      await _deleteSubcollection(profileId, col);
    }
    await _firestore.collection('profiles').doc(profileId).delete();

    await _firestore.collection('users').doc(phone).set(
      {'profiles': FieldValue.arrayRemove([profileId])},
      SetOptions(merge: true),
    );

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_activeProfileKey);
    if (current == profileId) {
      await _switchToDefaultProfile();
    }
  }

  // ─── Revocation Notifications ──────────────────────────────────────────────

  /// Checks for profiles the user was removed from since last check.
  /// Clears the list and returns profile names for display in a popup.
  Future<List<String>> checkAndClearRevokedProfiles() async {
    final phone = _currentPhone;
    if (phone.isEmpty) return [];

    try {
      final doc = await _firestore.collection('users').doc(phone).get();
      if (!doc.exists) return [];

      final revokedRaw = doc.data()?['revokedProfiles'] as List? ?? [];
      if (revokedRaw.isEmpty) return [];

      final revokedNames = revokedRaw
          .map((e) =>
              (e as Map<String, dynamic>?)?['name']?.toString() ?? 'Unknown')
          .toList();

      final revokedIds = revokedRaw
          .map((e) =>
              (e as Map<String, dynamic>?)?['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Clear the revokedProfiles array atomically
      await _firestore.collection('users').doc(phone).update({
        'revokedProfiles': FieldValue.delete(),
      });

      // Switch to default if the active profile was revoked
      final activeId = await getActiveProfileId();
      if (activeId != null && revokedIds.contains(activeId)) {
        await _switchToDefaultProfile();
      }

      return revokedNames;
    } catch (_) {
      return [];
    }
  }

  // ─── Lookup helpers ────────────────────────────────────────────────────────

  /// Finds a profile ID by its identifier (phone number or share code)
  /// and verifies the current user has access to it.
  Future<String?> findProfileIdByIdentifier(
    String identifier,
    String profileName,
  ) async {
    final phone = _currentPhone;
    if (phone.isEmpty) return null;

    try {
      // Share code: 6-char alphanumeric
      if (identifier.length == 6 &&
          RegExp(r'^[A-Z0-9]+$').hasMatch(identifier.toUpperCase())) {
        final snap = await _firestore
            .collection('profiles')
            .where('shareCode', isEqualTo: identifier.toUpperCase())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final members =
              doc.data()['members'] as Map<String, dynamic>? ?? {};
          if (members.containsKey(phone)) return doc.id;
        }
        return null;
      }

      // Phone number: find a matching profile owned by that phone that the
      // current user is also a member of
      final snap = await _firestore
          .collection('profiles')
          .where('createdBy', isEqualTo: identifier)
          .where('members.$phone', isGreaterThanOrEqualTo: '')
          .get();

      for (final doc in snap.docs) {
        final name = doc.data()['name']?.toString() ?? '';
        if (name.trim().toLowerCase() == profileName.trim().toLowerCase()) {
          return doc.id;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Private helpers ───────────────────────────────────────────────────────

  Future<void> _switchToDefaultProfile() async {
    final phone = _currentPhone;
    if (phone.isEmpty) return;
    // The default profile ID is deterministic — no Firestore read required.
    await switchProfile(defaultProfileId(phone));
  }

  Future<String> _generateShareCode() async {
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
          .where('shareCode', isEqualTo: code)
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
