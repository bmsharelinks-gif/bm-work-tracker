import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'config.dart';

final _ymd = DateFormat('yyyy-MM-dd');

String ymd(DateTime d) => _ymd.format(d);
DateTime parseYmd(String s) => _ymd.parse(s);
String todayYmd() => ymd(DateTime.now());
String prettyDate(String s) => DateFormat('EEE, d MMM').format(parseYmd(s));

String fmtMins(int m) {
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0) return '${r}m';
  if (r == 0) return '${h}h';
  return '${h}h ${r}m';
}

/// Monday..Sunday of the week containing [d], as yyyy-MM-dd strings.
List<String> weekOf(DateTime d) {
  final offset = d.weekday - 1;
  return List.generate(7, (i) => ymd(DateTime(d.year, d.month, d.day - offset + i)));
}

class AppUser {
  final String uid;
  final String name;
  final String username;
  final String role;
  final bool active;

  const AppUser({
    required this.uid,
    required this.name,
    required this.username,
    required this.role,
    required this.active,
  });

  bool get isManager => role == AppConfig.roleManager;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: d.id,
      name: (m['name'] as String?) ?? '',
      username: (m['username'] as String?) ?? '',
      role: (m['role'] as String?) ?? AppConfig.roleMember,
      active: (m['active'] as bool?) ?? false,
    );
  }
}

class Activity {
  final String id;
  final String uid;
  final String userName;
  final String title;
  final String category;
  final String status;
  final int minutes;
  final String date; // work date yyyy-MM-dd
  final String? dueDate;
  final String? completedDate;
  final String notes;
  final String? assignedById;
  final String? assignedByName;
  final DateTime? createdAt;

  const Activity({
    required this.id,
    required this.uid,
    required this.userName,
    required this.title,
    required this.category,
    required this.status,
    required this.minutes,
    required this.date,
    this.dueDate,
    this.completedDate,
    required this.notes,
    this.assignedById,
    this.assignedByName,
    this.createdAt,
  });

  bool get isOpen => status != AppConfig.statusDone;
  bool get isAssigned => assignedById != null;
  bool get isOverdue => isOpen && dueDate != null && dueDate!.compareTo(todayYmd()) < 0;
  bool get isDueToday => isOpen && dueDate == todayYmd();

  factory Activity.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const <String, dynamic>{};
    final ts = m['createdAt'];
    return Activity(
      id: d.id,
      uid: (m['uid'] as String?) ?? '',
      userName: (m['userName'] as String?) ?? '',
      title: (m['title'] as String?) ?? '',
      category: (m['category'] as String?) ?? 'Other',
      status: (m['status'] as String?) ?? AppConfig.statusPending,
      minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      date: (m['date'] as String?) ?? todayYmd(),
      dueDate: m['dueDate'] as String?,
      completedDate: m['completedDate'] as String?,
      notes: (m['notes'] as String?) ?? '',
      assignedById: m['assignedById'] as String?,
      assignedByName: m['assignedByName'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

/// Newest first; items still being saved (no server time yet) go on top.
int byCreatedDesc(Activity a, Activity b) {
  final x = a.createdAt, y = b.createdAt;
  if (x == null && y == null) return 0;
  if (x == null) return -1;
  if (y == null) return 1;
  return y.compareTo(x);
}
