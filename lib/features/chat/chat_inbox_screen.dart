import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Inbox unificado de conversas (reutiliza chatRooms existentes).
class ChatInboxScreen extends StatelessWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CarajasAppBar(title: 'Mensagens'),
      body: uid == null
          ? EmptyState(
              emoji: '💬',
              title: 'Faça login',
              subtitle: 'Entre na conta para ver suas conversas',
              actionLabel: 'Entrar',
              onAction: () => Navigator.pushNamed(context, Routes.login),
            )
          : StreamBuilder<List<ChatRoomPreview>>(
              stream: FS.chatRoomsStream(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const EmptyState(
                    emoji: '⚠️',
                    title: 'Falha ao carregar conversas',
                    subtitle: 'Verifique a conexão e tente novamente.',
                  );
                }
                final rooms = snap.data ?? [];
                if (rooms.isEmpty) {
                  return const EmptyState(
                    emoji: '💬',
                    title: 'Nenhuma conversa',
                    subtitle:
                        'Suas mensagens com profissionais e clientes aparecem aqui.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = rooms[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      tileColor: AppColors.white,
                      leading: AppAvatar(
                          url: r.otherPhoto,
                          name: r.otherName,
                          size: 48,
                          r: 14),
                      title: Text(r.otherName,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        r.lastMsg.isEmpty ? 'Conversa iniciada' : r.lastMsg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 13),
                      ),
                      trailing: r.lastMsgTime != null
                          ? Text(
                              _fmtTime(r.lastMsgTime!),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight),
                            )
                          : null,
                      onTap: () => Navigator.pushNamed(context, Routes.chat,
                          arguments: {
                            'roomId': r.id,
                            'name': r.otherName,
                            if (r.otherPhoto != null) 'photo': r.otherPhoto,
                          }),
                    );
                  },
                );
              },
            ),
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
