import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/profile_service.dart';
import '../widgets/section_tile.dart';

class ManageProfilesScreen extends StatefulWidget {
  const ManageProfilesScreen({super.key});

  @override
  State<ManageProfilesScreen> createState() => _ManageProfilesScreenState();
}

class _ManageProfilesScreenState extends State<ManageProfilesScreen> {
  final ProfileService _profileService = ProfileService();
  bool _busy = false;

  String get _myPhone =>
      FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

  // ─── Actions ───────────────────────────────────────────────────────────────

  Future<void> _rename(ProfileModel profile) async {
    final controller = TextEditingController(text: profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Profile name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == profile.name || !mounted) {
      return;
    }
    _withBusy(() => _profileService.updateProfileName(profile.id, name));
  }

  Future<void> _delete(ProfileModel profile) async {
    final body = profile.isShareable
        ? 'This will permanently delete "${profile.name}" and remove access for all members.'
        : 'This will permanently delete "${profile.name}" and all its data.';
    final confirmed = await _confirm('Delete profile?', '$body\n\nThis cannot be undone.');
    if (!confirmed || !mounted) return;
    _withBusy(() => _profileService.deleteProfile(profile.id));
  }

  Future<void> _leave(ProfileModel profile) async {
    final confirmed = await _confirm(
      'Leave profile?',
      'You will lose access to all data in "${profile.name}".',
    );
    if (!confirmed || !mounted) return;
    _withBusy(() async {
      await _profileService.leaveProfile(profile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left profile.')),
        );
      }
    });
  }

  Future<void> _copyShareCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share code copied to clipboard.')),
    );
  }

  Future<void> _toggleShareable(ProfileModel profile) async {
    final making = !profile.isShareable;
    if (!making) {
      final confirmed = await _confirm(
        'Make profile private?',
        'All members (except you) will lose access immediately.',
      );
      if (!confirmed || !mounted) return;
    }
    _withBusy(() => _profileService.toggleShareable(profile.id, making));
  }

  Future<void> _withBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        )) ==
        true;
  }

  // ─── Add Profile bottom sheet ──────────────────────────────────────────────

  void _showAddProfileSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Add Profile',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Create new profile'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showCreateProfileSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_outlined),
              title: const Text('Join with invite code'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showJoinCodeDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showCreateProfileSheet() {
    final nameCtrl = TextEditingController();
    bool isShareable = false;
    String defaultRole = 'editor';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create New Profile',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Profile name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sharable'),
                    subtitle: const Text(
                        'Allow others to join with a share code'),
                    value: isShareable,
                    onChanged: (v) => setSheet(() => isShareable = v),
                  ),
                  if (isShareable) ...[
                    const SizedBox(height: 4),
                    Text(
                      'New members join as:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Row(
                      children: [
                        for (final pair in [
                          ('editor', 'Editor'),
                          ('viewer', 'View only'),
                        ])
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text(
                                pair.$2,
                                style: const TextStyle(fontSize: 13),
                              ),
                              value: pair.$1,
                              groupValue: defaultRole,
                              onChanged: (v) =>
                                  setSheet(() => defaultRole = v!),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            Navigator.pop(sheetCtx);
                            await _withBusy(() async {
                              await _profileService.createProfile(
                                name,
                                isShareable: isShareable,
                                defaultMemberRole: defaultRole,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Profile "$name" created.'),
                                  ),
                                );
                              }
                            });
                          },
                          child: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.addListener(() {});
  }

  Future<void> _showJoinCodeDialog() async {
    final codeCtrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Profile'),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Enter 6-character code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    codeCtrl.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    await _withBusy(() async {
      final profile = await _profileService.joinProfileByCode(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${profile.name}".')),
        );
      }
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myPhone = _myPhone;

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProfileSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Profile'),
      ),
      body: Column(
        children: [
          // Non-intrusive progress indicator — keeps the profile list visible
          // while a background operation (toggle shareable, delete, etc.) runs.
          if (_busy)
            const LinearProgressIndicator()
          else
            const SizedBox(height: 4),
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: StreamBuilder<List<ProfileModel>>(
              stream: _profileService.getMyProfiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final profiles = snapshot.data ?? [];
                final defaultProfile = profiles
                    .where((p) => p.isDefault)
                    .cast<ProfileModel?>()
                    .firstOrNull;
                final ownedOthers = profiles
                    .where((p) =>
                        !p.isDefault &&
                        p.members[myPhone] == 'owner')
                    .toList();
                final joined = profiles
                    .where((p) =>
                        !p.isDefault &&
                        p.members[myPhone] != 'owner')
                    .toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  children: [
                    if (defaultProfile != null) ...[
                      _SectionHeader('Default Profile'),
                      _DefaultProfileCard(
                        profile: defaultProfile,
                        phone: myPhone,
                        onRename: () => _rename(defaultProfile),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (ownedOthers.isNotEmpty) ...[
                      _SectionHeader('My Profiles'),
                      for (final p in ownedOthers) ...[
                        _OwnedProfileCard(
                          profile: p,
                          onRename: () => _rename(p),
                          onDelete: () => _delete(p),
                          onToggleShareable: () => _toggleShareable(p),
                          onCopyCode: () => _copyShareCode(p.shareCode),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (joined.isNotEmpty) ...[
                      _SectionHeader('Joined Profiles'),
                      for (final p in joined) ...[
                        _JoinedProfileCard(
                          profile: p,
                          myPhone: myPhone,
                          onLeave: () => _leave(p),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                    if (profiles.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No profiles found.'),
                        ),
                      ),
                  ],
                );
              },
            ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _DefaultProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final String phone;
  final VoidCallback onRename;

  const _DefaultProfileCard({
    required this.profile,
    required this.phone,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.folder_special_outlined,
              color: Color(0xFF4F46E5), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          _Badge('Default', const Color(0xFF4F46E5)),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Rename',
            onPressed: onRename,
          ),
        ],
      ),
    );
  }
}

class _OwnedProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleShareable;
  final VoidCallback onCopyCode;

  const _OwnedProfileCard({
    required this.profile,
    required this.onRename,
    required this.onDelete,
    required this.onToggleShareable,
    required this.onCopyCode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionTile(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _Badge(
                profile.isShareable ? 'Sharable' : 'Private',
                profile.isShareable
                    ? Colors.green.shade700
                    : cs.onSurfaceVariant,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Rename',
                onPressed: onRename,
              ),
            ],
          ),
          if (profile.isShareable) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.share_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  profile.shareCode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onCopyCode,
                  child: const Icon(Icons.copy_outlined,
                      size: 14, color: Color(0xFF4F46E5)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'New members: ${profile.defaultMemberRole == 'editor' ? 'Editor' : 'View only'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    profile.isShareable
                        ? Icons.lock_outline
                        : Icons.share_outlined,
                    size: 15,
                  ),
                  label: Text(
                    profile.isShareable ? 'Make private' : 'Make sharable',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: onToggleShareable,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.error,
                  side: BorderSide(color: cs.error),
                ),
                icon: const Icon(Icons.delete_outline, size: 15),
                label:
                    const Text('Delete', style: TextStyle(fontSize: 12)),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JoinedProfileCard extends StatelessWidget {
  final ProfileModel profile;
  final String myPhone;
  final VoidCallback onLeave;

  const _JoinedProfileCard({
    required this.profile,
    required this.myPhone,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final role = profile.members[myPhone] ?? 'viewer';
    return SectionTile(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _Badge(
                role == 'editor' ? 'Editor' : 'View only',
                role == 'editor'
                    ? Colors.green.shade700
                    : cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Owner: ${profile.createdBy}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
            ),
            icon: const Icon(Icons.exit_to_app_outlined, size: 15),
            label: const Text('Leave', style: TextStyle(fontSize: 12)),
            onPressed: onLeave,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// Keep this alias so any external import of ProfileScreen still compiles.
typedef ProfileScreen = ManageProfilesScreen;
