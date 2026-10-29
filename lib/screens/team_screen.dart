import 'package:flutter/material.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/activity_form.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';
import 'pending_screen.dart';

/// Manager view: today's progress and open items for every member.
class TeamScreen extends StatefulWidget {
  final AppUser me;
  final List<AppUser> members;
  const TeamScreen({super.key, required this.me, required this.members});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final String _today = todayYmd();
  late final Stream<List<Activity>> _todayStream = Repo.forDates([_today]);
  late final Stream<List<Activity>> _openStream = Repo.teamOpen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamView<List<Activity>>(
      stream: _todayStream,
      builder: (context, today) => StreamView<List<Activity>>(
        stream: _openStream,
        builder: (context, open) {
          if (widget.members.isEmpty) {
            return const EmptyState(icon: Icons.group_add, text: 'No members yet.\nUse the profile menu > Manage members.');
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              SectionHeader('Today, ${prettyDate(_today)}'),
              for (final m in widget.members)
                Builder(builder: (context) {
                  final t = today.where((a) => a.uid == m.uid).toList();
                  final o = open.where((a) => a.uid == m.uid).toList();
                  final mins = t.fold<int>(0, (s, a) => s + a.minutes);
                  final overdue = o.where((a) => a.isOverdue).length;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
                      title: Text(m.name + (m.isManager ? '  (Manager)' : '')),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Logged ${fmtMins(mins)} • ${t.length} entries • ${o.length} open'
                              '${overdue > 0 ? ' • $overdue overdue' : ''}'),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: (mins / AppConfig.dailyTargetMinutes).clamp(0.0, 1.0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                      trailing: overdue > 0 ? Icon(Icons.warning_amber, color: theme.colorScheme.error) : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemberDetailScreen(me: widget.me, member: m, members: widget.members),
                        ),
                      ),
                    ),
                  );
                }),
              SectionHeader('All open items (${open.length})'),
              if (open.isEmpty) const EmptyState(icon: Icons.task_alt, text: 'Nothing open across the team.'),
              for (final a in ([...open]..sort((x, y) => (x.dueDate ?? '9999').compareTo(y.dueDate ?? '9999'))))
                ActivityTile(
                  a: a,
                  showOwner: true,
                  onTap: () => showActivityForm(context, me: widget.me, existing: a),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One member's today list + open items, with an Assign button.
class MemberDetailScreen extends StatefulWidget {
  final AppUser me;
  final AppUser member;
  final List<AppUser> members;
  const MemberDetailScreen({super.key, required this.me, required this.member, required this.members});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late final Stream<List<Activity>> _today = Repo.dayFor(widget.member.uid, todayYmd());
  late final Stream<List<Activity>> _open = Repo.openFor(widget.member.uid);

  @override
  Widget build(BuildContext context) {
    void edit(Activity a) => showActivityForm(context, me: widget.me, existing: a);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.member.name),
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Open items')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.assignment_ind),
          label: const Text('Assign task'),
          onPressed: () => showActivityForm(
            context,
            me: widget.me,
            assignees: widget.members,
            presetAssignee: widget.member,
          ),
        ),
        body: PageWidth(
          child: TabBarView(
            children: [
              StreamView<List<Activity>>(
                stream: _today,
                builder: (context, items) => items.isEmpty
                    ? const EmptyState(icon: Icons.edit_note, text: 'Nothing logged today yet.')
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 96),
                        children: [for (final a in items) ActivityTile(a: a, onTap: () => edit(a))],
                      ),
              ),
              StreamView<List<Activity>>(
                stream: _open,
                builder: (context, items) => items.isEmpty
                    ? const EmptyState(icon: Icons.task_alt, text: 'No open items.')
                    : PendingList(items: items, onTap: edit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
