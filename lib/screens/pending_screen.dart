import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../widgets/activity_form.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';

/// Every open item stays here (carried forward day to day) until marked Done.
class PendingScreen extends StatefulWidget {
  final AppUser me;
  const PendingScreen({super.key, required this.me});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  late final Stream<List<Activity>> _open = Repo.openFor(widget.me.uid);

  @override
  Widget build(BuildContext context) {
    return StreamView<List<Activity>>(
      stream: _open,
      builder: (context, items) {
        if (items.isEmpty) {
          return const EmptyState(icon: Icons.task_alt, text: 'No open follow-ups. Well done!');
        }
        return PendingList(
          items: items,
          onTap: (a) => showActivityForm(context, me: widget.me, existing: a),
        );
      },
    );
  }
}

/// Groups open items: Overdue / Due today / Upcoming / No due date.
class PendingList extends StatelessWidget {
  final List<Activity> items;
  final void Function(Activity) onTap;
  final bool showOwner;

  const PendingList({super.key, required this.items, required this.onTap, this.showOwner = false});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    int byDue(Activity a, Activity b) => a.dueDate!.compareTo(b.dueDate!);
    final overdue = items.where((a) => a.isOverdue).toList()..sort(byDue);
    final today = items.where((a) => a.isDueToday).toList();
    final upcoming = items.where((a) => a.dueDate != null && !a.isOverdue && !a.isDueToday).toList()..sort(byDue);
    final noDue = items.where((a) => a.dueDate == null).toList();

    Widget section(String title, List<Activity> list, {Color? color}) {
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('$title (${list.length})', color: color),
          for (final a in list) ActivityTile(a: a, showOwner: showOwner, onTap: () => onTap(a)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        section('Overdue', overdue, color: error),
        section('Due today', today),
        section('Upcoming', upcoming),
        section('No due date', noDue),
      ],
    );
  }
}
