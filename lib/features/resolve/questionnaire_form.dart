import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import 'questionnaire.dart';

/// Formulário dinâmico do questionário do serviço. Mostra só as perguntas
/// visíveis (condicionais) e envia anexos para a pasta privada do usuário.
class QuestionnaireForm extends StatefulWidget {
  final Questionnaire questionnaire;
  final Map<String, Object?> answers;
  final VoidCallback onChanged;
  const QuestionnaireForm(
      {super.key, required this.questionnaire, required this.answers, required this.onChanged});

  @override
  State<QuestionnaireForm> createState() => _QuestionnaireFormState();
}

class _QuestionnaireFormState extends State<QuestionnaireForm> {
  final _uploading = <String>{};

  void _set(String id, Object? v) {
    setState(() => widget.answers[id] = v);
    widget.onChanged();
  }

  Future<void> _attach(Question q) async {
    final r = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        withData: true);
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    if (f.bytes!.length > 10 * 1024 * 1024) {
      if (mounted) snack(context, 'Arquivo acima de 10 MB', bg: AppColors.error);
      return;
    }
    setState(() => _uploading.add(q.id));
    try {
      final path = await FS.uploadResolveAttachment(f.bytes!, f.name);
      if (path == null) throw Exception('formato não aceito');
      final cur = List<String>.from((widget.answers[q.id] as List?) ?? const []);
      _set(q.id, [...cur, path]);
    } catch (e) {
      if (mounted) snack(context, 'Não foi possível enviar o anexo: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _uploading.remove(q.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final qs = widget.questionnaire.visible(widget.answers);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final q in qs) Padding(padding: const EdgeInsets.only(bottom: 14), child: _field(q)),
    ]);
  }

  Widget _label(Question q) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('${q.label}${q.required ? ' *' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)));

  Widget _field(Question q) {
    final v = widget.answers[q.id];
    switch (q.type) {
      case 'single_choice':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(q),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final o in q.options)
              ChoiceChip(label: Text(o), selected: v == o, onSelected: (_) => _set(q.id, v == o ? null : o)),
          ]),
        ]);
      case 'multi_choice':
        final sel = List<String>.from((v as List?) ?? const []);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(q),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final o in q.options)
              FilterChip(
                  label: Text(o),
                  selected: sel.contains(o),
                  onSelected: (on) => _set(q.id, on ? [...sel, o] : (sel..remove(o)))),
          ]),
        ]);
      case 'boolean':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(q),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: const Text('Sim'), selected: v == true, onSelected: (_) => _set(q.id, true)),
            ChoiceChip(label: const Text('Não'), selected: v == false, onSelected: (_) => _set(q.id, false)),
          ]),
        ]);
      case 'number':
        return TextFormField(
            initialValue: v?.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '${q.label}${q.required ? ' *' : ''}', border: const OutlineInputBorder()),
            onChanged: (t) => _set(q.id, num.tryParse(t.replaceAll(',', '.'))));
      case 'date':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(q),
          OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(v is String ? v : 'Escolher data'),
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                    context: context, firstDate: now.subtract(const Duration(days: 3650)),
                    lastDate: now.add(const Duration(days: 730)), initialDate: now);
                if (d != null) _set(q.id, d.toIso8601String().substring(0, 10));
              }),
        ]);
      case 'attachment':
        final files = List<String>.from((v as List?) ?? const []);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _label(q),
          for (var i = 0; i < files.length; i++)
            Row(children: [
              const Icon(Icons.attach_file, size: 18),
              Expanded(child: Text('Anexo ${i + 1}', style: const TextStyle(fontSize: 12))),
              IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _set(q.id, [...files]..removeAt(i))),
            ]),
          OutlinedButton.icon(
              icon: _uploading.contains(q.id)
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: const Text('Adicionar foto ou PDF'),
              onPressed: _uploading.contains(q.id) ? null : () => _attach(q)),
          const Text('Visível apenas para você e para o profissional que você escolher.',
              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]);
      default: // text / long_text
        return TextFormField(
            initialValue: v as String?,
            maxLines: q.type == 'long_text' ? 4 : 1,
            maxLength: q.type == 'long_text' ? 2000 : 200,
            decoration: InputDecoration(labelText: '${q.label}${q.required ? ' *' : ''}', border: const OutlineInputBorder()),
            onChanged: (t) => _set(q.id, t));
    }
  }
}
