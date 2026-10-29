import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config.dart';
import 'models.dart';

/// All reads/writes to the Firestore database live here.
class Repo {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _acts => _db.collection('activities');
  static CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  static List<Activity> _toActs(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(Activity.fromDoc).toList()..sort(byCreatedDesc);

  // ---------- users ----------
  static Stream<AppUser?> userDoc(String uid) =>
      _users.doc(uid).snapshots().map((d) => d.exists ? AppUser.fromDoc(d) : null);

  static Stream<List<AppUser>> allUsers() => _users.snapshots().map((s) {
        final list = s.docs.map(AppUser.fromDoc).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return list;
      });

  /// Creates the profile for the bootstrap manager on first login.
  static Future<void> createBootstrapProfile(User u) => _users.doc(u.uid).set({
        'name': AppConfig.bootstrapManagerName,
        'username': AppConfig.bootstrapManagerUsername,
        'role': AppConfig.roleManager,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// Manager adds a member login. Uses a second Firebase "app" so the
  /// manager stays signed in while the new account is created.
  static Future<void> createMember({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    const helperName = 'memberCreator';
    final helper = Firebase.apps.any((a) => a.name == helperName)
        ? Firebase.app(helperName)
        : await Firebase.initializeApp(name: helperName, options: Firebase.app().options);
    final helperAuth = FirebaseAuth.instanceFor(app: helper);
    final cred = await helperAuth.createUserWithEmailAndPassword(
      email: usernameToEmail(username),
      password: password,
    );
    final uid = cred.user!.uid;
    await helperAuth.signOut();
    await _users.doc(uid).set({
      'name': name.trim(),
      'username': normaliseUsername(username),
      'role': role,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> setUserActive(String uid, bool active) =>
      _users.doc(uid).update({'active': active});

  static Future<void> setUserRole(String uid, String role) =>
      _users.doc(uid).update({'role': role});

  static Future<void> renameUser(String uid, String name) =>
      _users.doc(uid).update({'name': name.trim()});

  // ---------- activities ----------
  static Stream<List<Activity>> dayFor(String uid, String date) => _acts
      .where('uid', isEqualTo: uid)
      .where('date', isEqualTo: date)
      .snapshots()
      .map(_toActs);

  static Stream<List<Activity>> openFor(String uid) => _acts
      .where('uid', isEqualTo: uid)
      .where('status', whereIn: AppConfig.openStatuses)
      .snapshots()
      .map(_toActs);

  /// uid == null -> whole team (managers only).
  static Stream<List<Activity>> forDates(List<String> dates, {String? uid}) {
    Query<Map<String, dynamic>> q = _acts.where('date', whereIn: dates);
    if (uid != null) q = q.where('uid', isEqualTo: uid);
    return q.snapshots().map(_toActs);
  }

  /// All open items of the whole team (managers only).
  static Stream<List<Activity>> teamOpen() =>
      _acts.where('status', whereIn: AppConfig.openStatuses).snapshots().map(_toActs);

  static Future<void> addActivity(Map<String, dynamic> data) => _acts.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateActivity(String id, Map<String, dynamic> data) =>
      _acts.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> deleteActivity(String id) => _acts.doc(id).delete();

  static Future<void> toggleDone(Activity a) => updateActivity(a.id, {
        'status': a.isOpen ? AppConfig.statusDone : AppConfig.statusPending,
        'completedDate': a.isOpen ? todayYmd() : null,
      });
}
