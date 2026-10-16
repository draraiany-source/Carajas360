import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────
// MEUS CHAMADOS — conversa do chamado com a equipe de suporte.
// Respostas em support/{id}/messages; status e "não lido" são
// atualizados pelo servidor (onSupportMessageCreated).
// ─────────────────────────────────────────────────────────────

Color ticketStatusColor(TicketStatus s) => switch (s) {
      TicketStatus.open => AppColors.warning,
      TicketStatus.answered => AppColors.primary,
      TicketStatus.inProgress => AppColors.info,
      TicketStatus.resolved => AppColors.secondary,
      TicketStatus.closed => AppColors.textLight,
    };

class MyTicketsScreen extends StatelessWidget {
  /// Para testes: lista injetada no lugar do Firestore.
  final Stream<List<TicketModel>>? stream;
  const MyTicketsScreen({super.key, this.stream});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meus chamados')),
        body: StreamBuilder<List<TicketModel>>(
          stream: stream ?? FS.myTicketsStream(),
          builder: (context, snap) {
            if (snap.hasError) return QueryErrorView(error: snap.error);
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return const EmptyState(
                  emoji: '🎧',
                  title: 'Nenhum chamado',
                  subtitle:
                      'Os chamados que você abrir na Central de Ajuda aparecem aqui.');
            }
            return ListView.builder(
              padding: pagePadding(context),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final t = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppDecorations.card(r: 16),
                  child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        key: Key('ticket-${t.id}'),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => TicketDetailScreen(
                                    ticketId: t.id, initial: t))),
                        leading: Stack(clipBehavior: Clip.none, children: [
                          const Icon(Icons.support_agent_rounded,
                              color: AppColors.primary),
                          if (t.unreadByUser)
                            Positioned(
                                right: -2,
                                top: -2,
                                child: Semantics(
                                  label: 'Nova resposta do suporte',
                                  child: Container(
                                      key: const Key('ticket-unread'),
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                          color: AppColors.error,
                                          shape: BoxShape.circle)),
                                )),
                        ]),
                        title: Text(t.subject.isEmpty ? 'Chamado' : t.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: t.unreadByUser
                                    ? FontWeight.w900
                                    : FontWeight.w700,
                                fontSize: 14)),
                        subtitle: Text(
                            t.unreadByUser
                                ? 'Nova resposta do suporte · ${fmtDate(t.lastMessageAt ?? t.createdAt)}'
                                : 'Aberto em ${fmtDate(t.createdAt)}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: AppTag(t.statusLabel,
                            bg: ticketStatusColor(t.status)),
                      )),
                );
              },
            );
          },
        ),
      );
}

/// Conversa do chamado: mensagem original primeiro, depois as respostas
/// em ordem. [asSupport] = admin respondendo pela equipe.
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final TicketModel? initial;
  final bool asSupport;

  /// Injeções para testes (padrão: Firestore e callable markTicketRead).
  final Stream<TicketModel?>? ticketStream;
  final Stream<List<TicketMessage>>? messagesStream;
  final Future<void> Function(String ticketId)? markRead;
  const TicketDetailScreen(
      {super.key,
      required this.ticketId,
      this.initial,
      this.asSupport = false,
      this.ticketStream,
      this.messagesStream,
      this.markRead});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  // Streams criados uma vez (setState não reabre a assinatura).
  late final Stream<TicketModel?> _ticket;
  late final Stream<List<TicketMessage>> _messages;
  String? _markedKey;
  int _msgCount = -1;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticketStream ?? FS.ticketStream(widget.ticketId);
    _messages =
        widget.messagesStream ?? FS.ticketMessagesStream(widget.ticketId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Dono abriu com resposta nova: limpa o "não lido" (uma vez por
  /// mensagem; falha é ignorada). Admin no suporte não marca.
  void _markReadIfNeeded(TicketModel t) {
    if (widget.asSupport || !t.unreadByUser) return;
    final key = '${t.lastMessageAt?.millisecondsSinceEpoch}';
    if (_markedKey == key) return;
    _markedKey = key;
    Future(() => (widget.markRead ?? FS.markTicketRead)(widget.ticketId))
        .catchError((_) {});
  }

  /// Rola até a mensagem mais recente quando chega uma nova.
  void _scrollOnNew(int count) {
    if (count <= _msgCount || _msgCount < 0) {
      _msgCount = count;
      return;
    }
    _msgCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 5000) {
      snack(context, 'Mensagem muito longa (máx. 5000 caracteres).',
          bg: AppColors.error);
      return;
    }
    setState(() => _sending = true);
    try {
      await FS.sendTicketMessage(widget.ticketId, text,
          asSupport: widget.asSupport);
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        snack(context,
            'Não foi possível enviar: ${e is CloudCallException ? e.message : _sendError(e)}',
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<TicketModel?>(
        stream: _ticket,
        initialData: widget.initial,
        builder: (context, tSnap) {
          final t = tSnap.data;
          if (t != null) _markReadIfNeeded(t);
          // Leitura concluída e documento ausente (apagado/sem acesso).
          final notFound = t == null &&
              !tSnap.hasError &&
              tSnap.connectionState != ConnectionState.waiting &&
              tSnap.connectionState != ConnectionState.none;
          return Scaffold(
            appBar: AppBar(
                title: Text(
                    t?.subject.isNotEmpty == true ? t!.subject : 'Chamado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            body: Column(children: [
              if (t != null)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: ticketStatusColor(t.status).withValues(alpha: 0.12),
                  child: Text(
                      widget.asSupport
                          ? '${t.statusLabel} · ${t.userName.isEmpty ? 'Usuário' : t.userName}'
                          : t.statusLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              Expanded(
                child: tSnap.hasError
                    ? QueryErrorView(error: tSnap.error)
                    : notFound
                    ? const Center(
                        key: Key('ticket-not-found'),
                        child: Text('Chamado não encontrado.'))
                    : StreamBuilder<List<TicketMessage>>(
                        stream: _messages,
                        builder: (context, mSnap) {
                          if (mSnap.hasError) {
                            return QueryErrorView(error: mSnap.error);
                          }
                          if (t == null && !tSnap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final msgs = mSnap.data ?? const <TicketMessage>[];
                          if (mSnap.hasData) _scrollOnNew(msgs.length);
                          return ListView(
                              controller: _scroll,
                              padding: pagePadding(context),
                              children: [
                                if (t != null)
                                  _Bubble(
                                      text: t.message,
                                      mine: !widget.asSupport,
                                      author:
                                          widget.asSupport ? 'Usuário' : 'Você',
                                      at: t.createdAt),
                                if (!mSnap.hasData)
                                  const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child: CircularProgressIndicator())),
                                for (final m in msgs)
                                  _Bubble(
                                      text: m.text,
                                      mine: m.fromSupport == widget.asSupport,
                                      author: m.fromSupport
                                          ? 'Suporte Carajás 360'
                                          : (widget.asSupport
                                              ? 'Usuário'
                                              : 'Você'),
                                      at: m.createdAt),
                                if (mSnap.hasData &&
                                    msgs.isEmpty &&
                                    !widget.asSupport)
                                  const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Text(
                                          'A equipe de suporte responde por aqui. Você será avisado.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textLight))),
                              ]);
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                      key: const Key('ticket-reply'),
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: InputDecoration(
                          counterText: '',
                          hintText: widget.asSupport
                              ? 'Responder como suporte…'
                              : 'Escreva sua mensagem…'),
                    )),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        key: const Key('ticket-send'),
                        tooltip: 'Enviar',
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_rounded)),
                  ]),
                ),
              ),
            ]),
          );
        },
      );
}

String _sendError(Object e) {
  final s = '$e';
  if (s.contains('permission-denied')) {
    return 'sem permissão (o app pode estar em manutenção).';
  }
  return 'verifique a conexão e tente de novo.';
}

class _Bubble extends StatelessWidget {
  final String text, author;
  final bool mine;
  final DateTime? at;
  const _Bubble(
      {required this.text, required this.mine, required this.author, this.at});

  @override
  Widget build(BuildContext context) => Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints:
              BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: mine ? AppColors.primarySoft : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(author,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMedium)),
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textDark, height: 1.4)),
            if (at != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${fmtDate(at!)} ${fmtTime(at!)}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textLight)),
              ),
          ]),
        ),
      );
}
