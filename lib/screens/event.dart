import 'package:flutter/material.dart';

import '../data.dart';
import 'division.dart';
import 'shared.dart';

class EventPage extends StatefulWidget {
  const EventPage({
    super.key,
    required this.repo,
    required this.event,
    required this.profile,
    required this.users,
  });
  final CmsRepository repo;
  final DbRow event, profile;
  final List<DbRow> users;
  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  late Future<List<dynamic>> future;
  int tab = 0;
  CmsRepository get repo => widget.repo;
  bool get admin => widget.profile['role'] == 'admin';
  bool get manager => admin || widget.event['ketua_panitia_id'] == repo.uid;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
    repo.rows('divisions', column: 'event_id', value: widget.event['id']),
    repo.rows('members'),
    repo.rows('tasks'),
  ]);

  void reload() {
    setState(() {
      future = _load();
    });
  }

  Future<void> addDivision() async {
    final result = await editRecord(
      context,
      title: 'Tambah divisi',
      fields: const [Field('name', 'Nama divisi')],
      save: (values) =>
          repo.save('divisions', {'event_id': widget.event['id'], ...values}),
    );
    if (result == true) reload();
  }

  Future<void> memberEditor(List<DbRow> divisions, [DbRow? member]) async {
    final result = await editRecord(
      context,
      title: member == null ? 'Tambah anggota' : 'Edit anggota',
      initial: member == null
          ? null
          : {...member, 'division_id': member['division_id'].toString()},
      fields: [
        Field(
          'division_id',
          'Divisi',
          options: {for (final d in divisions) d['id'].toString(): d['name']},
        ),
        Field(
          'user_id',
          'Pengguna',
          options: {
            for (final u in widget.users)
              u['id']: '${u['name']} • ${u['email']}',
          },
        ),
      ],
      save: (v) => repo.save('members', {
        'division_id': int.parse(v['division_id']),
        'user_id': v['user_id'],
      }, member?['id']),
    );
    if (result == true) reload();
  }

  Future<void> taskEditor(
    List<DbRow> divisions,
    List<DbRow> members, [
    DbRow? task,
  ]) async {
    final memberIds = members
        .where((m) => divisions.any((d) => d['id'] == m['division_id']))
        .map((m) => m['user_id'])
        .toSet();
    final result = await editRecord(
      context,
      title: task == null ? 'Buat tugas' : 'Edit tugas',
      initial: task == null
          ? null
          : {...task, 'division_id': task['division_id'].toString()},
      fields: [
        const Field('title', 'Judul tugas'),
        const Field('description', 'Deskripsi', required: false, lines: 3),
        Field(
          'division_id',
          'Divisi',
          options: {for (final d in divisions) d['id'].toString(): d['name']},
        ),
        Field(
          'assigned_to',
          'PIC',
          required: false,
          options: {
            for (final u in widget.users.where(
              (u) => memberIds.contains(u['id']),
            ))
              u['id']: u['name'],
          },
        ),
        const Field('deadline', 'Deadline', kind: 'datetime', required: false),
        const Field('priority', 'Prioritas', options: priorityLabels),
        const Field('status', 'Status', options: statusLabels),
      ],
      save: (v) => repo.save('tasks', {
        ...v,
        'division_id': int.parse(v['division_id']),
      }, task?['id']),
    );
    if (result == true) reload();
  }

  Future<void> delete(String table, DbRow row, String name) async {
    if (!await confirmDelete(context, name)) return;
    try {
      await repo.remove(table, row['id']);
      reload();
    } catch (e) {
      if (mounted) notifyError(context, e);
    }
  }

  Future<void> editEvent() async {
    final result = await editRecord(
      context,
      title: 'Edit event',
      initial: widget.event,
      fields: const [
        Field('title', 'Nama event'),
        Field('description', 'Deskripsi', required: false, lines: 3),
        Field('location', 'Lokasi'),
        Field('start_date', 'Tanggal mulai', kind: 'date'),
        Field('end_date', 'Tanggal selesai', kind: 'date'),
      ],
      save: (values) async {
        await repo.save('events', values, widget.event['id']);
        widget.event.addAll(values);
      },
    );
    if (result == true && mounted) setState(() {});
  }

  Future<void> editChair() async {
    final result = await editRecord(
      context,
      title: widget.event['ketua_panitia_id'] == null
          ? 'Tetapkan ketua panitia'
          : 'Ubah ketua panitia',
      initial: widget.event,
      fields: [
        Field(
          'ketua_panitia_id',
          'Ketua panitia',
          options: {for (final u in widget.users) u['id']: u['name']},
        ),
      ],
      save: (values) async {
        await repo.save('events', values, widget.event['id']);
        widget.event.addAll(values);
      },
    );
    if (result == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, snapshot) {
      final divisions = snapshot.hasData
          ? snapshot.data![0] as List<DbRow>
          : <DbRow>[];
      final members = snapshot.hasData
          ? (snapshot.data![1] as List<DbRow>)
                .where((m) => divisions.any((d) => d['id'] == m['division_id']))
                .toList()
          : <DbRow>[];
      final tasks = snapshot.hasData
          ? (snapshot.data![2] as List<DbRow>)
                .where((t) => divisions.any((d) => d['id'] == t['division_id']))
                .toList()
          : <DbRow>[];
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.event['title']),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
            if (manager)
              IconButton(
                tooltip: 'Edit event',
                onPressed: editEvent,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (admin)
              IconButton(
                tooltip: widget.event['ketua_panitia_id'] == null
                    ? 'Tetapkan ketua panitia'
                    : 'Ubah ketua panitia',
                onPressed: editChair,
                icon: const Icon(Icons.person_add_alt_1_outlined),
              ),
            if (admin)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    if (!await confirmDelete(context, widget.event['title'])) {
                      return;
                    }
                    try {
                      await repo.remove('events', widget.event['id']);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) notifyError(context, e);
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Hapus event'),
                  ),
                ],
              ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Ringkasan',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              label: 'Divisi',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              label: 'Anggota',
            ),
          ],
        ),
        floatingActionButton: manager && snapshot.hasData && tab > 0
            ? FloatingActionButton.extended(
                onPressed: () {
                  if (tab == 1) addDivision();
                  if (tab == 2) memberEditor(divisions);
                },
                icon: const Icon(Icons.add),
                label: Text(['', 'Tambah divisi', 'Tambah anggota'][tab]),
              )
            : null,
        body: !snapshot.hasData
            ? snapshot.hasError
                  ? LoadError(snapshot.error!, reload)
                  : const LoadingState()
            : RefreshIndicator(
                onRefresh: () async {
                  reload();
                  await future;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    if (tab == 0) ...[
                      Card(
                        margin: const EdgeInsets.only(bottom: 20),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi event',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if ((widget.event['description'] as String?)
                                      ?.isNotEmpty ??
                                  false) ...[
                                const SizedBox(height: 8),
                                Text(widget.event['description']),
                              ],
                              const SizedBox(height: 12),
                              _EventInfoRow(
                                icon: Icons.place_outlined,
                                text:
                                    widget.event['location'] ??
                                    'Lokasi belum ditentukan',
                              ),
                              const SizedBox(height: 8),
                              _EventInfoRow(
                                icon: Icons.calendar_month_outlined,
                                text:
                                    '${dateLabel(widget.event['start_date'])} – ${dateLabel(widget.event['end_date'])}',
                              ),
                              const SizedBox(height: 8),
                              _EventInfoRow(
                                icon: Icons.person_outline,
                                text:
                                    'Ketua: ${widget.users.where((u) => u['id'] == widget.event['ketua_panitia_id']).map((u) => u['name']).firstOrNull ?? 'Belum ditetapkan'}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final item in {
                            'Divisi': divisions.length,
                            'Anggota': members.length,
                            'Tugas': tasks.length,
                            'Belum dimulai': tasks
                                .where((t) => t['status'] == 'todo')
                                .length,
                            'Sedang dikerjakan': tasks
                                .where((t) => t['status'] == 'in_progress')
                                .length,
                            'Selesai': tasks
                                .where((t) => t['status'] == 'done')
                                .length,
                          }.entries)
                            SizedBox(
                              width:
                                  (MediaQuery.sizeOf(context).width - 56) / 2,
                              child: _MetricCard(
                                label: item.key,
                                value: item.value,
                                icon: switch (item.key) {
                                  'Divisi' => Icons.hub_outlined,
                                  'Anggota' => Icons.people_outline,
                                  'Tugas' => Icons.checklist_outlined,
                                  'Belum dimulai' => Icons.pending_actions,
                                  'Sedang dikerjakan' => Icons.autorenew,
                                  _ => Icons.task_alt_outlined,
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Progres penyelesaian',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${(taskProgress(tasks) * 100).round()}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: taskProgress(tasks),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                tasks.isEmpty
                                    ? 'Tambahkan tugas untuk mulai melacak progres.'
                                    : '${tasks.where((t) => t['status'] == 'done').length} dari ${tasks.length} tugas selesai',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (tab == 1) ...[
                      if (divisions.isEmpty)
                        const EmptyState(
                          'Divisi membantu membagi kepanitiaan berdasarkan tanggung jawab.',
                          icon: Icons.hub_outlined,
                        ),
                      for (final d in divisions)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DivisionDetailPage(
                                    repo: repo,
                                    event: widget.event,
                                    division: d,
                                    profile: widget.profile,
                                    users: widget.users,
                                  ),
                                ),
                              );
                              if (mounted) reload();
                            },
                            title: Text(d['name']),
                            subtitle: Text(
                              '${members.where((m) => m['division_id'] == d['id']).length} anggota',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ),
                    ] else if (tab == 2) ...[
                      if (members.isEmpty)
                        const EmptyState(
                          'Anggota yang ditambahkan ke event akan muncul di sini.',
                          icon: Icons.group_add_outlined,
                        ),
                      for (final m in members)
                        Card(
                          child: ListTile(
                            onTap: manager
                                ? () => memberEditor(divisions, m)
                                : null,
                            title: Text(
                              widget.users
                                      .where((u) => u['id'] == m['user_id'])
                                      .map((u) => u['name'])
                                      .firstOrNull ??
                                  'Pengguna',
                            ),
                            subtitle: Text(
                              '${divisions.where((d) => d['id'] == m['division_id']).map((d) => d['name']).firstOrNull ?? '-'} • ${widget.users.where((u) => u['id'] == m['user_id']).map((u) => u['email']).firstOrNull ?? ''}',
                            ),
                            trailing: manager
                                ? IconButton(
                                    tooltip: 'Hapus anggota',
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: () =>
                                        delete('members', m, 'anggota'),
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      );
    },
  );
}

class _EventInfoRow extends StatelessWidget {
  const _EventInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Expanded(child: Text(text)),
    ],
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
