import 'package:flutter/material.dart';

import 'services.dart';

class AdminHome extends StatelessWidget {
  final AppUser user;
  const AdminHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin - MDPTMGR'),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: Svc.signOut),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Staff'),
            Tab(text: 'Students'),
            Tab(text: 'Contacts'),
          ]),
        ),
        body: const TabBarView(children: [
          StaffTab(),
          StudentsTab(),
          ContactsTab(),
        ]),
      ),
    );
  }
}

InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: suffix,
    );

class StaffTab extends StatefulWidget {
  const StaffTab({super.key});

  @override
  State<StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<StaffTab> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final Stream<List<AppUser>> _staff = Svc.usersByRole('staff');
  bool busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final email = _email.text.trim().toLowerCase();
    final pw = _pw.text;
    if (name.isEmpty || !email.contains('@') || pw.length < 6) {
      showMsg(context, 'Enter name, a valid Gmail and a password (min 6 characters)');
      return;
    }
    setState(() => busy = true);
    final ok = await guard(
        context,
        () => Svc.createAccount(
            email: email, password: pw, profile: {'role': 'staff', 'name': name}));
    if (ok) {
      _name.clear();
      _email.clear();
      _pw.clear();
      showMsg(context, 'Staff account created');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Add staff', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: _dec('Staff name')),
        const SizedBox(height: 12),
        TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: _dec('Gmail')),
        const SizedBox(height: 12),
        TextField(controller: _pw, decoration: _dec('Password')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : _create,
          child: busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create staff'),
        ),
        const Divider(height: 32),
        Text('All staff', style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder<List<AppUser>>(
          stream: _staff,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.isEmpty) return const Text('No staff yet');
            return Column(children: [
              for (final s in snap.data!)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.badge)),
                  title: Text(s.name),
                  subtitle: Text(s.email),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  final _sid = TextEditingController();
  final _name = TextEditingController();
  final _cls = TextEditingController();
  final _pw = TextEditingController(text: genPassword());
  final Stream<List<AppUser>> _students = Svc.usersByRole('student');
  bool busy = false;

  @override
  void dispose() {
    _sid.dispose();
    _name.dispose();
    _cls.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final sid = _sid.text.trim().toLowerCase();
    final name = _name.text.trim();
    final cls = Svc.normClass(_cls.text);
    final pw = _pw.text;
    if (!RegExp(r'^[a-z0-9._-]+$').hasMatch(sid)) {
      showMsg(context, 'Student ID: only letters, numbers, . _ - (no spaces)');
      return;
    }
    if (name.isEmpty || cls.isEmpty || pw.length < 6) {
      showMsg(context, 'Enter name, class and a password (min 6 characters)');
      return;
    }
    setState(() => busy = true);
    final ok = await guard(
        context,
        () => Svc.createAccount(
              email: Svc.toEmail(sid),
              password: pw,
              profile: {
                'role': 'student',
                'name': name,
                'studentId': sid,
                'className': cls,
              },
            ));
    if (ok && mounted) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Student created'),
          content: SelectableText('Name: $name\nStudent ID: $sid\nPassword: $pw\n\nShare these with the student.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      _sid.clear();
      _name.clear();
      _pw.text = genPassword();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Add student', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
            controller: _sid,
            autocorrect: false,
            decoration: _dec('Unique student ID (e.g. 23bcs001)')),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: _dec('Student name')),
        const SizedBox(height: 12),
        TextField(controller: _cls, decoration: _dec('Class (e.g. III B.Sc CS)')),
        const SizedBox(height: 12),
        TextField(
          controller: _pw,
          decoration: _dec('Password',
              suffix: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Generate',
                onPressed: () => setState(() => _pw.text = genPassword()),
              )),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : _create,
          child: busy
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create student'),
        ),
        const Divider(height: 32),
        Text('All students', style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder<List<AppUser>>(
          stream: _students,
          builder: (context, snap) {
            if (snap.hasError) return Text('${snap.error}');
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.isEmpty) return const Text('No students yet');
            return Column(children: [
              for (final s in snap.data!)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(s.name),
                  subtitle: Text('${s.studentId}  |  ${s.className}'),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  static const _fields = <String, String>{
    'tutorName': 'Class Tutor name',
    'tutorPhone': 'Class Tutor phone',
    'hodName': 'HOD name',
    'hodPhone': 'HOD phone',
    'principalName': 'Principal name',
    'principalPhone': 'Principal phone',
  };
  final Map<String, TextEditingController> _c = {
    for (final k in _fields.keys) k: TextEditingController(),
  };
  final Stream<List<AppUser>> _students = Svc.usersByRole('student');
  String? cls;
  bool busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(String? v) async {
    if (v == null) return;
    setState(() => cls = v);
    Map<String, dynamic> m = {};
    await guard(context, () async {
      final d = await Svc.db.collection('contacts').doc(Svc.normClass(v)).get();
      m = d.data() ?? <String, dynamic>{};
    });
    for (final k in _fields.keys) {
      _c[k]!.text = (m[k] ?? '').toString();
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    final ok = await guard(
        context,
        () => Svc.saveContacts(cls!, {
              for (final k in _fields.keys) k: _c[k]!.text.trim(),
            }));
    if (ok) showMsg(context, 'Contacts saved');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: _students,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final classes = snap.data!.map((e) => e.className).toSet().toList()..sort();
        if (classes.isEmpty) {
          return const Center(child: Text('Add students first, then set class contacts.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: classes.contains(cls) ? cls : null,
              hint: const Text('Select class'),
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [for (final c in classes) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: _pick,
            ),
            if (cls != null) ...[
              const SizedBox(height: 12),
              for (final e in _fields.entries) ...[
                TextField(
                  controller: _c[e.key],
                  keyboardType: e.key.endsWith('Phone')
                      ? TextInputType.phone
                      : TextInputType.text,
                  decoration: _dec(e.value),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: busy ? null : _save,
                child: const Text('Save contacts'),
              ),
            ],
          ],
        );
      },
    );
  }
}
