import 'package:flutter/material.dart';

import '../data.dart';
import 'shared.dart';
import 'task.dart';

class DivisionDetailPage extends StatefulWidget {
  const DivisionDetailPage({
    super.key,
    required this.repo,
    required this.event,
    required this.division,
    required this.profile,
    required this.users,
  });

  final CmsRepository repo;
  final DbRow event;
  final DbRow division;
  final DbRow profile;
  final List<DbRow> users;

  @override
  State<DivisionDetailPage> createState() => _DivisionDetailPageState();
}

class _DivisionDetailPageState extends State<DivisionDetailPage> {
  late Future<List<dynamic>> future;
  CmsRepository get repo => widget.repo;
  bool get manager =>
      widget.profile['role'] == 'admin' ||
      widget.event['ketua_panitia_id'] == repo.uid;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
    repo.rows('members', column: 'division_id', value: widget.division['id']),
    repo.rows('tasks', column: 'division_id', value: widget.division['id']),
  ]);

  void reload() {
    setState(() {
      future = _load();
    });
  }

  Future<void> editDivision() async {
    final result = await editRecord(
      context,
      title: 'Edit divisi',
      initial: widget.division,
      fields: const [Field('name', 'Nama divisi')],
      save: (values) async {
        await repo.save('divisions', values, widget.division['id']);
        widget.division.addAll(values);
      },
    );
    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> deleteDivision() async {
    if (!await confirmDelete(context, widget.division['name'])) return;
    try {
      await repo.remove('divisions', widget.division['id']);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) notifyError(context, error);
    }
  }

  Future<void> editTask(List<DbRow> members, [DbRow? task]) async {
    final memberIds = members.map((member) => member['user_id']).toSet();
    final result = await editRecord(
      context,
      title: task == null ? 'Buat tugas' : 'Edit tugas',
      initial: task,
      fields: [
        const Field('title', 'Judul tugas'),
        const Field('description', 'Deskripsi', required: false, lines: 3),
        Field(
          'assigned_to',
          'PIC',
          required: false,
          options: {
            for (final user in widget.users.where(
              (user) => memberIds.contains(user['id']),
            ))
              user['id']: user['name'],
          },
        ),
        const Field('deadline', 'Deadline', kind: 'datetime', required: false),
        const Field('priority', 'Prioritas', options: priorityLabels),
        const Field('status', 'Status', options: statusLabels),
      ],
      save: (values) => repo.save('tasks', {
        'division_id': widget.division['id'],
        ...values,
      }, task?['id']),
    );
    if (result == true) reload();
  }

  Future<void> deleteTask(DbRow task) async {
    if (!await confirmDelete(context, task['title'])) return;
    try {
      await repo.remove('tasks', task['id']);
      reload();
    } catch (error) {
      if (mounted) notifyError(context, error);
    }
  }

  String userName(Object? id) => widget.users
      .where((user) => user['id'] == id)
      .map((user) => user['name'] as String)
      .firstOrNull ?? 'Belum ditentukan';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.division['name']),
      actions: [
        if (manager)
          IconButton(
            tooltip: 'Edit divisi',
            onPressed: editDivision,
            icon: const Icon(Icons.edit_outlined),
          ),
        if (manager)
          IconButton(
            tooltip: 'Hapus divisi',
            onPressed: deleteDivision,
            icon: const Icon(Icons.delete_outline),
          ),
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: manager
        ? FloatingActionButton.extended(
            onPressed: () async {
              final data = await future;
              if (mounted) await editTask(data[0] as List<DbRow>);
            },
            icon: const Icon(Icons.add),
            label: const Text('Tambah tugas'),
          )
        : null,
    body: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? LoadError(snapshot.error!, reload)
              : const LoadingState();
        }

        final members = snapshot.data![0] as List<DbRow>;
        final tasks = snapshot.data![1] as List<DbRow>;
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              Text(
                widget.event['title'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'Anggota',
                      value: members.length,
                      icon: Icons.people_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Tugas',
                      value: tasks.length,
                      icon: Icons.checklist_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Tugas divisi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                const EmptyState(
                  'Buat tugas pertama untuk mulai mengatur pekerjaan divisi.',
                  icon: Icons.add_task_outlined,
                ),
              for (final task in tasks)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.checklist_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(task['title']),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${statusLabels[task['status']] ?? 'Belum dimulai'} • ${priorityLabels[task['priority']] ?? 'Sedang'}\nPIC: ${userName(task['assigned_to'])} • ${dateLabel(task['deadline'])}',
                      ),
                    ),
                    isThreeLine: true,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskPage(
                            repo: repo,
                            task: task,
                            users: widget.users,
                            manager: manager,
                          ),
                        ),
                      );
                      if (mounted) reload();
                    },
                    trailing: manager
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit tugas',
                                onPressed: () => editTask(members, task),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Hapus tugas',
                                onPressed: () => deleteTask(task),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Anggota divisi',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const EmptyState(
                  'Anggota yang ditugaskan ke divisi ini akan tampil di sini.',
                  icon: Icons.group_add_outlined,
                ),
              for (final member in members)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                    title: Text(userName(member['user_id'])),
                    subtitle: Text(
                      widget.users
                              .where((user) => user['id'] == member['user_id'])
                              .map((user) => user['email'] as String)
                              .firstOrNull ??
                          '',
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: Theme.of(context).textTheme.titleLarge),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );
}
