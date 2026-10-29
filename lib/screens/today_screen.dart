import 'package:flutter/material.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/activity_form.dart';
import '../widgets/activity_tile.dart';
import '../widgets/common.dart';

class TodayScreen extends StatefulWidget {
  final AppUser me;
  final VoidCallback onOpenPending;
  const TodayScreen({super.key, required this.me, required this.onOpenPending});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String _day = todayYmd();
  late Stream<List<Activity>> _dayStream;
  late final Stream<List<Activity>> _openStream;

  @override
  void initState() {
    super.initState();
    _dayStream = Repo.dayFor(widget.me.uid, _day);
    _openStream = Repo.openFor(widget.me.uid);
  }

  void _setDay(String d) => setState(() {
        _day = d;
        _dayStream = Repo.dayFor(widget.me.uid, _day);
      });

  void _shift(int days) {
    final d = parseYmd(_day);
    _setDay(ymd(DateTime(d.year, d.month, d.day + days)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday = _day == todayYmd();
    return StreamView<List<Activity>>(
      stream: _dayStream,
      builder: (context, items) {
        final mins = items.fold<int>(0, (s, a) => s + a.minutes);
        final done = items.where((a) => !a.isOpen).length;
        final progress = (mins / AppConfig.dailyTargetMinutes).clamp(0.0, 1.0);
        return ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Card(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                        Expanded(
                          child: TextButton(
                            onPressed: () async {
                              final p = await showDatePicker(
                                context: context,
                                initialDate: parseYmd(_day),
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                              );
                              if (p != null) _setDay(ymd(p));
                            },
                            child: Text(
                              isToday ? 'Today, ${prettyDate(_day)}' : prettyDate(_day),
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _Stat(label: 'Time logged', value: fmtMins(mins)),
                        _Stat(label: 'Entries', value: '${items.length}'),
                        _Stat(label: 'Done', value: '$done'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                    const SizedBox(height: 4),
                    Text('Target ${fmtMins(AppConfig.dailyTargetMinutes)}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<Activity>>(
              stream: _openStream,
              builder: (context, snap) {
                final open = snap.data ?? const <Activity>[];
                if (open.isEmpty) return const SizedBox.shrink();
                final overdue = open.where((a) => a.isOverdue).length;
                final assigned = open.where((a) => a.isAssigned).length;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  color: overdue > 0 ? theme.colorScheme.errorContainer : theme.colorScheme.secondaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions),
                    title: Text('${open.length} open follow-up${open.length == 1 ? '' : 's'}'
                        '${overdue > 0 ? ' • $overdue overdue' : ''}'),
                    subtitle: assigned > 0 ? Text('$assigned assigned by manager') : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onOpenPending,
                  ),
                );
              },
            ),
            if (items.isEmpty)
              const EmptyState(icon: Icons.edit_note, text: 'Nothing logged for this day.\nTap "Log work" to add an entry.')
            else
              for (final a in items)
                ActivityTile(a: a, onTap: () => showActivityForm(context, me: widget.me, existing: a)),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [Text(value, style: t.titleLarge), Text(label, style: t.bodySmall)]);
  }
}
