import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services.dart';

class StaffHome extends StatefulWidget {
  final AppUser user;
  const StaffHome({super.key, required this.user});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  final Stream<List<AppUser>> _students = Svc.usersByRole('student');
  String? cls;
  DateTime date = DateTime.now();
  Map<String, String> status = {};
  bool busy = false;

  Future<void> _load() async {
    final c = cls;
    if (c == null) return;
    setState(() => busy = true);
    Map<String, String> m = {};
    await guard(context, () async {
      m = await Svc.attendanceFor(c, dateKey(date));
    });
    if (!mounted) return;
    setState(() {
      status = m;
      busy = false;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => date = d);
      _load();
    }
  }

  Future<void> _save(List<AppUser> list) async {
    final ids = list.map((e) => e.uid).toSet();
    final toSave = {
      for (final e in status.entries)
        if (ids.contains(e.key)) e.key: e.value
    };
    if (toSave.isEmpty) {
      showMsg(context, 'Mark at least one student');
      return;
    }
    setState(() => busy = true);
    final ok = await guard(context,
        () => Svc.saveAttendance(cls!, dateKey(date), toSave, widget.user.uid));
    if (ok) showMsg(context, 'Attendance saved');
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MDPTMGR Attendance'),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: Svc.signOut),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: _students,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data!;
          final classes = all.map((e) => e.className).toSet().toList()..sort();
          final list = all.where((e) => e.className == cls).toList();
          var p = 0, a = 0;
          for (final s in list) {
            final v = status[s.uid];
            if (v == 'P') p++;
            if (v == 'A') a++;
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: classes.contains(cls) ? cls : null,
                      hint: const Text('Select class'),
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: [
                        for (final c in classes) DropdownMenuItem(value: c, child: Text(c))
                      ],
                      onChanged: (v) {
                        setState(() {
                          cls = v;
                          status = {};
                        });
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('dd MMM').format(date)),
                  ),
                ]),
              ),
              if (cls != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    Text('P: $p   A: $a   Total: ${list.length}'),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final s in list) {
                          status[s.uid] = 'P';
                        }
                      }),
                      child: const Text('All Present'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final s in list) {
                          status[s.uid] = 'A';
                        }
                      }),
                      child: const Text('All Absent'),
                    ),
                  ]),
                ),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: cls == null
                    ? Center(
                        child: Text(classes.isEmpty
                            ? 'No students yet. Ask the admin to add students.'
                            : 'Select a class to mark attendance'))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final cur = status[s.uid];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(s.studentId,
                                        style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                emptySelectionAllowed: true,
                                segments: const [
                                  ButtonSegment(value: 'P', label: Text('P')),
                                  ButtonSegment(value: 'A', label: Text('A')),
                                ],
                                selected: cur == null ? <String>{} : {cur},
                                onSelectionChanged: (sel) => setState(() {
                                  if (sel.isEmpty) {
                                    status.remove(s.uid);
                                  } else {
                                    status[s.uid] = sel.first;
                                  }
                                }),
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                                    if (!states.contains(WidgetState.selected)) return null;
                                    return cur == 'P'
                                        ? Colors.green.shade200
                                        : Colors.red.shade200;
                                  }),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
              ),
              if (cls != null)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => _save(list),
                        icon: const Icon(Icons.save),
                        label: const Text('Save Attendance'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
