// App settings you can change without touching the rest of the code.
class AppConfig {
  static const appName = 'BM Work Tracker';

  // Usernames are turned into login e-mails like  ravi@bmworktracker.app
  // (no real mailbox needed). Do not change this after members are created.
  static const usernameDomain = 'bmworktracker.app';

  // The first (bootstrap) manager. Create this one login yourself in the
  // Firebase console (setup guide step 4). Keep in sync with firestore.rules.
  static const bootstrapManagerUsername = 'vignesh';
  static const bootstrapManagerName = 'Vignesh V';

  static const roleManager = 'manager';
  static const roleMember = 'member';

  static const categories = <String>[
    'RFQ / Quotation',
    'Supplier Follow-up',
    'Customer Follow-up',
    'Machining Prove-out',
    'Costing / Price Adjustment',
    'Engineering / Drawings',
    'Meeting / Call',
    'Documentation / MIS',
    'Other',
  ];

  static const statusDone = 'Done';
  static const statusInProgress = 'In Progress';
  static const statusPending = 'Pending';
  static const statuses = <String>[statusDone, statusInProgress, statusPending];
  static const openStatuses = <String>[statusInProgress, statusPending];

  // Daily target used for the progress bar (minutes) = 8 hours.
  static const dailyTargetMinutes = 480;
}

final _usernamePattern = RegExp(r'^[a-z0-9._-]{3,30}$');

String normaliseUsername(String u) => u.trim().toLowerCase();

bool isValidUsername(String u) => _usernamePattern.hasMatch(normaliseUsername(u));

/// "ravi" -> "ravi@bmworktracker.app". A full e-mail is used as typed.
String usernameToEmail(String u) {
  final n = normaliseUsername(u);
  return n.contains('@') ? n : '$n@${AppConfig.usernameDomain}';
}

String emailToUsername(String? email) {
  if (email == null) return '';
  final suffix = '@${AppConfig.usernameDomain}';
  return email.endsWith(suffix) ? email.substring(0, email.length - suffix.length) : email;
}

bool isBootstrapManager(String? email) =>
    email != null && email.toLowerCase() == usernameToEmail(AppConfig.bootstrapManagerUsername);
