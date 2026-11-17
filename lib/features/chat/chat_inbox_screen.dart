import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';

/// Inbox unificado de conversas (reutiliza chatRooms existentes).
/// Em tela larga usa o chrome da marca (Tela 07); no celular mantém a lista.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  String _q = '';
  int _streamGen = 0;
  late Stream<List<ChatRoomPreview>> _rooms = FS.chatRoomsStream();

  void _retryRooms() {
    setState(() {
      _streamGen++;
      _rooms = FS.chatRoomsStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final uid = AuthService.uid;
    final body = _body(context, uid, wide);
    if (!wide) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const CarajasAppBar(title: 'Mensagens'),
        body: body,
      );
    }
    return Scaffold(
      backgroundColor: Brand.isDark(context) ? null : Brand.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            BrandContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: BrandBreadcrumb(items: [
                        (
                          'Início',
                          () => Navigator.pushNamedAndRemoveUntil(
                              context, Routes.main, (_) => false)
                        ),
                        ('Meus pedidos',
                            () => Navigator.pushNamed(context, Routes.myOrders)),
                        ('Mensagens', null),
                      ]),
                    ),
                    BrandBackLink(onTap: () => AppNav.safeBack(context)),
                  ]),
                  const SizedBox(height: 12),
                  const BrandPageHero(
                    title: 'Mensagens e orçamento',
                    subtitle: 'Converse com o profissional e confira a proposta.',
                    height: 120,
                  ),
                  const SizedBox(height: 12),
                  if (BrandShell.demoMode) ...[
                    const BrandDemoNotice(
                        message:
                            'Modo demonstração • conversas reais só com profissionais cadastrados.'),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  BrandSoftCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Conversas',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Brand.ink(context))),
                        const SizedBox(height: 12),
                        if (uid != null) ...[
                          TextField(
                            onChanged: (v) => setState(() => _q = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: 'Buscar conversa',
                              isDense: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: Brand.line(context))),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          height: 480,
                          child: body,
                        ),
                      ],
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

  Widget _body(BuildContext context, String? uid, bool wide) {
    if (uid == null) {
      return EmptyState(
        emoji: '💬',
        title: 'Faça login',
        subtitle: 'Entre na conta para ver suas conversas',
        actionLabel: 'Entrar',
        onAction: () => Navigator.pushNamed(context, Routes.login),
      );
    }
    return StreamBuilder<List<ChatRoomPreview>>(
      key: ValueKey(_streamGen),
      stream: _rooms,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return EmptyState(
            emoji: '⚠️',
            title: 'Falha ao carregar conversas',
            subtitle: 'Verifique a conexão e tente novamente.',
            actionLabel: 'Tentar novamente',
            onAction: _retryRooms,
          );
        }
        var rooms = snap.data ?? [];
        if (rooms.isEmpty) {
          return const EmptyState(
            emoji: '💬',
            title: 'Nenhuma conversa',
            subtitle:
                'Suas mensagens com profissionais e clientes aparecem aqui.',
          );
        }
        final q = _q.trim().toLowerCase();
        if (wide && q.isNotEmpty) {
          rooms = rooms
              .where((r) =>
                  r.otherName.toLowerCase().contains(q) ||
                  r.lastMsg.toLowerCase().contains(q))
              .toList();
          if (rooms.isEmpty) {
            return const EmptyState(
              emoji: '🔍',
              title: 'Nada encontrado',
              subtitle: 'Nenhuma conversa com esse termo.',
            );
          }
        }
        return ListView.separated(
          padding: wide
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final r = rooms[i];
            return ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                    color: wide ? Brand.line(context) : AppColors.border),
              ),
              tileColor: wide ? Brand.surface(context) : AppColors.white,
              leading: AppAvatar(
                  url: r.otherPhoto, name: r.otherName, size: 48, r: 14),
              title: Text(r.otherName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(
                r.lastMsg.isEmpty ? 'Conversa iniciada' : r.lastMsg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
              trailing: r.lastMsgTime != null
                  ? Text(
                      _fmtTime(r.lastMsgTime!),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight),
                    )
                  : null,
              onTap: () =>
                  Navigator.pushNamed(context, Routes.chat, arguments: {
                'roomId': r.id,
                'name': r.otherName,
                if (r.otherPhoto != null) 'photo': r.otherPhoto,
              }),
            );
          },
        );
      },
    );
  }

  static String _fmtTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
  }
}
