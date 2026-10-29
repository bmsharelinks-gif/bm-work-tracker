import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import 'common.dart';

class ActivityTile extends StatelessWidget {
  final Activity a;
  final VoidCallback? onTap;
  final bool showOwner;
  final bool canToggle;

  const ActivityTile({
    super.key,
    required this.a,
    this.onTap,
    this.showOwner = false,
    this.canToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bits = <String>[
      a.category,
      if (a.minutes > 0) fmtMins(a.minutes),
      if (a.isOpen && a.dueDate != null) 'Due ${prettyDate(a.dueDate!)}',
      if (showOwner) a.userName,
      if (a.isAssigned) 'Assigned by ${a.assignedByName ?? 'manager'}',
    ];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: IconButton(
          tooltip: a.isOpen ? 'Mark done' : 'Reopen',
          icon: Icon(
            a.isOpen ? Icons.radio_button_unchecked : Icons.check_circle,
            color: a.isOpen ? theme.colorScheme.outline : statusColor(a.status),
          ),
          onPressed: canToggle
              ? () => Repo.toggleDone(a).catchError((Object e) {
                    if (context.mounted) showSnack(context, 'Update failed: $e');
                  })
              : null,
        ),
        title: Text(
          a.title,
          style: TextStyle(
            decoration: a.isOpen ? null : TextDecoration.lineThrough,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          bits.join('  •  '),
          style: TextStyle(color: a.isOverdue ? theme.colorScheme.error : null),
        ),
        trailing: StatusPill(a.isOverdue ? 'Overdue' : a.status),
      ),
    );
  }
}
