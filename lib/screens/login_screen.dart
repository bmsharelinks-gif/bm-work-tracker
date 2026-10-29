import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your username and password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: usernameToEmail(_user.text),
        password: _pass.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' =>
            'Wrong username or password',
          'user-disabled' => 'This login has been disabled',
          'too-many-requests' => 'Too many attempts. Please wait a few minutes.',
          'network-request-failed' => 'No internet connection',
          _ => 'Sign-in failed (${e.code})',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.assignment_turned_in, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(AppConfig.appName,
                      textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  Text('Bombay Metrics Sourcing',
                      textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _user,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Logins are created by your manager.\nForgot your password? Ask your manager.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets a signed-in user change their own password.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  String? error;
  bool busy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
            TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6)')),
            TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Repeat new password')),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error!, style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (next.text.length < 6) {
                      setState(() => error = 'New password must be at least 6 characters');
                      return;
                    }
                    if (next.text != confirm.text) {
                      setState(() => error = 'New passwords do not match');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final u = FirebaseAuth.instance.currentUser!;
                      await u.reauthenticateWithCredential(
                        EmailAuthProvider.credential(email: u.email!, password: current.text),
                      );
                      await u.updatePassword(next.text);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) showSnack(context, 'Password changed');
                      }
                    } on FirebaseAuthException catch (e) {
                      setState(() {
                        busy = false;
                        error = e.code == 'invalid-credential' || e.code == 'wrong-password'
                            ? 'Current password is wrong'
                            : 'Failed (${e.code})';
                      });
                    } catch (e) {
                      setState(() {
                        busy = false;
                        error = 'Failed: $e';
                      });
                    }
                  },
            child: const Text('Change'),
          ),
        ],
      ),
    ),
  );
}
