import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/data_service.dart';
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
  bool _expandAddOptions = false;
  String? _activeProfileId;

  String get _myPhone =>
      FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

  @override
  void initState() {
    super.initState();
    _refreshActiveProfileId();
  }

  Future<void> _refreshActiveProfileId() async {
    final id = await _profileService.getActiveProfileId();
    if (mounted) setState(() => _activeProfileId = id);
  }

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
    await _withBusy(() => _profileService.toggleShareable(profile.id, making));
    if (making && mounted) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Profile is now sharable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this code with others to let them join:'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      profile.shareCode,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy code',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: profile.shareCode),
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share code copied.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Copy later'),
            ),
          ],
        ),
      );
    }
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
      if (mounted) {
        setState(() => _busy = false);
        await _refreshActiveProfileId();
      }
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

  void _showCreateProfileSheet() {
    final nameCtrl = TextEditingController();
    bool isShareable = false;

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
                            String? newProfileId;
                            await _withBusy(() async {
                              newProfileId = await _profileService.createProfile(
                                name,
                                isShareable: isShareable,
                              );
                            });
                            if (newProfileId == null || !mounted) return;
                            await _showPostCreateFlow(name, newProfileId!);
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

  /// Two-step post-creation flow:
  /// Step 1 — offer to switch to the new profile.
  /// Step 2 — offer to initialize defaults for it.
  Future<void> _showPostCreateFlow(String name, String profileId) async {
    if (!mounted) return;
    // Let the bottom-sheet route finish popping before stacking dialogs; avoids
    // delayed or missing dialogs on some devices.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    // Step 1: switch?
    final shouldSwitch = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch Profile?'),
        content: Text('Profile "$name" created. Switch to it now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (shouldSwitch == true) {
      await _withBusy(() => _profileService.switchProfile(profileId));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Switched to "$name".')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Profile "$name" created.')));
    }

    // Step 2: initialize defaults?
    if (!mounted) return;
    final shouldInit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create General Categories and Accounts?'),
        content: const Text(
          'Create general categories and accounts for this profile?\n\n'
          'You can do this later from Main Menu > Data management.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (shouldInit == true) {
      BuildContext? progressCtx;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          progressCtx = ctx;
          return AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 16),
                  Text(
                    'Creating general categories and accounts…',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        },
      );
      int created = 0;
      try {
        created = await DataService
            .initializeDefaultCategoriesAndAccountsForProfile(profileId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        final dlg = progressCtx;
        if (dlg != null && dlg.mounted) {
          Navigator.of(dlg).pop();
        } else if (mounted) {
          Navigator.of(context).pop();
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              created == 0
                  ? 'General categories and accounts are already available.'
                  : 'Added $created general categories/accounts.',
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can create general categories and accounts later from Main Menu > Data management.',
            ),
          ),
        );
      }
    }
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
    final theme = Theme.of(context);
    final activeId = _activeProfileId;

    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage profiles',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _expandAddOptions = !_expandAddOptions);
                  },
                  icon: Icon(
                    Icons.add_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  label: Text(
                    'Create profile',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add_circle_outline, size: 22),
                      title: const Text('Create new profile'),
                      onTap: () {
                        setState(() => _expandAddOptions = false);
                        _showCreateProfileSheet();
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.qr_code_2_outlined, size: 22),
                      title: const Text('Join with invite code'),
                      onTap: () {
                        setState(() => _expandAddOptions = false);
                        _showJoinCodeDialog();
                      },
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: _expandAddOptions
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          if (_busy)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
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
                          !p.isDefault && p.members[myPhone] == 'owner')
                      .toList();
                  final joined = profiles
                      .where((p) =>
                          !p.isDefault && p.members[myPhone] != 'owner')
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          'Tap a profile in the main menu to switch. Active is marked below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (defaultProfile != null) ...[
                        const _SectionHeader('Default profile'),
                        _DefaultProfileCard(
                          profile: defaultProfile,
                          phone: myPhone,
                          isActive: activeId == defaultProfile.id,
                          onRename: () => _rename(defaultProfile),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (ownedOthers.isNotEmpty) ...[
                        const _SectionHeader('My profiles'),
                        for (final p in ownedOthers) ...[
                          _OwnedProfileCard(
                            profile: p,
                            isActive: activeId == p.id,
                            onRename: () => _rename(p),
                            onDelete: () => _delete(p),
                            onToggleShareable: () => _toggleShareable(p),
                            onCopyCode: () => _copyShareCode(p.shareCode),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const SizedBox(height: 8),
                      ],
                      if (joined.isNotEmpty) ...[
                        const _SectionHeader('Joined profiles'),
                        for (final p in joined) ...[
                          _JoinedProfileCard(
                            profile: p,
                            myPhone: myPhone,
                            isActive: activeId == p.id,
                            onLeave: () => _leave(p),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (profiles.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'No profiles found.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
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
  final bool isActive;
  final VoidCallback onRename;

  const _DefaultProfileCard({
    required this.profile,
    required this.phone,
    required this.isActive,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SectionTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.folder_special_outlined,
              color: cs.primary, size: 20),
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
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (isActive) ...[
            Icon(Icons.check_circle, color: cs.primary, size: 20),
            const SizedBox(width: 6),
            _Badge('Active', cs.primary),
            const SizedBox(width: 6),
          ],
          _Badge('Default', cs.primary),
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
  final bool isActive;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleShareable;
  final VoidCallback onCopyCode;

  const _OwnedProfileCard({
    required this.profile,
    required this.isActive,
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
              if (isActive) ...[
                Icon(Icons.check_circle, color: cs.primary, size: 18),
                const SizedBox(width: 4),
                _Badge('Active', cs.primary),
                const SizedBox(width: 6),
              ],
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
                  child: Icon(Icons.copy_outlined,
                      size: 14, color: cs.primary),
                ),
              ],
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
  final bool isActive;
  final VoidCallback onLeave;

  const _JoinedProfileCard({
    required this.profile,
    required this.myPhone,
    required this.isActive,
    required this.onLeave,
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
              if (isActive) ...[
                Icon(Icons.check_circle, color: cs.primary, size: 18),
                const SizedBox(width: 4),
                _Badge('Active', cs.primary),
                const SizedBox(width: 6),
              ],
              _Badge('Member', cs.onSurfaceVariant),
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
        color: color.withValues(alpha: 0.12),
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
