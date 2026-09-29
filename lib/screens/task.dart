import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import 'shared.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({
    super.key,
    required this.repo,
    required this.task,
    required this.users,
    required this.manager,
  });
  final CmsRepository repo;
  final DbRow task;
  final List<DbRow> users;
  final bool manager;
  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  late Future<List<dynamic>> future;
  bool busy = false;
  CmsRepository get repo => widget.repo;
  bool get assignee => widget.task['assigned_to'] == repo.uid;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
    repo.rows('attachments', column: 'task_id', value: widget.task['id']),
    repo.rows('comments', column: 'task_id', value: widget.task['id']),
  ]);

  void reload() {
    setState(() {
      future = _load();
    });
  }

  Future<void> changeStatus(String value) async {
    try {
      await repo.save('tasks', {'status': value}, widget.task['id']);
      setState(() => widget.task['status'] = value);
    } catch (e) {
      if (mounted) notifyError(context, e);
    }
  }

  Future<void> addLink() async {
    final result = await editRecord(
      context,
      title: 'Lampiran tautan',
      fields: const [Field('url', 'URL lampiran', kind: 'url')],
      save: (v) async {
        final old = await repo.rows(
          'attachments',
          column: 'task_id',
          value: widget.task['id'],
        );
        await repo.client.from('attachments').upsert({
          'task_id': widget.task['id'],
          'uploaded_by': repo.uid,
          'type': 'link',
          'url': v['url'],
          'file_name': null,
          'file_path': null,
        }, onConflict: 'task_id');
        if (old.isNotEmpty && old.first['type'] == 'file') {
          try {
            await repo.client.storage.from('task-attachments').remove([
              old.first['file_path'],
            ]);
          } catch (_) {}
        }
      },
    );
    if (result == true) reload();
  }

  Future<void> upload() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (file == null) return;
    if ((await file.length() ?? 0) > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ukuran file maksimal 10 MB.')),
        );
      }
      return;
    }
    setState(() => busy = true);
    String? path;
    try {
      final old = await repo.rows(
        'attachments',
        column: 'task_id',
        value: widget.task['id'],
      );
      final extension = file.extension?.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
        throw Exception('Format file tidak didukung');
      }
      path =
          '${widget.task['id']}/${DateTime.now().millisecondsSinceEpoch}_${repo.uid}.$extension';
      await repo.client.storage
          .from('task-attachments')
          .uploadBinary(
            path,
            await file.xFile.readAsBytes(),
            fileOptions: FileOptions(
              contentType: extension == 'pdf'
                  ? 'application/pdf'
                  : extension == 'png'
                  ? 'image/png'
                  : 'image/jpeg',
            ),
          );
      await repo.client.from('attachments').upsert({
        'task_id': widget.task['id'],
        'uploaded_by': repo.uid,
        'type': 'file',
        'file_name': file.name,
        'file_path': path,
        'url': null,
      }, onConflict: 'task_id');
      if (old.isNotEmpty && old.first['type'] == 'file') {
        try {
          await repo.client.storage.from('task-attachments').remove([
            old.first['file_path'],
          ]);
        } catch (_) {}
      }
      reload();
    } catch (e) {
      if (path != null) {
        try {
          await repo.client.storage.from('task-attachments').remove([path]);
        } catch (_) {}
      }
      if (mounted) notifyError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> openAttachment(DbRow attachment) async {
    try {
      final value = attachment['type'] == 'file'
          ? await repo.client.storage
                .from('task-attachments')
                .createSignedUrl(attachment['file_path'], 300)
          : attachment['url'];
      if (!await launchUrl(
        Uri.parse(value),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('Tidak dapat membuka lampiran');
      }
    } catch (e) {
      if (mounted) notifyError(context, e);
    }
  }

  Future<void> addComment() async {
    final result = await editRecord(
      context,
      title: 'Tambah komentar',
      fields: const [Field('comment', 'Komentar', lines: 3)],
      save: (v) => repo.save('comments', {
        'task_id': widget.task['id'],
        'user_id': repo.uid,
        ...v,
      }),
    );
    if (result == true) reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detail tugas'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
              ? LoadError(snapshot.error!, reload)
              : const LoadingState();
        }
        final attachments = snapshot.data![0] as List<DbRow>;
        final comments = snapshot.data![1] as List<DbRow>;
        return RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.task['title'],
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                (widget.task['description'] as String?)?.isNotEmpty ?? false
                    ? widget.task['description']
                    : 'Belum ada deskripsi untuk tugas ini.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.flag_outlined, size: 18),
                    label: Text(
                      'Prioritas ${priorityLabels[widget.task['priority']] ?? 'Sedang'}',
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      'Deadline ${dateLabel(widget.task['deadline'])}',
                    ),
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penanggung jawab',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.users
                                .where(
                                  (u) => u['id'] == widget.task['assigned_to'],
                                )
                                .map((u) => u['name'])
                                .firstOrNull ??
                            'Belum ditetapkan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (widget.manager || assignee) ...[
                        Text(
                          'Perbarui status',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: widget.task['status'],
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.track_changes_outlined),
                          ),
                          items: statusLabels.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) changeStatus(v);
                          },
                        ),
                      ] else ...[
                        Text(
                          'Status',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Chip(
                          avatar: const Icon(Icons.track_changes_outlined),
                          label: Text(
                            statusLabels[widget.task['status']] ??
                                'Belum dimulai',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lampiran',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (attachments.isNotEmpty)
                    Text(
                      '${attachments.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (attachments.isEmpty)
                const EmptyState(
                  'Dokumen atau tautan pendukung akan muncul di sini.',
                  icon: Icons.attach_file_outlined,
                ),
              for (final a in attachments)
                Card(
                  child: ListTile(
                    leading: Icon(
                      a['type'] == 'file'
                          ? Icons.insert_drive_file_outlined
                          : Icons.link,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(
                      a['file_name'] ?? a['url'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: const Text('Ketuk untuk membuka'),
                    onTap: () => openAttachment(a),
                    trailing: widget.manager || assignee
                        ? IconButton(
                            tooltip: 'Hapus lampiran',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmDelete(context, 'lampiran')) {
                                return;
                              }
                              try {
                                await repo.remove('attachments', a['id']);
                                if (a['type'] == 'file') {
                                  await repo.client.storage
                                      .from('task-attachments')
                                      .remove([a['file_path']]);
                                }
                                reload();
                              } catch (e) {
                                if (context.mounted) notifyError(context, e);
                              }
                            },
                          )
                        : const Icon(Icons.open_in_new),
                  ),
                ),
              if (widget.manager || assignee)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: busy ? null : upload,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Pilih file (maks. 10 MB)'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : addLink,
                      icon: const Icon(Icons.link),
                      label: const Text('Tambah tautan'),
                    ),
                  ],
                ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Komentar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: addComment,
                    icon: const Icon(Icons.add_comment_outlined),
                    label: const Text('Tulis komentar'),
                  ),
                ],
              ),
              if (comments.isEmpty)
                const EmptyState(
                  'Mulai diskusi dengan menambahkan komentar.',
                  icon: Icons.chat_bubble_outline,
                ),
              for (final c in comments)
                Card(
                  child: ListTile(
                    title: Text(
                      widget.users
                              .where((u) => u['id'] == c['user_id'])
                              .map((u) => u['name'])
                              .firstOrNull ??
                          'Pengguna',
                    ),
                    subtitle: Text(
                      '${c['comment']}\n${dateLabel(c['created_at'])}',
                    ),
                    trailing: c['user_id'] == repo.uid || widget.manager
                        ? IconButton(
                            tooltip: 'Hapus komentar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmDelete(context, 'komentar')) {
                                return;
                              }
                              try {
                                await repo.remove('comments', c['id']);
                                reload();
                              } catch (e) {
                                if (context.mounted) notifyError(context, e);
                              }
                            },
                          )
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
