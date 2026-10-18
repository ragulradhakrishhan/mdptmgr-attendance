import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'services.dart';
import 'staff_screen.dart';
import 'student_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  runApp(const MdptmgrApp());
}

class MdptmgrApp extends StatelessWidget {
  const MdptmgrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDPTMGR Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3949AB),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final u = snap.data;
        if (u == null) return const LoginScreen();
        return FutureBuilder<AppUser?>(
          future: Svc.currentProfile(u.uid),
          builder: (context, ps) {
            if (ps.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final p = ps.data;
            if (p == null) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Your account is not set up yet. Please contact the admin.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: Svc.signOut, child: const Text('Logout')),
                      ],
                    ),
                  ),
                ),
              );
            }
            switch (p.role) {
              case 'admin':
                return AdminHome(user: p);
              case 'staff':
                return StaffHome(user: p);
              default:
                return StudentHome(user: p);
            }
          },
        );
      },
    );
  }
}
