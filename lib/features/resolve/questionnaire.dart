/// Questionário por serviço (Fase 4). Mesmas regras de visibilidade e
/// validação do servidor (functions/resolveCore.js); o servidor revalida
/// tudo — aqui é só para orientar o preenchimento.
class Question {
  final String id, type, label;
  final bool required;
  final List<String> options;
  final QuestionCondition? showIf;

  const Question({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.options = const [],
    this.showIf,
  });

  factory Question.fromMap(Map m) => Question(
        id: (m['id'] ?? '').toString(),
        type: (m['type'] ?? 'text').toString(),
        label: (m['label'] ?? '').toString(),
        required: m['required'] == true,
        options: ((m['options'] as List?) ?? const []).map((e) => e.toString()).toList(),
        showIf: m['showIf'] is Map ? QuestionCondition.fromMap(m['showIf'] as Map) : null,
      );
}

class QuestionCondition {
  final String questionId, op;
  final Object? value;
  const QuestionCondition(this.questionId, this.op, this.value);
  factory QuestionCondition.fromMap(Map m) =>
      QuestionCondition((m['questionId'] ?? '').toString(), (m['op'] ?? '').toString(), m['value']);
}

class Questionnaire {
  final String id, title;
  final int? version;
  final List<Question> questions;
  const Questionnaire({required this.id, required this.title, this.version, required this.questions});

  factory Questionnaire.fromMap(String id, Map<String, dynamic> m) => Questionnaire(
        id: id,
        title: (m['title'] ?? '').toString(),
        version: (m['version'] as num?)?.toInt(),
        questions: ((m['questions'] as List?) ?? const [])
            .whereType<Map>()
            .map(Question.fromMap)
            .toList(),
      );

  static bool answered(Object? v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  static bool holds(QuestionCondition? c, Map<String, Object?> answers) {
    if (c == null) return true;
    final v = answers[c.questionId];
    switch (c.op) {
      case 'answered':
        return answered(v);
      case 'equals':
        return v is List ? v.contains(c.value) : v == c.value;
      case 'not_equals':
        return v is List ? !v.contains(c.value) : answered(v) && v != c.value;
      case 'in':
        final vals = c.value is List ? c.value as List : [c.value];
        return v is List ? v.any(vals.contains) : vals.contains(v);
      default:
        return false;
    }
  }

  /// Perguntas visíveis na ordem (condição só olha anteriores visíveis).
  List<Question> visible(Map<String, Object?> answers) {
    final out = <Question>[];
    final seen = <String, Object?>{};
    for (final q in questions) {
      final c = q.showIf;
      if (c != null && !seen.containsKey(c.questionId)) continue;
      if (!holds(c, seen)) continue;
      out.add(q);
      seen[q.id] = answers[q.id];
    }
    return out;
  }

  /// Respostas a enviar (só das visíveis) e erros de obrigatórias.
  ({Map<String, Object?> answers, List<String> errors}) collect(Map<String, Object?> raw) {
    final out = <String, Object?>{};
    final errors = <String>[];
    for (final q in visible(raw)) {
      final v = raw[q.id];
      if (!answered(v)) {
        if (q.required) errors.add('Responda: ${q.label}');
        continue;
      }
      out[q.id] = v;
    }
    return (answers: out, errors: errors);
  }
}
