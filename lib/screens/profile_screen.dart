import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/profile_service.dart';
import '../widgets/section_tile.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileService _profileService = ProfileService();

  Map<String, dynamic>? _profile;
  String? _myRole;
  bool _loading = true;
  bool _saving = false;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await _profileService.getActiveProfile();
      final role = await _profileService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _profile = profile;
          _myRole = role;
          _nameController.text = profile?['name']?.toString() ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || _profile == null) return;
    setState(() => _saving = true);
    try {
      await _profileService.updateProfileName(
        _profile!['id'] as String,
        newName,
      );
      if (mounted) {
        setState(() {
          _profile = {..._profile!, 'name': newName};
          _saving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile name updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      }
    }
  }

  Future<void> _copyInviteCode() async {
    final code = _profile?['inviteCode']?.toString() ?? '';
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard.')),
    );
  }

  void _showChangeMemberRoleSheet(String memberPhone, String currentRole) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Change role for $memberPhone',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Divider(height: 1),
            for (final role in ['editor', 'viewer'])
              ListTile(
                leading: Icon(
                  role == 'editor' ? Icons.edit_outlined : Icons.visibility_outlined,
                ),
                title: Text(role == 'editor' ? 'Editor' : 'Viewer'),
                subtitle: Text(
                  role == 'editor'
                      ? 'Can add and edit data'
                      : 'Can only view data',
                ),
                trailing: currentRole == role
                    ? const Icon(Icons.check, color: Color(0xFF4F46E5))
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (currentRole == role) return;
                  try {
                    await _profileService.updateMemberRole(
                      _profile!['id'] as String,
                      memberPhone,
                      role,
                    );
                    await _loadProfile();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(String memberPhone) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
          'Remove $memberPhone from this profile?\nThey will lose access to all shared data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _profileService.removeMember(
          _profile!['id'] as String, memberPhone);
      await _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _leaveProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave profile?'),
        content: const Text(
          'You will lose access to all data in this profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _profileService.leaveProfile(_profile!['id'] as String);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: const Text(
          'This will permanently delete the profile and all its data.\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _profileService.deleteProfile(_profile!['id'] as String);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isOwner = _myRole == 'owner';
    final myPhone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    final members = (_profile?['members'] as Map<String, dynamic>?) ?? {};
    final inviteCode = _profile?['inviteCode']?.toString() ?? '------';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
              children: [
                // Profile name
                SectionTile(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Name',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              readOnly: !isOwner,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 8),
                            _saving
                                ? const SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.check),
                                    tooltip: 'Save name',
                                    onPressed: _saveName,
                                  ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Invite code
                SectionTile(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite Code',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              inviteCode,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 6,
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined),
                              tooltip: 'Copy invite code',
                              onPressed: _copyInviteCode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Share this code so others can join this profile.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Members
                SectionTile(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Text(
                          'Members',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const Divider(height: 1),
                      ...members.entries.map((entry) {
                        final memberPhone = entry.key;
                        final role = entry.value.toString();
                        final isMe = memberPhone == myPhone;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.surfaceVariant,
                            child: Icon(
                              Icons.person_outline,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          title: Text(
                            isMe ? '$memberPhone (you)' : memberPhone,
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: _RoleBadge(role: role),
                          onTap: isOwner && !isMe
                              ? () => _showChangeMemberRoleSheet(
                                    memberPhone,
                                    role,
                                  )
                              : null,
                          onLongPress: isOwner && !isMe
                              ? () => _confirmRemoveMember(memberPhone)
                              : null,
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Leave / Delete buttons
                if (!isOwner)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.exit_to_app_outlined),
                    label: const Text('Leave Profile'),
                    onPressed: _leaveProfile,
                  ),
                if (isOwner)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor:
                          Theme.of(context).colorScheme.onError,
                    ),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: const Text('Delete Profile'),
                    onPressed: _deleteProfile,
                  ),
              ],
            ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Color bgColor;
    Color textColor;
    switch (role) {
      case 'owner':
        bgColor = const Color(0xFF4F46E5).withOpacity(0.12);
        textColor = const Color(0xFF4F46E5);
        break;
      case 'editor':
        bgColor = Colors.green.withOpacity(0.12);
        textColor = Colors.green.shade700;
        break;
      default:
        bgColor = cs.surfaceVariant;
        textColor = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
