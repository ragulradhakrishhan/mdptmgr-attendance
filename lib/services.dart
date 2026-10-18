import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

/// Students log in with their unique ID; internally it is stored as an email.
const emailDomain = 'mdptmgr.app';

final DateFormat _keyFmt = DateFormat('yyyy-MM-dd');
String dateKey(DateTime d) => _keyFmt.format(d);

class AppUser {
  final String uid, role, name, email, studentId, className;
  const AppUser({
    required this.uid,
    required this.role,
    required this.name,
    required this.email,
    required this.studentId,
    required this.className,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? <String, dynamic>{};
    String s(String k) => (m[k] ?? '').toString();
    return AppUser(
      uid: d.id,
      role: s('role'),
      name: s('name'),
      email: s('email'),
      studentId: s('studentId'),
      className: s('className'),
    );
  }
}

class Svc {
  static final FirebaseAuth auth = FirebaseAuth.instance;
  static final FirebaseFirestore db = FirebaseFirestore.instance;

  static String toEmail(String input) {
    final v = input.trim().toLowerCase();
    return v.contains('@') ? v : '$v@$emailDomain';
  }

  static String normClass(String c) =>
      c.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll('/', '-');

  static Future<void> signIn(String id, String password) =>
      auth.signInWithEmailAndPassword(email: toEmail(id), password: password);

  static Future<void> signOut() => auth.signOut();

  static Future<AppUser?> currentProfile(String uid) async {
    final d = await db.collection('users').doc(uid).get();
    if (!d.exists) return null;
    return AppUser.fromDoc(d);
  }

  /// Creates a login (Auth) + profile (Firestore) without logging the admin out.
  static Future<void> createAccount({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    FirebaseApp app;
    try {
      app = Firebase.app('creator');
    } catch (_) {
      app = await Firebase.initializeApp(name: 'creator', options: firebaseOptions);
    }
    final creatorAuth = FirebaseAuth.instanceFor(app: app);
    final cred = await creatorAuth.createUserWithEmailAndPassword(
        email: email, password: password);
    await db.collection('users').doc(cred.user!.uid).set({
      ...profile,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await creatorAuth.signOut();
  }

  static Stream<List<AppUser>> usersByRole(String role) => db
      .collection('users')
      .where('role', isEqualTo: role)
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  static Future<Map<String, String>> attendanceFor(
      String className, String date) async {
    final s = await db
        .collection('attendance')
        .where('className', isEqualTo: className)
        .where('date', isEqualTo: date)
        .get();
    return {
      for (final d in s.docs) (d['uid'] as String): (d['status'] as String),
    };
  }

  static Future<void> saveAttendance(String className, String date,
      Map<String, String> status, String markedBy) async {
    final batch = db.batch();
    status.forEach((uid, st) {
      batch.set(db.collection('attendance').doc('${date}_$uid'), {
        'uid': uid,
        'className': className,
        'date': date,
        'status': st,
        'markedBy': markedBy,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  }

  /// date (yyyy-MM-dd) -> 'P' or 'A' for one student.
  static Stream<Map<String, String>> myAttendance(String uid) => db
      .collection('attendance')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map((s) => {
            for (final d in s.docs) (d['date'] as String): (d['status'] as String),
          });

  static Stream<Map<String, dynamic>?> contacts(String className) =>
      db.collection('contacts').doc(normClass(className)).snapshots().map((d) => d.data());

  static Future<void> saveContacts(String className, Map<String, dynamic> data) =>
      db.collection('contacts').doc(normClass(className)).set(data);
}

String genPassword() {
  const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

String authMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-email':
      return 'Wrong ID / email or password';
    case 'network-request-failed':
      return 'No internet connection';
    case 'email-already-in-use':
      return 'This ID / email already exists';
    case 'weak-password':
      return 'Password must be at least 6 characters';
    case 'too-many-requests':
      return 'Too many attempts. Try again later';
    default:
      return e.message ?? e.code;
  }
}

void showMsg(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Runs [f]; shows an error snackbar and returns false when it fails.
Future<bool> guard(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
    return true;
  } on FirebaseAuthException catch (e) {
    showMsg(context, authMessage(e));
  } on FirebaseException catch (e) {
    showMsg(context, e.code == 'permission-denied'
        ? 'Permission denied. Check Firestore rules.'
        : (e.message ?? e.code));
  } catch (e) {
    showMsg(context, '$e');
  }
  return false;
}
