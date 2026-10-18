import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String role = 'student';
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool busy = false;
  bool hide = true;
  String? error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _pw.text.isEmpty) {
      setState(() => error = 'Enter your login and password');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Svc.signIn(_id.text, _pw.text);
      final u = Svc.auth.currentUser;
      final p = u == null ? null : await Svc.currentProfile(u.uid);
      if (p == null || p.role != role) {
        await Svc.signOut();
        if (mounted) {
          setState(() => error = p == null
              ? 'Account not set up. Contact the admin.'
              : 'This account is not a $role login. Choose the right tab.');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => error = authMessage(e));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final idLabel = role == 'student' ? 'Student ID' : 'Gmail';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.fact_check_rounded, size: 72, color: cs.primary),
                  const SizedBox(height: 8),
                  Text('MDPTMGR Attendance',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 'student', label: Text('Student')),
                      ButtonSegment(value: 'staff', label: Text('Staff')),
                      ButtonSegment(value: 'admin', label: Text('Admin')),
                    ],
                    selected: {role},
                    onSelectionChanged: (s) => setState(() {
                      role = s.first;
                      error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _id,
                    keyboardType: role == 'student'
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: idLabel,
                      prefixIcon: const Icon(Icons.person),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: hide,
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(hide ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => hide = !hide),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: busy ? null : _login,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Login'),
                    ),
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
