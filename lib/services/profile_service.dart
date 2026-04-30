import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models.dart';
import 'data_store.dart';
import 'database_service.dart';
import 'firestore_service.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._();

  factory ProfileService() => _instance;

  ProfileService._();

  static const String _activeProfileKey = 'active_profile_id';

  /// Last Firebase [User.uid] that [active_profile_id] was validated for.
  /// Without this, switching accounts reuses the previous user's profile id from prefs.
  static const String _prefsUidKey = 'profile_prefs_uid';

  /// On-device private profile when the user is not signed into Firebase.
  static const String localPrivateProfileId = 'local_private';

  /// Synthetic "member" key for [localPrivateProfileModel] (not a phone number).
  static const String localDeviceMemberKey = '__local_device__';

  static final ProfileModel localPrivateProfileModel = ProfileModel(
    id: localPrivateProfileId,
    name: 'Private',
    isDefault: true,
    isShareable: false,
    shareCode: '',
    shareCodeActive: false,
    createdBy: '',
    members: {localDeviceMemberKey: 'owner'},
  );

  static const String _localProfilesJsonKey = 'local_profiles_json_v1';

  /// In-memory copy of the last resolved active profile id (for sync data routing).
  String? _cachedActiveProfileId;

  /// Cloud profile IDs where SQLite is source of truth (owner made book private).
  static const String _cloudSqlitePrimaryKey = 'cloud_profile_sqlite_primary_v1';
  final Set<String> _cloudIdsSqlitePrimary = {};

  String? get cachedActiveProfileId => _cachedActiveProfileId;

  /// Whether [profileId] is a Firestore profile that reads/writes SQLite only.
  bool usesSqlitePrimaryForCloudProfile(String profileId) =>
      _cloudIdsSqlitePrimary.contains(profileId);

  /// True when the active book is a multi-user shared cloud profile (owner with
  /// sharing on, or a joined member). Private on-device books and solo cloud
  /// books return false. Used to gate pull-to-refresh on the records page.
  Future<bool> activeProfileIsSharedCollaborationBook() async {
    if (!AppConfig.firebaseCloudEnabled) return false;
    final uid = _cloudUid;
    if (uid.isEmpty) return false;
    final id = await getActiveProfileId();
    if (id == null || id.isEmpty || isLocalProfileId(id)) return false;
    if (usesSqlitePrimaryForCloudProfile(id)) return false;
    try {
      final doc = await _firestore.collection('profiles').doc(id).get();
      if (!doc.exists) return false;
      final data = doc.data()!;
      if (data['isShareable'] as bool? ?? false) return true;
      final members = data['members'] as Map<String, dynamic>? ?? {};
      final raw = members[uid]?.toString() ?? '';
      return raw == 'member' || raw == 'viewer';
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadCloudSqlitePrimaryIds() async {
    final prefs = await SharedPreferences.getInstance();
    _cloudIdsSqlitePrimary
      ..clear()
      ..addAll(prefs.getStringList(_cloudSqlitePrimaryKey) ?? []);
  }

  Future<void> _persistCloudSqlitePrimaryIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _cloudSqlitePrimaryKey,
      _cloudIdsSqlitePrimary.toList(),
    );
  }

  Future<void> markCloudProfileSqlitePrimary(String profileId) async {
    _cloudIdsSqlitePrimary.add(profileId);
    await _persistCloudSqlitePrimaryIds();
  }

  Future<void> clearCloudProfileSqlitePrimary(String profileId) async {
    _cloudIdsSqlitePrimary.remove(profileId);
    await _persistCloudSqlitePrimaryIds();
  }

  Future<void> refreshCachedActiveProfileId() async {
    _cachedActiveProfileId = await getActiveProfileId();
  }

  /// Private on-device profiles: [localPrivateProfileId] and `local_*` ids.
  static bool isLocalProfileId(String id) =>
      id == localPrivateProfileId || id.startsWith('local_');

  Future<void> _ensureLocalProfilesSeed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_localProfilesJsonKey)) return;
    await prefs.setString(
      _localProfilesJsonKey,
      jsonEncode([
        {'id': localPrivateProfileId, 'name': 'Private', 'isDefault': true},
      ]),
    );
  }

  Future<List<Map<String, dynamic>>> _readLocalProfileMaps() async {
    await _ensureLocalProfilesSeed();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localProfilesJsonKey);
    if (raw == null || raw.isEmpty) {
      return [
        {'id': localPrivateProfileId, 'name': 'Private', 'isDefault': true},
      ];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [
        {'id': localPrivateProfileId, 'name': 'Private', 'isDefault': true},
      ];
    }
  }

  Future<void> _writeLocalProfileMaps(List<Map<String, dynamic>> maps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localProfilesJsonKey, jsonEncode(maps));
  }

  Future<List<ProfileModel>> _loadLocalProfileModels() async {
    final maps = await _readLocalProfileMaps();
    final uid = _cloudUid;
    return maps
        .map(
          (m) => ProfileModel(
            id: m['id'] as String,
            name: m['name'] as String? ?? 'Profile',
            isDefault: m['isDefault'] as bool? ?? false,
            isShareable: false,
            shareCode: '',
            shareCodeActive: false,
            createdBy: '',
            members: {
              localDeviceMemberKey: 'owner',
              if (uid.isNotEmpty) uid: 'owner',
            },
          ),
        )
        .toList();
  }

  Future<String> _createLocalProfile(String name) async {
    final maps = await _readLocalProfileMaps();
    final id =
        'local_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
    final trimmed = name.trim();
    maps.add({
      'id': id,
      'name': trimmed.isEmpty ? 'Profile' : trimmed,
      'isDefault': false,
    });
    await _writeLocalProfileMaps(maps);
    return id;
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'krchabookdb',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _cloudUid => _auth.currentUser?.uid ?? '';

  bool get isSignedIn => _auth.currentUser != null;

  /// Key used in [ProfileModel.members] for the current user (Firebase UID when signed in).
  String get currentMemberKey =>
      _cloudUid.isNotEmpty ? _cloudUid : localDeviceMemberKey;

  /// Seeds [active_profile_id] for on-device private use (signed in or not).
  Future<void> ensureLocalPrivateProfileActive() async {
    await _ensureLocalProfilesSeed();
    final prefs = await SharedPreferences.getInstance();
    final valid =
        (await _readLocalProfileMaps()).map((m) => m['id'] as String).toSet();
    var id = prefs.getString(_activeProfileKey);
    if (id == null || (isLocalProfileId(id) && !valid.contains(id))) {
      id = localPrivateProfileId;
      await prefs.setString(_activeProfileKey, id);
    }
    _cachedActiveProfileId = prefs.getString(_activeProfileKey);
    FirestoreService().clearCaches();
  }

  // ─── Deterministic default profile ID ─────────────────────────────────────

  /// Returns the deterministic Firestore document ID for a user's default profile.
  /// Derived from [User.uid] so it is known immediately at login, with zero network calls.
  static String defaultProfileId(String uid) => 'default_$uid';

  /// Returns the uid segment for ids shaped as `default_<uid>`, else null.
  static String? userIdFromDefaultProfileId(String? id) {
    if (id == null || !id.startsWith('default_')) return null;
    return id.substring('default_'.length);
  }

  /// Tracks the signed-in [User.uid] and resets state when the Firebase account changes.
  /// Does **not** move the user onto a cloud "default" book — private/default stay local.
  Future<void> syncActiveProfileForCurrentUser() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    final uid = _cloudUid;
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final storedUid = prefs.getString(_prefsUidKey);
    var activeId = prefs.getString(_activeProfileKey);

    if (storedUid != null && storedUid != uid) {
      await prefs.setString(_activeProfileKey, localPrivateProfileId);
      await prefs.setString(_prefsUidKey, uid);
      FirestoreService().clearCaches();
      try {
        await DatabaseService.deleteAllData();
      } catch (_) {}
      _cachedActiveProfileId = localPrivateProfileId;
      return;
    }

    await prefs.setString(_prefsUidKey, uid);

    if (activeId == null || activeId.isEmpty) {
      await prefs.setString(_activeProfileKey, localPrivateProfileId);
      activeId = localPrivateProfileId;
    }

    _cachedActiveProfileId = activeId;
    FirestoreService().clearCaches();
  }

  /// Whether this Firebase user already has Kharcha Book data in Firestore (Pro / cloud books).
  ///
  /// Uses the default cache strategy (works offline when persistence already has the user doc).
  /// Returns false if not signed in, cloud off, or on read error (caller may treat as "no cloud").
  Future<bool> currentUserHasEstablishedCloudData() async {
    if (!AppConfig.firebaseCloudEnabled) return false;
    final uid = _cloudUid;
    if (uid.isEmpty) return false;
    try {
      final userSnap = await _firestore.collection('users').doc(uid).get();
      if (userSnap.exists) {
        final list = userSnap.data()?['profiles'];
        if (list is List && list.isNotEmpty) return true;
      }
      final defId = defaultProfileId(uid);
      final profSnap = await _firestore.collection('profiles').doc(defId).get();
      if (!profSnap.exists) return false;
      final members = profSnap.data()?['members'] as Map<String, dynamic>?;
      return members != null && members.containsKey(uid);
    } catch (_) {
      return false;
    }
  }

  /// Clears profile selection prefs on sign-out so the next user never inherits
  /// the previous account's active profile id.
  Future<void> clearProfilePrefsForLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeProfileKey);
    await prefs.remove(_prefsUidKey);
    _cachedActiveProfileId = null;
  }

  /// Derives a 6-char share code from [uid] without any network call.
  /// Used only for the default profile. Custom profiles still use random codes.
  static String _deriveShareCode(String uid) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var hash = uid.hashCode.abs();
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
    if (!AppConfig.firebaseCloudEnabled) return;
    final uid = _cloudUid;
    if (uid.isEmpty) return;

    final profileId = defaultProfileId(uid);
    final shareCode = _deriveShareCode(uid);

    await _firestore.collection('profiles').doc(profileId).set(
      {
        'name': 'Default',
        'isDefault': true,
        'isShareable': false,
        'shareCode': shareCode,
        'shareCodeActive': false,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'members': {uid: 'owner'},
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(uid).set(
      {
        'activeProfileId': profileId,
        'profiles': FieldValue.arrayUnion([profileId]),
      },
      SetOptions(merge: true),
    );
  }

  /// If [active_profile_id] points at a profile this user is no longer a
  /// member of (revoked, deleted account, stale prefs), switch to the default
  /// profile so Firestore rules allow reads/writes again.
  Future<void> ensureActiveProfileMembership() async {
    if (!AppConfig.firebaseCloudEnabled) return;
    final uid = _cloudUid;
    if (uid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final activeId = prefs.getString(_activeProfileKey);
    if (activeId == null || activeId.isEmpty) {
      await prefs.setString(_activeProfileKey, localPrivateProfileId);
      FirestoreService().clearCaches();
      _cachedActiveProfileId = localPrivateProfileId;
      return;
    }

    if (isLocalProfileId(activeId)) {
      return;
    }

    try {
      final doc = await _firestore.collection('profiles').doc(activeId).get();
      if (!doc.exists) {
        await _switchToDefaultProfile();
        return;
      }
      final members = doc.data()?['members'] as Map<String, dynamic>?;
      if (members == null || members[uid] == null) {
        await _switchToDefaultProfile();
      }
    } catch (_) {
      // Offline or transient error — keep current selection
    }
  }

  // ─── Profile CRUD ──────────────────────────────────────────────────────────

  /// Creates a new non-default profile and adds it to the user's profile list.
  /// Does not change the active profile or clear local data — call [switchProfile]
  /// after the user confirms (e.g. "Switch to this profile?").
  Future<String> createProfile(
    String name, {
    bool isShareable = false,
  }) async {
    if (!AppConfig.firebaseCloudEnabled) {
      return _createLocalProfile(name);
    }
    final uid = _cloudUid;
    // Signed-out users only get on-device profiles (private).
    if (uid.isEmpty) {
      return _createLocalProfile(name);
    }

    final shareCode = await _generateShareCode();
    final profileRef = _firestore.collection('profiles').doc();
    final profileId = profileRef.id;

    await profileRef.set({
      'name': name,
      'isDefault': false,
      'isShareable': isShareable,
      'shareCode': shareCode,
      'shareCodeActive': isShareable,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {uid: 'owner'},
    });

    // Only register the new profile — do not change active profile or wipe local
    // data here. Callers show "Switch to new profile?" and call [switchProfile]
    // when the user confirms, so the UI stays responsive and SQLite is not cleared
    // until then.
    await _firestore.collection('users').doc(uid).set(
      {
        'profiles': FieldValue.arrayUnion([profileId]),
      },
      SetOptions(merge: true),
    );

    return profileId;
  }

  /// Returns a real-time stream of all profiles the current user is a member of.
  Stream<List<ProfileModel>> getMyProfiles() {
    if (!AppConfig.firebaseCloudEnabled) {
      return Stream.fromFuture(_loadLocalProfileModels());
    }
    if (!isSignedIn) {
      return Stream.fromFuture(_loadLocalProfileModels());
    }
    final uid = _cloudUid;
    if (uid.isEmpty) return Stream.value([]);

    return _firestore
        .collection('profiles')
        .where('members.$uid', isGreaterThanOrEqualTo: '')
        .snapshots()
        .asyncMap((snap) async {
      final cloud = snap.docs
          .map((doc) => ProfileModel.fromMap(doc.id, doc.data()))
          .where((p) => !p.id.startsWith('default_'))
          .toList();
      final local = await _loadLocalProfileModels();
      return [...local, ...cloud];
    });
  }

  /// Switches the active profile, clears all caches, and persists choice.
  ///
  /// Wiping SQLite here is intentional: the SQLite database is profile-agnostic
  /// and would otherwise serve the previous profile's data as a fallback while
  /// Firestore loads the new profile's data.
  Future<void> switchProfile(String profileId) async {
    if (!AppConfig.firebaseCloudEnabled) {
      await _ensureLocalProfilesSeed();
      final maps = await _readLocalProfileMaps();
      if (!maps.any((m) => m['id'] == profileId)) {
        throw Exception('Unknown profile');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeProfileKey, profileId);
      _cachedActiveProfileId = profileId;
      FirestoreService().clearCaches();
      await DatabaseService.closeDatabase();
      DataStore.clearBookDataCache();
      DataStore.bumpTransactionMutationGeneration();
      DataStore.bumpProfileSwitchGeneration();
      return;
    }

    if (!isSignedIn) {
      await _ensureLocalProfilesSeed();
      final maps = await _readLocalProfileMaps();
      if (!maps.any((m) => m['id'] == profileId)) {
        throw Exception('Unknown profile');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeProfileKey, profileId);
      _cachedActiveProfileId = profileId;
      FirestoreService().clearCaches();
      await DatabaseService.closeDatabase();
      DataStore.clearBookDataCache();
      DataStore.bumpTransactionMutationGeneration();
      DataStore.bumpProfileSwitchGeneration();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final prevId = prefs.getString(_activeProfileKey);
    final prevWasCloud =
        prevId != null && !isLocalProfileId(prevId);

    if (prevWasCloud && prevId != profileId) {
      try {
        await DatabaseService.deleteAllData();
      } catch (_) {}
    }

    await prefs.setString(_activeProfileKey, profileId);
    _cachedActiveProfileId = profileId;
    FirestoreService().clearCaches();
    await DatabaseService.closeDatabase();

    try {
      final uid = _cloudUid;
      if (uid.isNotEmpty && !isLocalProfileId(profileId)) {
        await _firestore.collection('users').doc(uid).set(
          {'activeProfileId': profileId},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}

    DataStore.clearBookDataCache();
    DataStore.bumpTransactionMutationGeneration();
    DataStore.bumpProfileSwitchGeneration();
  }

  /// Gets the active profile ID from SharedPreferences, falling back to Firestore.
  Future<String?> getActiveProfileId() async {
    await _loadCloudSqlitePrimaryIds();
    final prefs = await SharedPreferences.getInstance();
    if (!AppConfig.firebaseCloudEnabled) {
      await _ensureLocalProfilesSeed();
      final valid =
          (await _readLocalProfileMaps()).map((m) => m['id'] as String).toSet();
      var id = prefs.getString(_activeProfileKey);
      if (id == null || !valid.contains(id)) {
        id = localPrivateProfileId;
        await prefs.setString(_activeProfileKey, id);
        FirestoreService().clearCaches();
        await DatabaseService.closeDatabase();
      }
      _cachedActiveProfileId = id;
      return id;
    }

    if (!isSignedIn) {
      await _ensureLocalProfilesSeed();
      final valid =
          (await _readLocalProfileMaps()).map((m) => m['id'] as String).toSet();
      var id = prefs.getString(_activeProfileKey);
      if (id == null || !valid.contains(id)) {
        id = localPrivateProfileId;
        await prefs.setString(_activeProfileKey, id);
        FirestoreService().clearCaches();
        await DatabaseService.closeDatabase();
      }
      _cachedActiveProfileId = id;
      return id;
    }

    await _ensureLocalProfilesSeed();
    final localValid =
        (await _readLocalProfileMaps()).map((m) => m['id'] as String).toSet();

    var id = prefs.getString(_activeProfileKey);
    if (id == null || id.isEmpty) {
      id = localPrivateProfileId;
      await prefs.setString(_activeProfileKey, id);
    }

    if (isLocalProfileId(id)) {
      if (!localValid.contains(id)) {
        id = localPrivateProfileId;
        await prefs.setString(_activeProfileKey, id);
      }
      _cachedActiveProfileId = id;
      await DatabaseService.closeDatabase();
      return id;
    }

    _cachedActiveProfileId = id;
    return id;
  }

  /// Returns the ProfileModel for the active profile.
  Future<ProfileModel?> getActiveProfile() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    if (!AppConfig.firebaseCloudEnabled) {
      final models = await _loadLocalProfileModels();
      for (final p in models) {
        if (p.id == profileId) return p;
      }
      return null;
    }
    if (isLocalProfileId(profileId)) {
      final models = await _loadLocalProfileModels();
      for (final p in models) {
        if (p.id == profileId) return p;
      }
      if (profileId == localPrivateProfileId) {
        return localPrivateProfileModel;
      }
      return null;
    }
    try {
      final doc = await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      return ProfileModel.fromMap(doc.id, doc.data()!);
    } catch (_) {
      return null;
    }
  }

  /// Returns the current user's role in the active profile ('owner' or 'viewer').
  Future<String?> getCurrentUserRole() async {
    final profileId = await getActiveProfileId();
    if (profileId == null) return null;
    return getRoleInProfile(profileId);
  }

  /// Returns the current user's role in a specific profile ('owner' or 'viewer').
  /// Legacy Firestore value `member` is treated as viewer (read-only).
  Future<String?> getRoleInProfile(String profileId) async {
    if (!AppConfig.firebaseCloudEnabled) {
      final maps = await _readLocalProfileMaps();
      if (maps.any((m) => m['id'] == profileId)) return 'owner';
      return null;
    }
    if (isLocalProfileId(profileId)) {
      final maps = await _readLocalProfileMaps();
      if (maps.any((m) => m['id'] == profileId)) return 'owner';
      return null;
    }
    final uid = _cloudUid;
    if (uid.isEmpty) return null;
    try {
      final doc =
          await _firestore.collection('profiles').doc(profileId).get();
      if (!doc.exists) return null;
      final members = doc.data()?['members'] as Map<String, dynamic>?;
      final raw = members?[uid] as String?;
      if (raw == null) return null;
      if (raw == 'owner') return 'owner';
      return 'viewer';
    } catch (_) {
      return null;
    }
  }

  // ─── Sharing ───────────────────────────────────────────────────────────────

  /// Joins a profile by its share code. New members join with the 'viewer' role.
  Future<ProfileModel> joinProfileByCode(String code) async {
    if (!AppConfig.firebaseCloudEnabled) {
      throw Exception('Joining profiles is unavailable while cloud sync is off.');
    }
    final uid = _cloudUid;
    if (uid.isEmpty) throw Exception('Not logged in');

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
    } on FirebaseException catch (e) {
      // Do not mask permission / project / rules issues as "no profile found".
      if (e.code == 'permission-denied' ||
          e.code == 'failed-precondition' ||
          e.code == 'unauthenticated') {
        throw _joinFirestoreException(e, phase: 'lookup shareCode');
      }
      try {
        snap = await _firestore
            .collection('profiles')
            .where('shareCode', isEqualTo: trimmed)
            .limit(1)
            .get();
      } on FirebaseException catch (e2) {
        throw _joinFirestoreException(e2, phase: 'lookup shareCode (cache)');
      }
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
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied' ||
            e.code == 'failed-precondition' ||
            e.code == 'unauthenticated') {
          throw _joinFirestoreException(e, phase: 'lookup inviteCode');
        }
        try {
          final legacySnap = await _firestore
              .collection('profiles')
              .where('inviteCode', isEqualTo: trimmed)
              .limit(1)
              .get();
          if (legacySnap.docs.isNotEmpty) {
            snap = legacySnap;
          }
        } on FirebaseException catch (e2) {
          throw _joinFirestoreException(e2, phase: 'lookup inviteCode (cache)');
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
    final normalizedData = Map<String, dynamic>.from(data);
    if (normalizedData.containsKey('shareCodeActive')) {
      final r = normalizedData['shareCodeActive'];
      normalizedData['shareCodeActive'] =
          r == true || (r is String && r.toLowerCase() == 'true');
    }
    if (isShareCodeBased) {
      final isActive = normalizedData['shareCodeActive'] == true;
      if (!isActive) {
        throw Exception(
          'This share code is not active. '
          'Ask the profile owner to enable sharing in Manage Profiles.',
        );
      }
    }

    final model = ProfileModel.fromMap(profileId, normalizedData);

    // Already a member — return as-is
    if (model.members.containsKey(uid)) {
      return model;
    }

    if (kDebugMode) {
      debugPrint(
        '[joinProfileByCode] profileId=$profileId joinerUid=$uid code=$trimmed '
        'shareCodeActive=${normalizedData['shareCodeActive']}',
      );
    }

    // Read before write (Firestore transaction requirement) + re-check share state.
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('profiles').doc(profileId);
        final fresh = await tx.get(ref);
        if (!fresh.exists) {
          throw Exception('Profile no longer exists. Try again or ask the owner.');
        }
        final fd = fresh.data()!;
        final membersRaw = fd['members'];
        final members = membersRaw is Map
            ? Map<String, dynamic>.from(
                membersRaw.map((k, v) => MapEntry(k.toString(), v)),
              )
            : <String, dynamic>{};
        if (members.containsKey(uid)) {
          return;
        }
        if (fd.containsKey('shareCode')) {
          final rawActive = fd['shareCodeActive'];
          final active = rawActive == true ||
              (rawActive is String && rawActive.toLowerCase() == 'true');
          if (!active) {
            throw Exception(
              'Sharing was turned off before you could join. Ask the owner to re-enable.',
            );
          }
        }
        // Write full `members` map (not `members.{uid}` dot paths). Some rule
        // evaluations see an incomplete `request.resource.data.members` for
        // field-path updates, which made `afterM[myUid()] == 'viewer'` fail.
        final mergedMembers = Map<String, dynamic>.from(members);
        mergedMembers[uid] = 'viewer';
        tx.update(ref, {'members': mergedMembers});
      });
    } on FirebaseException catch (e) {
      throw _joinFirestoreException(e, phase: 'transaction members.$uid');
    }

    try {
      await _firestore.collection('users').doc(uid).set(
        {'profiles': FieldValue.arrayUnion([profileId])},
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw _joinFirestoreException(e, phase: 'users/$uid profiles');
    }

    return ProfileModel.fromMap(profileId, {
      ...normalizedData,
      'members': {...model.members, uid: 'viewer'},
    });
  }

  /// User-visible message with Firestore [code] so rules vs network vs auth is obvious.
  FirebaseException _joinFirestoreException(
    FirebaseException e, {
    required String phase,
  }) {
    return FirebaseException(
      plugin: e.plugin,
      code: e.code,
      message: 'Join ($phase) [${e.code}]: ${e.message ?? ''}',
      stackTrace: e.stackTrace,
    );
  }

  /// Renames a profile. Owner-only.
  Future<void> updateProfileName(String profileId, String newName) async {
    final role = await getRoleInProfile(profileId);
    if (role != 'owner') {
      throw Exception('Only the owner can rename this profile');
    }
    if (!AppConfig.firebaseCloudEnabled || isLocalProfileId(profileId)) {
      final maps = await _readLocalProfileMaps();
      final i = maps.indexWhere((m) => m['id'] == profileId);
      if (i < 0) throw Exception('Profile not found');
      maps[i]['name'] = newName.trim();
      await _writeLocalProfileMaps(maps);
      return;
    }
    await _firestore
        .collection('profiles')
        .doc(profileId)
        .update({'name': newName});
  }

  /// Promotes a non-default on-device profile to a shareable Firestore book.
  Future<void> _promoteLocalProfileToShareable(String localProfileId) async {
    final uid = _cloudUid;
    if (uid.isEmpty) throw Exception('Not logged in');
    if (localProfileId == localPrivateProfileId) {
      throw Exception('The default on-device book cannot be shared this way.');
    }
    final maps = await _readLocalProfileMaps();
    final i = maps.indexWhere((m) => m['id'] == localProfileId);
    if (i < 0) throw Exception('Profile not found');
    if (maps[i]['isDefault'] == true) {
      throw Exception('The default profile cannot be converted.');
    }
    final name = maps[i]['name'] as String? ?? 'Profile';

    final shareCode = await _generateShareCode();
    final profileRef = _firestore.collection('profiles').doc();
    final newId = profileRef.id;

    await profileRef.set({
      'name': name,
      'isDefault': false,
      'isShareable': true,
      'shareCode': shareCode,
      'shareCodeActive': true,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': {uid: 'owner'},
    });

    await _firestore.collection('users').doc(uid).set(
      {'profiles': FieldValue.arrayUnion([newId])},
      SetOptions(merge: true),
    );

    final prefs = await SharedPreferences.getInstance();
    final previousActive = prefs.getString(_activeProfileKey);

    await DatabaseService.closeDatabase();
    await DatabaseService.copyDatabaseFileBetweenProfiles(localProfileId, newId);

    maps.removeAt(i);
    await _writeLocalProfileMaps(maps);
    await prefs.setString(_activeProfileKey, newId);
    _cachedActiveProfileId = newId;

    try {
      await FirestoreService().replaceCloudCollectionsFromSqlite(newId);
    } finally {
      await DatabaseService.deleteDatabaseFileForProfile(localProfileId);
      if (previousActive != null &&
          previousActive != localProfileId &&
          previousActive != newId) {
        await prefs.setString(_activeProfileKey, previousActive);
        _cachedActiveProfileId = previousActive;
      }
      await DatabaseService.closeDatabase();
      FirestoreService().clearCaches();
    }

    DataStore.clearBookDataCache();
    DataStore.bumpTransactionMutationGeneration();
    DataStore.bumpProfileSwitchGeneration();
  }

  /// Best-effort notify collaborator user docs. May fail if [userId] has no
  /// `users/{userId}` doc yet; profile membership is already revoked separately.
  Future<void> _notifyUserProfileRevoked(
    String userId,
    String profileId,
    String profileName,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set(
        {
          'profiles': FieldValue.arrayRemove([profileId]),
          'revokedProfiles': FieldValue.arrayUnion([
            {'id': profileId, 'name': profileName},
          ]),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // Owner-side revoke/delete already applied on the profile document.
    }
  }

  /// Toggles the sharable state of a profile. Owner-only.
  /// When disabling, removes all non-owner members and notifies them.
  Future<void> toggleShareable(String profileId, bool isShareable) async {
    if (!AppConfig.firebaseCloudEnabled) return;
    if (isLocalProfileId(profileId)) {
      if (!isShareable) {
        throw Exception('On-device profiles are already private.');
      }
      await _promoteLocalProfileToShareable(profileId);
      return;
    }
    final uid = _cloudUid;
    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    if (!doc.exists) throw Exception('Profile not found');

    final data = doc.data()!;
    final members = data['members'] as Map<String, dynamic>? ?? {};
    if (members[uid] != 'owner') {
      throw Exception('Only the owner can change profile settings');
    }

    if (!isShareable) {
      // Revoking: atomically remove non-owner members and notify them
      final nonOwnerKeys = members.entries
          .where((e) => e.value != 'owner')
          .map((e) => e.key)
          .toList();

      final updatedMembers = Map<String, dynamic>.from(members);
      for (final k in nonOwnerKeys) {
        updatedMembers.remove(k);
      }

      final profileName = data['name']?.toString() ?? 'Profile';

      await _firestore.collection('profiles').doc(profileId).update({
        'isShareable': false,
        'shareCodeActive': false,
        'members': updatedMembers,
      });

      for (final mp in nonOwnerKeys) {
        await _notifyUserProfileRevoked(mp, profileId, profileName);
      }

      for (final col in const [
        'transactions',
        'budgets',
        'accounts',
        'categories',
      ]) {
        await _deleteSubcollection(profileId, col);
      }
      await markCloudProfileSqlitePrimary(profileId);
      FirestoreService().clearCaches();
    } else {
      await FirestoreService().replaceCloudCollectionsFromSqlite(profileId);
      await clearCloudProfileSqlitePrimary(profileId);
      await _firestore.collection('profiles').doc(profileId).update({
        'isShareable': true,
        'shareCodeActive': true,
      });
      FirestoreService().clearCaches();
    }
  }

  // ─── Membership ────────────────────────────────────────────────────────────

  /// Removes a member from a profile and notifies them. Owner-only.
  Future<void> removeMember(String profileId, String memberUserId) async {
    if (!AppConfig.firebaseCloudEnabled) {
      throw Exception('Not available while cloud sync is off.');
    }
    final myRole = await getRoleInProfile(profileId);
    if (myRole != 'owner') {
      throw Exception('Only the owner can remove members');
    }

    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    final profileName = doc.data()?['name']?.toString() ?? 'Profile';

    await _firestore.collection('profiles').doc(profileId).update({
      'members.$memberUserId': FieldValue.delete(),
    });
    await _notifyUserProfileRevoked(memberUserId, profileId, profileName);
  }

  /// Leaves a shared profile. Non-owner only — owner must delete instead.
  Future<void> leaveProfile(String profileId) async {
    if (!AppConfig.firebaseCloudEnabled) {
      throw Exception('Not available while cloud sync is off.');
    }
    final uid = _cloudUid;
    if (uid.isEmpty) return;

    final role = await getRoleInProfile(profileId);
    if (role == 'owner') {
      throw Exception('Owner cannot leave. Delete the profile instead.');
    }

    await _firestore.collection('profiles').doc(profileId).update({
      'members.$uid': FieldValue.delete(),
    });

    await _firestore.collection('users').doc(uid).set(
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
    if (!AppConfig.firebaseCloudEnabled || isLocalProfileId(profileId)) {
      final maps = await _readLocalProfileMaps();
      final i = maps.indexWhere((m) => m['id'] == profileId);
      if (i < 0) throw Exception('Profile not found');
      if (profileId == localPrivateProfileId ||
          maps[i]['isDefault'] == true) {
        throw Exception('The default profile cannot be deleted');
      }
      maps.removeAt(i);
      await _writeLocalProfileMaps(maps);
      await DatabaseService.deleteDatabaseFileForProfile(profileId);
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_activeProfileKey) == profileId) {
        await prefs.setString(_activeProfileKey, localPrivateProfileId);
        FirestoreService().clearCaches();
        await DatabaseService.closeDatabase();
        DataStore.clearBookDataCache();
      }
      return;
    }
    final uid = _cloudUid;
    if (profileId.startsWith('default_')) {
      throw Exception('The default profile cannot be deleted');
    }
    final doc =
        await _firestore.collection('profiles').doc(profileId).get();
    if (!doc.exists) throw Exception('Profile not found');

    final data = doc.data()!;
    final members = data['members'] as Map<String, dynamic>? ?? {};
    if (members[uid] != 'owner') {
      throw Exception('Only the owner can delete this profile');
    }
    if (data['isDefault'] as bool? ?? false) {
      throw Exception('The default profile cannot be deleted');
    }

    final profileName = data['name']?.toString() ?? 'Profile';
    final nonOwnerKeys = members.entries
        .where((e) => e.value != 'owner')
        .map((e) => e.key)
        .toList();

    for (final mp in nonOwnerKeys) {
      await _notifyUserProfileRevoked(mp, profileId, profileName);
    }

    // Delete subcollections then the profile document
    for (final col in ['transactions', 'budgets', 'accounts', 'categories']) {
      await _deleteSubcollection(profileId, col);
    }
    await clearCloudProfileSqlitePrimary(profileId);
    await _firestore.collection('profiles').doc(profileId).delete();

    await _firestore.collection('users').doc(uid).set(
      {'profiles': FieldValue.arrayRemove([profileId])},
      SetOptions(merge: true),
    );

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(_activeProfileKey);
    if (current == profileId) {
      await _switchToDefaultProfile();
    }
    try {
      await DatabaseService.deleteDatabaseFileForProfile(profileId);
    } catch (_) {}
  }

  // ─── Revocation Notifications ──────────────────────────────────────────────

  /// Checks for profiles the user was removed from since last check.
  /// Clears the list and returns profile names for display in a popup.
  Future<List<String>> checkAndClearRevokedProfiles() async {
    if (!AppConfig.firebaseCloudEnabled) return [];
    final uid = _cloudUid;
    if (uid.isEmpty) return [];

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
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
      await _firestore.collection('users').doc(uid).update({
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

  /// Finds a profile ID by its identifier (owner uid or share code)
  /// and verifies the current user has access to it.
  Future<String?> findProfileIdByIdentifier(
    String identifier,
    String profileName,
  ) async {
    if (!AppConfig.firebaseCloudEnabled) {
      final models = await _loadLocalProfileModels();
      final want = profileName.trim().toLowerCase();
      for (final p in models) {
        if (p.name.trim().toLowerCase() != want) continue;
        if (p.id == identifier) return p.id;
        if (identifier == 'local_private' && p.id == localPrivateProfileId) {
          return p.id;
        }
      }
      return null;
    }
    final uid = _cloudUid;
    if (uid.isEmpty) return null;

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
          if (members.containsKey(uid)) return doc.id;
        }
        return null;
      }

      // Owner uid: find a matching profile created by that user that the
      // current user is also a member of
      final snap = await _firestore
          .collection('profiles')
          .where('createdBy', isEqualTo: identifier)
          .where('members.$uid', isGreaterThanOrEqualTo: '')
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
    await switchProfile(localPrivateProfileId);
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
