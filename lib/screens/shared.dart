import 'package:flutter/material.dart';

import '../data.dart';

class Field {
  const Field(
    this.key,
    this.label, {
    this.options,
    this.required = true,
    this.lines = 1,
    this.kind = 'text',
  });
  final String key, label, kind;
  final Map<String, String>? options;
  final bool required;
  final int lines;
}

Future<bool?> editRecord(
  BuildContext context, {
  required String title,
  required List<Field> fields,
  DbRow? initial,
  required Future<void> Function(DbRow) save,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _Editor(title: title, fields: fields, initial: initial ?? {}, save: save),
);

class _Editor extends StatefulWidget {
  const _Editor({
    required this.title,
    required this.fields,
    required this.initial,
    required this.save,
  });
  final String title;
  final List<Field> fields;
  final DbRow initial;
  final Future<void> Function(DbRow) save;
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final form = GlobalKey<FormState>();
  late final values = Map<String, dynamic>.from(widget.initial);
  late final controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(
        text: widget.initial[f.key]?.toString() ?? '',
      ),
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    final row = <String, dynamic>{};
    for (final f in widget.fields) {
      final v = f.options == null
          ? controllers[f.key]!.text.trim()
          : values[f.key]?.toString();
      row[f.key] = v == null || v.isEmpty ? null : v;
    }
    if (row['start_date'] != null &&
        row['end_date'] != null &&
        DateTime.parse(row['end_date'])
            .isBefore(DateTime.parse(row['start_date']))) {
      setState(
        () => error = 'Tanggal selesai tidak boleh sebelum tanggal mulai.',
      );
      return;
    }
    if (row['deadline'] != null) {
      row['deadline'] = DateTime.parse(row['deadline'])
          .toUtc()
          .toIso8601String();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.save(row);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errorMessage(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in widget.fields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: f.options != null
                      ? DropdownButtonFormField<String>(
                          initialValue:
                              f.options!.containsKey(values[f.key]?.toString())
                              ? values[f.key]?.toString()
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: f.label),
                          items: f.options!.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: busy ? null : (v) => values[f.key] = v,
                          validator: (v) => f.required && v == null
                              ? 'Pilih ${f.label.toLowerCase()}'
                              : null,
                        )
                      : TextFormField(
                          controller: controllers[f.key],
                          enabled: !busy,
                          maxLines: f.lines,
                          minLines: f.lines > 1 ? 2 : 1,
                          keyboardType: switch (f.kind) {
                            'email' => TextInputType.emailAddress,
                            'url' => TextInputType.url,
                            'phone' => TextInputType.phone,
                            _ => f.lines > 1
                                ? TextInputType.multiline
                                : TextInputType.text,
                          },
                          textCapitalization:
                              f.kind == 'email' ||
                                  f.kind == 'url' ||
                                  f.kind == 'password'
                              ? TextCapitalization.none
                              : TextCapitalization.sentences,
                          readOnly: f.kind == 'date' || f.kind == 'datetime',
                          decoration: InputDecoration(
                            labelText: f.label,
                            suffixIcon: f.kind.startsWith('date')
                                ? const Icon(Icons.calendar_month_outlined)
                                : f.kind == 'password'
                                ? IconButton(
                                    tooltip:
                                        values['obscure_${f.key}'] as bool? ??
                                            true
                                        ? 'Tampilkan kata sandi'
                                        : 'Sembunyikan kata sandi',
                                    onPressed: () => setState(() {
                                      values['obscure_${f.key}'] =
                                          !(values['obscure_${f.key}']
                                                  as bool? ??
                                              true);
                                    }),
                                    icon: Icon(
                                      (values['obscure_${f.key}'] as bool? ??
                                              true)
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  )
                                : null,
                          ),
                          obscureText:
                              f.kind == 'password' &&
                              (values['obscure_${f.key}'] as bool? ?? true),
                          textInputAction: f.lines > 1
                              ? TextInputAction.newline
                              : TextInputAction.next,
                          onTap: f.kind.startsWith('date')
                              ? () async {
                                  final now = DateTime.now();
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        DateTime.tryParse(
                                          controllers[f.key]!.text,
                                        )?.toLocal() ??
                                        now,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date == null || !context.mounted) {
                                    return;
                                  }
                                  var selected = date;
                                  if (f.kind == 'datetime') {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (time == null) return;
                                    selected = DateTime(
                                      date.year,
                                      date.month,
                                      date.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  }
                                  controllers[f.key]!.text = f.kind == 'date'
                                      ? selected.toIso8601String().substring(
                                          0,
                                          10,
                                        )
                                      : selected.toIso8601String();
                                }
                              : null,
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) {
                              return f.required
                                  ? '${f.label} wajib diisi'
                                  : null;
                            }
                            if (f.kind == 'email' &&
                                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(text)) {
                              return 'Email tidak valid';
                            }
                            if (f.kind == 'password' && text.length < 8) {
                              return 'Gunakan minimal 8 karakter';
                            }
                            if (f.kind == 'url') {
                              final uri = Uri.tryParse(text);
                              if (uri == null ||
                                  !['http', 'https'].contains(uri.scheme) ||
                                  uri.host.isEmpty) {
                                return 'Masukkan URL http/https yang valid';
                              }
                            }
                            return null;
                          },
                        ),
                ),
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    ),
  );
}

Future<bool> confirmDelete(BuildContext context, String name) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 32,
        ),
        title: const Text('Hapus data?'),
        content: Text(
          'Hapus "$name" beserta data terkait? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ??
    false;
void notifyError(BuildContext context, Object e) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(e))));

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Memuat data…'});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class LoadError extends StatelessWidget {
  const LoadError(this.error, this.retry, {super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: retry, child: const Text('Coba lagi')),
        ],
      ),
    ),
  );
}
