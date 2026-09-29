import 'package:supabase_flutter/supabase_flutter.dart';

typedef DbRow = Map<String, dynamic>;
const statusLabels = {
  'todo': 'Belum dimulai',
  'in_progress': 'Sedang dikerjakan',
  'done': 'Selesai',
};
const priorityLabels = {'low': 'Rendah', 'medium': 'Sedang', 'high': 'Tinggi'};

class CmsRepository {
  CmsRepository(this.client);
  final SupabaseClient client;
  String get uid => client.auth.currentUser!.id;
  Future<List<DbRow>> rows(
    String table, {
    String? column,
    Object? value,
  }) async {
    var query = client.from(table).select();
    if (column != null && value != null) query = query.eq(column, value);
    return await query.order('id');
  }

  Future<void> save(String table, DbRow values, [Object? id]) async {
    if (id == null) {
      await client.from(table).insert(values);
    } else {
      await client.from(table).update(values).eq('id', id);
    }
  }

  Future<void> remove(String table, Object id) async =>
      await client.from(table).delete().eq('id', id);
  Future<DbRow> profile() =>
      client.from('users').select().eq('id', uid).single();
}

double taskProgress(List<DbRow> tasks) => tasks.isEmpty
    ? 0
    : tasks.where((t) => t['status'] == 'done').length / tasks.length;
String dateLabel(Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return 'Belum ditentukan';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String errorMessage(Object error) {
  if (error is AuthException) {
    return 'Login gagal. Periksa email dan kata sandi Anda.';
  }
  if (error is FunctionException) {
    if (error.status == 0) {
      return 'Tidak dapat terhubung ke layanan pengelolaan pengguna. Periksa koneksi Anda.';
    }
    final details = error.details;
    final code = details is Map ? details['code']?.toString() : null;
    switch (code) {
      case 'server_config_missing':
      case 'admin_lookup_failed':
        return 'Konfigurasi Edge Function belum lengkap. Periksa secret SUPABASE_SERVICE_ROLE_KEY di Supabase.';
      case 'auth_required':
        return 'Sesi login sudah berakhir. Silakan masuk kembali.';
      case 'admin_required':
        return 'Hanya administrator yang dapat mengelola pengguna.';
    }
    final message = details is Map ? details['error']?.toString() : null;
    if (message != null && message.isNotEmpty) {
      return 'Pengelolaan pengguna gagal: $message';
    }
    return 'Pengelolaan pengguna gagal (HTTP ${error.status}).';
  }
  if (error is PostgrestException) {
    if (error.code == '23505') {
      return 'Data sudah terdaftar. Gunakan data yang berbeda.';
    }
    if (error.code == '42501') {
      final table = RegExp(
        r'permission denied for table ([a-zA-Z_][a-zA-Z_0-9]*)',
      ).firstMatch(error.message)?.group(1);
      if (table != null) {
        return 'Akses database ke tabel $table belum diberikan. Hubungi pengelola Supabase.';
      }
      return 'Anda tidak memiliki izin untuk tindakan ini.';
    }
    if (error.code == 'PGRST205' || error.code == '42P01') {
      return 'Database belum siap. Jalankan migrasi Supabase pada panduan setup.';
    }
    return 'Data gagal disimpan atau dimuat: ${error.message}';
  }
  return 'Permintaan gagal. Periksa koneksi Anda lalu coba kembali.';
}
