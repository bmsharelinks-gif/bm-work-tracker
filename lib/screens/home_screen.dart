import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/activity_form.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'members_screen.dart';
import 'pending_screen.dart';
import 'summary_screen.dart';
import 'team_screen.dart';
import 'today_screen.dart';

/// Loads the signed-in person's profile, then shows the main app.
class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _creatingBootstrap = false;
  String? _bootstrapError;
  late Stream<AppUser?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = Repo.userDoc(widget.user.uid);
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.user.uid != widget.user.uid) _profile = Repo.userDoc(widget.user.uid);
  }

  Widget _message(String text) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(text, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, snap) {
        if (snap.hasError) return _message('Could not load your profile:\n${snap.error}');
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final me = snap.data;
        if (me == null) {
          if (_bootstrapError != null) {
            return _message('Setup failed - are the Firestore rules published?\n$_bootstrapError');
          }
          if (isBootstrapManager(widget.user.email)) {
            if (!_creatingBootstrap) {
              _creatingBootstrap = true;
              Repo.createBootstrapProfile(widget.user).catchError((Object e) {
                if (mounted) setState(() => _bootstrapError = '$e');
              });
            }
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _message('Your profile is not set up yet.\nPlease ask your manager.');
        }
        if (!me.active) return _message('Your login has been deactivated.\nPlease contact your manager.');
        return _Shell(me: me);
      },
    );
  }
}

class _Shell extends StatefulWidget {
  final AppUser me;
  const _Shell({required this.me});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;
  final Stream<List<AppUser>> _users = Repo.allUsers();

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    if (!me.isManager) return _scaffold(me, null);
    // Managers also need the list of members.
    return StreamBuilder<List<AppUser>>(
      stream: _users,
      builder: (context, snap) => _scaffold(me, snap.data ?? const []),
    );
  }

  Widget _scaffold(AppUser me, List<AppUser>? users) {
    final isManager = users != null;
    final active = users?.where((u) => u.active).toList() ?? const <AppUser>[];

    final pages = <Widget>[
      TodayScreen(me: me, onOpenPending: () => setState(() => _tab = 1)),
      PendingScreen(me: me),
      SummaryScreen(me: me, members: isManager ? active : null),
      if (isManager) TeamScreen(me: me, members: active),
    ];
    final titles = ['Today', 'Pending & Follow-ups', 'Summary', if (isManager) 'Team'];
    if (_tab >= pages.length) _tab = 0;

    Widget? fab;
    if (_tab <= 1) {
      fab = FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log work'),
        onPressed: () => showActivityForm(context, me: me),
      );
    } else if (isManager && _tab == 3) {
      fab = FloatingActionButton.extended(
        icon: const Icon(Icons.assignment_ind),
        label: const Text('Assign task'),
        onPressed: () => showActivityForm(context, me: me, assignees: active),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            onSelected: (v) {
              switch (v) {
                case 'members':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => MembersScreen(me: me)),
                  );
                case 'password':
                  showChangePasswordDialog(context);
                case 'logout':
                  FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text('${me.name}  (${me.isManager ? 'Manager' : 'Member'})'),
              ),
              if (isManager)
                const PopupMenuItem(
                  value: 'members',
                  child: ListTile(leading: Icon(Icons.group_add), title: Text('Manage members')),
                ),
              const PopupMenuItem(
                value: 'password',
                child: ListTile(leading: Icon(Icons.key), title: Text('Change password')),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out')),
              ),
            ],
          ),
        ],
      ),
      body: PageWidth(child: pages[_tab]),
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          const NavigationDestination(icon: Icon(Icons.pending_actions), label: 'Pending'),
          const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Summary'),
          if (isManager) const NavigationDestination(icon: Icon(Icons.groups), label: 'Team'),
        ],
      ),
    );
  }
}
