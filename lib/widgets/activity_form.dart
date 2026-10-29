import 'package:flutter/material.dart';

import '../config.dart';
import '../data.dart';
import '../models.dart';
import 'common.dart';

/// Opens the add / edit / assign sheet.
///  - [existing] given      -> edit that item
///  - [assignees] given     -> manager "assign task" mode (pick a member)
///  - otherwise             -> log my own work
Future<void> showActivityForm(
  BuildContext context, {
  required AppUser me,
  Activity? existing,
  List<AppUser>? assignees,
  AppUser? presetAssignee,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _ActivityForm(
        me: me,
        existing: existing,
        assignees: assignees,
        presetAssignee: presetAssignee,
      ),
    ),
  );
}

class _ActivityForm extends StatefulWidget {
  final AppUser me;
  final Activity? existing;
  final List<AppUser>? assignees;
  final AppUser? presetAssignee;

  const _ActivityForm({required this.me, this.existing, this.assignees, this.presetAssignee});

  @override
  State<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<_ActivityForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _minutes;
  late String _category;
  late String _status;
  late String _date;
  String? _dueDate;
  AppUser? _assignee;
  bool _saving = false;

  bool get _assignMode => widget.assignees != null && widget.existing == null;
  bool get _canDelete {
    final e = widget.existing;
    if (e == null) return false;
    return widget.me.isManager || !e.isAssigned;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _minutes = TextEditingController(text: e == null || e.minutes == 0 ? '' : '${e.minutes}');
    _category = e?.category ?? AppConfig.categories.first;
    if (!AppConfig.categories.contains(_category)) _category = 'Other';
    _status = e?.status ?? (_assignMode ? AppConfig.statusPending : AppConfig.statusDone);
    _date = e?.date ?? todayYmd();
    _dueDate = e?.dueDate;
    _assignee = widget.presetAssignee;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<String?> _pickDate(String? current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null ? parseYmd(current) : DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    return picked == null ? null : ymd(picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_assignMode && _assignee == null) {
      showSnack(context, 'Please choose a team member');
      return;
    }
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'category': _category,
      'status': _status,
      'minutes': int.tryParse(_minutes.text.trim()) ?? 0,
      'date': _date,
      'dueDate': _dueDate,
      'notes': _notes.text.trim(),
      'completedDate': _status == AppConfig.statusDone
          ? (widget.existing?.completedDate ?? todayYmd())
          : null,
    };
    try {
      final e = widget.existing;
      if (e != null) {
        await Repo.updateActivity(e.id, data);
      } else {
        final target = _assignee ?? widget.me;
        data['uid'] = target.uid;
        data['userName'] = target.name;
        if (target.uid != widget.me.uid) {
          data['assignedById'] = widget.me.uid;
          data['assignedByName'] = widget.me.name;
        }
        await Repo.addActivity(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Save failed: $err');
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Repo.deleteActivity(widget.existing!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.existing;
    final heading = e != null
        ? 'Edit entry'
        : _assignMode
            ? 'Assign a task'
            : 'Log work';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(heading, style: Theme.of(context).textTheme.titleLarge)),
                if (_canDelete)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _saving ? null : _delete,
                  ),
              ],
            ),
            if (e != null && e.isAssigned)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Assigned by ${e.assignedByName ?? 'manager'}'),
              ),
            const SizedBox(height: 8),
            if (_assignMode) ...[
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Assign to', border: OutlineInputBorder()),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    isDense: true,
                    hint: const Text('Choose team member'),
                    value: _assignee?.uid,
                    items: [
                      for (final u in widget.assignees!)
                        DropdownMenuItem(value: u.uid, child: Text(u.name)),
                    ],
                    onChanged: (v) => setState(
                      () => _assignee = widget.assignees!.firstWhere((u) => u.uid == v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _title,
              autofocus: e == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What was done / to do',
                hintText: 'e.g. Followed up ABC Castings on PPAP samples',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a short description' : null,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: _category,
                  items: [
                    for (final c in AppConfig.categories) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Status', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: [
                for (final s in AppConfig.statuses) ButtonSegment(value: s, label: Text(s)),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _minutes,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Time spent (minutes)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 0 || n > 1440) return 'Enter minutes between 0 and 1440';
                return null;
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final m in const [15, 30, 60, 90, 120, 240])
                  ActionChip(
                    label: Text(fmtMins(m)),
                    onPressed: () => setState(() => _minutes.text = '$m'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.today),
                    label: Text('Work date: ${prettyDate(_date)}'),
                    onPressed: () async {
                      final d = await _pickDate(_date);
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_dueDate == null ? 'Add due date (follow-up)' : 'Due: ${prettyDate(_dueDate!)}'),
                    onPressed: () async {
                      final d = await _pickDate(_dueDate);
                      if (d != null) setState(() => _dueDate = d);
                    },
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    tooltip: 'Remove due date',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_assignMode ? 'Assign' : 'Save'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
