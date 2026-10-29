import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/common.dart';

/// Manager only: add member logins, activate/deactivate, change role.
class MembersScreen extends StatefulWidget {
  final AppUser me;
  const MembersScreen({super.key, required this.me});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final Stream<List<AppUser>> _users = Repo.allUsers();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage members')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add member'),
        onPressed: () => _showAddMember(context),
      ),
      body: PageWidth(
        child: StreamView<List<AppUser>>(
          stream: _users,
          builder: (context, users) => ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final u in users)
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase())),
                    title: Text(u.name, style: TextStyle(color: u.active ? null : Colors.grey)),
                    subtitle: Text('Username: ${u.username}  •  ${u.isManager ? 'Manager' : 'Member'}'
                        '${u.active ? '' : '  •  DEACTIVATED'}'),
                    trailing: u.uid == widget.me.uid
                        ? const Text('You')
                        : PopupMenuButton<String>(
                            onSelected: (v) => _onAction(context, u, v),
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'rename', child: Text('Edit name')),
                              PopupMenuItem(
                                value: 'role',
                                child: Text(u.isManager ? 'Make member' : 'Make manager'),
                              ),
                              PopupMenuItem(
                                value: 'active',
                                child: Text(u.active ? 'Deactivate login' : 'Re-activate login'),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, AppUser u, String action) async {
    try {
      switch (action) {
        case 'role':
          await Repo.setUserRole(u.uid, u.isManager ? AppConfig.roleMember : AppConfig.roleManager);
        case 'active':
          await Repo.setUserActive(u.uid, !u.active);
        case 'rename':
          final c = TextEditingController(text: u.name);
          final name = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Edit name'),
              content: TextField(controller: c, autofocus: true),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Save')),
              ],
            ),
          );
          if (name != null && name.trim().isNotEmpty) await Repo.renameUser(u.uid, name);
      }
    } catch (e) {
      if (context.mounted) showSnack(context, 'Failed: $e');
    }
  }

  Future<void> _showAddMember(BuildContext context) async {
    final name = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = AppConfig.roleMember;
    bool busy = false;
    String? error;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Add member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: username,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      helperText: 'small letters / numbers, e.g. ravi.k',
                    ),
                    validator: (v) => isValidUsername(v ?? '')
                        ? null
                        : '3-30 chars: a-z, 0-9, dot, dash, underscore',
                  ),
                  TextFormField(
                    controller: password,
                    decoration: const InputDecoration(labelText: 'Password (min 6)'),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: AppConfig.roleMember, label: Text('Member')),
                      ButtonSegment(value: AppConfig.roleManager, label: Text('Manager')),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setState(() => role = s.first),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await Repo.createMember(
                          name: name.text,
                          username: username.text,
                          password: password.text,
                          role: role,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (context.mounted) {
                          showSnack(context, 'Added. Share username "${normaliseUsername(username.text)}" and the password.');
                        }
                      } on FirebaseAuthException catch (e) {
                        setState(() {
                          busy = false;
                          error = e.code == 'email-already-in-use'
                              ? 'That username is already taken'
                              : 'Failed (${e.code})';
                        });
                      } catch (e) {
                        setState(() {
                          busy = false;
                          error = 'Failed: $e';
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create login'),
            ),
          ],
        ),
      ),
    );
  }
}
