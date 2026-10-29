import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import '../widgets/common.dart';

const _allTeam = '__ALL__';

class SummaryScreen extends StatefulWidget {
  final AppUser me;
  final List<AppUser>? members; // non-null for managers
  const SummaryScreen({super.key, required this.me, this.members});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _week = false;
  DateTime _anchor = DateTime.now();
  late String _scope = widget.me.uid;
  late Stream<List<Activity>> _stream;

  List<String> get _dates => _week ? weekOf(_anchor) : [ymd(_anchor)];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _stream = Repo.forDates(_dates, uid: _scope == _allTeam ? null : _scope);
  }

  void _update(VoidCallback change) => setState(() {
        change();
        _reload();
      });

  void _shift(int dir) => _update(() {
        final n = _week ? 7 * dir : dir;
        _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + n);
      });

  String get _periodLabel {
    final d = _dates;
    return _week ? '${prettyDate(d.first)} – ${prettyDate(d.last)}' : prettyDate(d.first);
  }

  String get _scopeName {
    if (_scope == _allTeam) return 'Sourcing team';
    if (_scope == widget.me.uid) return widget.me.name;
    final m = widget.members?.where((u) => u.uid == _scope);
    return (m == null || m.isEmpty) ? '' : m.first.name;
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Day'), icon: Icon(Icons.today)),
                  ButtonSegment(value: true, label: Text('Week'), icon: Icon(Icons.date_range)),
                ],
                selected: {_week},
                onSelectionChanged: (s) => _update(() => _week = s.first),
              ),
              if (members != null) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Show',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      isDense: true,
                      value: (_scope == _allTeam ||
                              _scope == widget.me.uid ||
                              members.any((u) => u.uid == _scope))
                          ? _scope
                          : widget.me.uid,
                      items: [
                        const DropdownMenuItem(value: _allTeam, child: Text('Whole team')),
                        DropdownMenuItem(value: widget.me.uid, child: Text('Me (${widget.me.name})')),
                        for (final u in members.where((u) => u.uid != widget.me.uid))
                          DropdownMenuItem(value: u.uid, child: Text(u.name)),
                      ],
                      onChanged: (v) => _update(() => _scope = v ?? widget.me.uid),
                    ),
                  ),
                ),
              ],
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                  Expanded(child: Text(_periodLabel, textAlign: TextAlign.center)),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamView<List<Activity>>(
            stream: _stream,
            builder: (context, items) => _SummaryBody(
              items: items,
              dates: _dates,
              week: _week,
              team: _scope == _allTeam,
              header: '$_scopeName — $_periodLabel',
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryBody extends StatelessWidget {
  final List<Activity> items;
  final List<String> dates;
  final bool week;
  final bool team;
  final String header;

  const _SummaryBody({
    required this.items,
    required this.dates,
    required this.week,
    required this.team,
    required this.header,
  });

  Map<String, int> _sumBy(String Function(Activity) key) {
    final m = <String, int>{};
    for (final a in items) {
      m[key(a)] = (m[key(a)] ?? 0) + a.minutes;
    }
    return m;
  }

  String _asText() {
    final b = StringBuffer('Work summary: $header\n');
    final total = items.fold<int>(0, (s, a) => s + a.minutes);
    final done = items.where((a) => !a.isOpen).length;
    b.writeln('Total time: ${fmtMins(total)} | Entries: ${items.length} | Done: $done | Open: ${items.length - done}');
    final sorted = [...items]..sort((a, b) => a.date.compareTo(b.date));
    String? lastDate;
    for (final a in sorted) {
      if (week && a.date != lastDate) {
        b.writeln('\n${prettyDate(a.date)}');
        lastDate = a.date;
      }
      final who = team ? '${a.userName}: ' : '';
      final time = a.minutes > 0 ? ' (${fmtMins(a.minutes)})' : '';
      b.writeln('- $who${a.title} [${a.category}] - ${a.status}$time');
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const EmptyState(icon: Icons.bar_chart, text: 'No entries for this period.');

    final total = items.fold<int>(0, (s, a) => s + a.minutes);
    final done = items.where((a) => !a.isOpen).length;
    final byCat = _sumBy((a) => a.category).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final byPerson = _sumBy((a) => a.userName).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final byDay = _sumBy((a) => a.date);

    Widget bar(String label, int mins, int max) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              SizedBox(width: 150, child: Text(label, overflow: TextOverflow.ellipsis)),
              Expanded(
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : mins / max,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              SizedBox(width: 64, child: Text(fmtMins(mins), textAlign: TextAlign.right)),
            ],
          ),
        );

    final maxCat = byCat.isEmpty ? 0 : byCat.first.value;
    final maxPerson = byPerson.isEmpty ? 0 : byPerson.first.value;
    final maxDay = byDay.values.fold<int>(0, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _big(theme, fmtMins(total), 'Total time'),
                _big(theme, '${items.length}', 'Entries'),
                _big(theme, '$done', 'Done'),
                _big(theme, '${items.length - done}', 'Open'),
              ],
            ),
          ),
        ),
        const SectionHeader('Time by category'),
        for (final e in byCat) bar(e.key, e.value, maxCat),
        if (week) ...[
          const SectionHeader('Time by day'),
          for (final d in dates) bar(prettyDate(d), byDay[d] ?? 0, maxDay),
        ],
        if (team) ...[
          const SectionHeader('Time by person'),
          for (final e in byPerson) bar(e.key, e.value, maxPerson),
        ],
        const SectionHeader('Status'),
        for (final s in AppConfig.statuses)
          ListTile(
            dense: true,
            leading: Icon(Icons.circle, color: statusColor(s), size: 14),
            title: Text(s),
            trailing: Text('${items.where((a) => a.status == s).length}'),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy summary (for WhatsApp / email)'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _asText()));
              if (context.mounted) showSnack(context, 'Summary copied');
            },
          ),
        ),
      ],
    );
  }

  Widget _big(ThemeData theme, String value, String label) =>
      Column(children: [Text(value, style: theme.textTheme.titleLarge), Text(label, style: theme.textTheme.bodySmall)]);
}
