import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'services.dart';

Color statusColor(String? s) =>
    s == 'P' ? Colors.green : (s == 'A' ? Colors.red : Colors.grey);
String statusText(String? s) =>
    s == 'P' ? 'Present' : (s == 'A' ? 'Absent' : 'Not marked');

class StudentHome extends StatelessWidget {
  final AppUser user;
  const StudentHome({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MDPTMGR Attendance'),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: Svc.signOut),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Contact'),
          ]),
        ),
        body: StreamBuilder<Map<String, String>>(
          stream: Svc.myAttendance(user.uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('${snap.error}'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;
            return TabBarView(children: [
              DailyTab(user: user, data: data),
              WeeklyTab(data: data),
              MonthlyTab(data: data),
              ContactTab(user: user),
            ]);
          },
        ),
      ),
    );
  }
}

class SummaryCard extends StatelessWidget {
  final int present, absent;
  const SummaryCard({super.key, required this.present, required this.absent});

  @override
  Widget build(BuildContext context) {
    final total = present + absent;
    final pct = total == 0 ? 0.0 : present * 100 / total;
    Widget stat(String label, String value, Color c) => Expanded(
          child: Column(children: [
            Text(value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: c)),
            Text(label),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          stat('Present', '$present', Colors.green),
          stat('Absent', '$absent', Colors.red),
          stat('Percentage', '${pct.toStringAsFixed(1)}%',
              Theme.of(context).colorScheme.primary),
        ]),
      ),
    );
  }
}

class DayTile extends StatelessWidget {
  final DateTime day;
  final String? status;
  const DayTile({super.key, required this.day, required this.status});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(DateFormat('EEE, dd MMM yyyy').format(day)),
      trailing: Chip(
        label: Text(statusText(status),
            style: const TextStyle(color: Colors.white, fontSize: 12)),
        backgroundColor: statusColor(status),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class DailyTab extends StatefulWidget {
  final AppUser user;
  final Map<String, String> data;
  const DailyTab({super.key, required this.user, required this.data});

  @override
  State<DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<DailyTab> {
  DateTime date = DateTime.now();

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => date = d);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.data[dateKey(date)];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(widget.user.name),
            subtitle: Text('ID: ${widget.user.studentId}\n${widget.user.className}'),
            isThreeLine: true,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.calendar_today),
          label: Text(DateFormat('EEEE, dd MMM yyyy').format(date)),
        ),
        const SizedBox(height: 24),
        Card(
          color: statusColor(st).withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(
                  st == 'P'
                      ? Icons.check_circle
                      : (st == 'A' ? Icons.cancel : Icons.help_outline),
                  size: 64,
                  color: statusColor(st)),
              const SizedBox(height: 8),
              Text(statusText(st),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: statusColor(st))),
            ]),
          ),
        ),
      ],
    );
  }
}

class WeeklyTab extends StatelessWidget {
  final Map<String, String> data;
  const WeeklyTab({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final days = List.generate(
        7, (i) => DateTime(monday.year, monday.month, monday.day + i));
    var p = 0, a = 0;
    for (final d in days) {
      final s = data[dateKey(d)];
      if (s == 'P') p++;
      if (s == 'A') a++;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('This week', style: Theme.of(context).textTheme.titleMedium),
        SummaryCard(present: p, absent: a),
        for (final d in days) DayTile(day: d, status: data[dateKey(d)]),
      ],
    );
  }
}

class MonthlyTab extends StatefulWidget {
  final Map<String, String> data;
  const MonthlyTab({super.key, required this.data});

  @override
  State<MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<MonthlyTab> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final count = DateTime(month.year, month.month + 1, 0).day;
    final days = List.generate(count, (i) => DateTime(month.year, month.month, i + 1));
    var p = 0, a = 0;
    for (final d in days) {
      final s = widget.data[dateKey(d)];
      if (s == 'P') p++;
      if (s == 'A') a++;
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month - 1))),
            Text(DateFormat('MMMM yyyy').format(month),
                style: Theme.of(context).textTheme.titleMedium),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(
                    () => month = DateTime(month.year, month.month + 1))),
          ],
        ),
        SummaryCard(present: p, absent: a),
        for (final d in days) DayTile(day: d, status: widget.data[dateKey(d)]),
      ],
    );
  }
}

class ContactTab extends StatelessWidget {
  final AppUser user;
  const ContactTab({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: Svc.contacts(user.className),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final m = snap.data ?? <String, dynamic>{};
        String v(String k) => (m[k] ?? '').toString();
        Widget card(String title, IconData icon, String name, String phone) => Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(icon)),
                title: Text(name.isEmpty ? 'Not added yet' : name),
                subtitle: SelectableText('$title${phone.isEmpty ? '' : '\n$phone'}'),
                isThreeLine: phone.isNotEmpty,
              ),
            );
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            card('Class Tutor', Icons.school, v('tutorName'), v('tutorPhone')),
            card('Head of Department', Icons.account_balance, v('hodName'), v('hodPhone')),
            card('Principal', Icons.workspace_premium, v('principalName'), v('principalPhone')),
          ],
        );
      },
    );
  }
}
