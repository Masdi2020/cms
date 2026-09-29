import 'package:flutter/material.dart';

import '../data.dart';
import 'shared.dart';
import 'event.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repo});
  final CmsRepository repo;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<dynamic>> future;
  int tab = 0;
  CmsRepository get repo => widget.repo;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<dynamic>> _load() => Future.wait([
    repo.profile(),
    repo.rows('events'),
    repo.rows('users'),
  ]);

  void reload() => setState(() {
    future = _load();
  });

  Future<void> eventEditor(
    DbRow profile,
    List<DbRow> users, [
    DbRow? event,
  ]) async {
    final result = await editRecord(
      context,
      title: event == null ? 'Buat event' : 'Edit event',
      initial: event,
      fields: [
        const Field('title', 'Nama event'),
        const Field('description', 'Deskripsi', required: false, lines: 3),
        const Field('location', 'Lokasi'),
        const Field('start_date', 'Tanggal mulai', kind: 'date'),
        const Field('end_date', 'Tanggal selesai', kind: 'date'),
        Field(
          'ketua_panitia_id',
          'Ketua panitia',
          options: {
            for (final u in users) u['id']: '${u['name']} • ${u['email']}',
          },
        ),
      ],
      save: (v) => repo.save('events', v, event?['id']),
    );
    if (result == true) reload();
  }

  Future<void> userEditor([DbRow? user]) async {
    final result = await editRecord(
      context,
      title: user == null ? 'Tambah pengguna' : 'Edit pengguna',
      initial: user,
      fields: [
        const Field('name', 'Nama'),
        const Field('username', 'Username'),
        const Field('email', 'Email', kind: 'email'),
        const Field('phone', 'Nomor HP', required: false),
        Field(
          'password',
          user == null ? 'Kata sandi awal' : 'Kata sandi baru (opsional)',
          kind: 'password',
          required: user == null,
        ),
        const Field(
          'role',
          'Peran global',
          options: {'user': 'Pengguna', 'admin': 'Administrator'},
        ),
      ],
      save: (v) async {
        final res = await repo.client.functions.invoke(
          'manage-users',
          body: {
            'action': user == null ? 'create' : 'update',
            'id': user?['id'],
            ...v,
          },
        );
        if (res.status >= 400) throw Exception('Pengelolaan pengguna gagal');
      },
    );
    if (result == true) reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rukun'),
            actions: [
              IconButton(
                tooltip: 'Keluar',
                onPressed: () async {
                  try {
                    await repo.client.auth.signOut();
                  } catch (e) {
                    if (context.mounted) notifyError(context, e);
                  }
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: snapshot.hasError
              ? LoadError(snapshot.error!, reload)
              : const LoadingState(),
        );
      }
      final profile = snapshot.data![0] as DbRow;
      final events = snapshot.data![1] as List<DbRow>;
      final users = snapshot.data![2] as List<DbRow>;
      final admin = profile['role'] == 'admin';
      return Scaffold(
        appBar: AppBar(
          title: const Text('Rukun'),
          actions: [
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Keluar',
              onPressed: () async {
                try {
                  await repo.client.auth.signOut();
                } catch (e) {
                  if (context.mounted) notifyError(context, e);
                }
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) => setState(() => tab = v),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.event_outlined),
              label: 'Event Saya',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profil',
            ),
            if (admin)
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                label: 'Pengguna',
              ),
          ],
        ),
        floatingActionButton: admin && tab != 1
            ? FloatingActionButton.extended(
                onPressed: () =>
                    tab == 0 ? eventEditor(profile, users) : userEditor(),
                icon: const Icon(Icons.add),
                label: Text(tab == 0 ? 'Buat event' : 'Pengguna'),
              )
            : null,
        body: RefreshIndicator(
          onRefresh: () async {
            reload();
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [
              if (tab == 0) ...[
                Card(
                  margin: const EdgeInsets.only(bottom: 24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Halo, ${profile['name']}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                admin
                                    ? 'Kelola acara dan koordinasikan para ketua panitia.'
                                    : 'Pilih event untuk melanjutkan kolaborasi.',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.diversity_3_outlined,
                          size: 36,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Event saya',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '${events.length} event',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (events.isEmpty)
                  const EmptyState(
                    'Event yang Anda ikuti akan muncul di sini. Hubungi administrator untuk bergabung.',
                    icon: Icons.event_busy_outlined,
                  ),
                for (final event in events)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EventPage(
                              repo: repo,
                              event: event,
                              profile: profile,
                              users: users,
                            ),
                          ),
                        );
                        reload();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                              child: Icon(
                                Icons.event_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${event['location'] ?? 'Lokasi belum ditentukan'} • ${dateLabel(event['start_date'])} – ${dateLabel(event['end_date'])}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      admin
                                          ? 'Administrator'
                                          : event['ketua_panitia_id'] ==
                                                repo.uid
                                          ? 'Ketua panitia'
                                          : 'Anggota',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSecondaryContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ] else if (tab == 1) ...[
                Text(
                  'Profil saya',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_outline,
                            size: 38,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile['name'],
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        _ProfileDetail(
                          icon: Icons.alternate_email,
                          label: 'Username',
                          value: '@${profile['username'] ?? '-'}',
                        ),
                        _ProfileDetail(
                          icon: Icons.mail_outline,
                          label: 'Email',
                          value: profile['email'] ?? '-',
                        ),
                        _ProfileDetail(
                          icon: Icons.phone_outlined,
                          label: 'Nomor HP',
                          value: profile['phone'] ?? 'Belum ditambahkan',
                        ),
                        _ProfileDetail(
                          icon: Icons.badge_outlined,
                          label: 'Peran',
                          value: admin
                              ? 'Administrator'
                              : 'Anggota • peran mengikuti event',
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit profil'),
                            onPressed: () async {
                              final result = await editRecord(
                                context,
                                title: 'Edit profil',
                                initial: profile,
                                fields: const [
                                  Field('name', 'Nama'),
                                  Field('username', 'Username'),
                                  Field(
                                    'phone',
                                    'Nomor HP',
                                    required: false,
                                    kind: 'phone',
                                  ),
                                ],
                                save: (v) =>
                                    repo.save('users', v, repo.uid),
                              );
                              if (result == true) reload();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Pengguna',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kelola akses dan informasi akun pengguna aplikasi.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (users.isEmpty)
                  const EmptyState(
                    'Belum ada pengguna yang terdaftar.',
                    icon: Icons.group_off_outlined,
                  ),
                for (final user in users)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          (user['name'] as String? ?? '').trim().isEmpty
                              ? '?'
                              : (user['name'] as String)
                                    .trim()
                                    .characters
                                    .first
                                    .toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        user['name'],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '@${user['username'] ?? '-'} • ${user['email']}\n${user['role'] == 'admin' ? 'Administrator' : 'Pengguna'}',
                      ),
                      onTap: () => userEditor(user),
                      trailing: user['id'] == repo.uid
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pengguna',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (!await confirmDelete(
                                  context,
                                  user['name'],
                                )) {
                                  return;
                                }
                                try {
                                  final response = await repo.client.functions
                                      .invoke(
                                        'manage-users',
                                        body: {
                                          'action': 'delete',
                                          'id': user['id'],
                                        },
                                      );
                                  if (response.status >= 400) {
                                    throw Exception('Gagal menghapus pengguna');
                                  }
                                  reload();
                                } catch (e) {
                                  if (context.mounted) notifyError(context, e);
                                }
                              },
                            ),
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

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}
