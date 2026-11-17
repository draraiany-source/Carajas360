import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/orders/order_photos.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../shared/widgets/widgets.dart';

/// Seletor de fotos do ambiente (câmera/galeria), até [OrderPhotos.maxCount].
class OrderPhotoPicker extends StatelessWidget {
  final List<OrderPhotoDraft> photos;
  final ValueChanged<List<OrderPhotoDraft>> onChanged;
  final bool enabled;

  const OrderPhotoPicker({
    super.key,
    required this.photos,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _add(BuildContext context, ImageSource source) async {
    if (!enabled) return;
    final remaining = OrderPhotos.maxCount - photos.length;
    if (remaining <= 0) {
      snack(context, OrderPhotos.countError(photos.length, 1)!,
          bg: AppColors.warning);
      return;
    }
    try {
      final picker = ImagePicker();
      final added = <OrderPhotoDraft>[];
      if (source == ImageSource.gallery) {
        final files = await picker.pickMultiImage(
          imageQuality: 72,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        for (final f in files.take(remaining)) {
          final bytes = await f.readAsBytes();
          final err = OrderPhotos.fileError(
              fileName: f.name, byteLength: bytes.length);
          if (err != null) {
            if (context.mounted) snack(context, err, bg: AppColors.warning);
            continue;
          }
          added.add(OrderPhotoDraft(
            id: '${DateTime.now().microsecondsSinceEpoch}_${added.length}',
            fileName: f.name.isNotEmpty ? f.name : 'foto.jpg',
            bytes: bytes,
          ));
        }
      } else {
        final f = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 72,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        if (f == null) return;
        final bytes = await f.readAsBytes();
        final err =
            OrderPhotos.fileError(fileName: f.name, byteLength: bytes.length);
        if (err != null) {
          if (context.mounted) snack(context, err, bg: AppColors.error);
          return;
        }
        added.add(OrderPhotoDraft(
          id: '${DateTime.now().microsecondsSinceEpoch}',
          fileName: f.name.isNotEmpty ? f.name : 'camera.jpg',
          bytes: bytes,
        ));
      }
      if (added.isEmpty) return;
      final countErr = OrderPhotos.countError(photos.length, added.length);
      if (countErr != null) {
        if (context.mounted) snack(context, countErr, bg: AppColors.warning);
        return;
      }
      onChanged([...photos, ...added]);
    } catch (_) {
      if (context.mounted) {
        snack(context, 'Não foi possível anexar a foto.', bg: AppColors.error);
      }
    }
  }

  Future<void> _replace(BuildContext context, int index) async {
    if (!enabled || index < 0 || index >= photos.length) return;
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (f == null) return;
      final bytes = await f.readAsBytes();
      final err =
          OrderPhotos.fileError(fileName: f.name, byteLength: bytes.length);
      if (err != null) {
        if (context.mounted) snack(context, err, bg: AppColors.error);
        return;
      }
      final next = List<OrderPhotoDraft>.from(photos);
      next[index] = OrderPhotoDraft(
        id: photos[index].id,
        fileName: f.name.isNotEmpty ? f.name : photos[index].fileName,
        bytes: bytes,
      );
      onChanged(next);
    } catch (_) {
      if (context.mounted) {
        snack(context, 'Não foi possível substituir a foto.',
            bg: AppColors.error);
      }
    }
  }

  void _remove(int index) {
    if (!enabled) return;
    final next = List<OrderPhotoDraft>.from(photos)..removeAt(index);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Fotos do ambiente (opcional, até ${OrderPhotos.maxCount})',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 6),
        Text(
          'JPG, PNG ou WebP · até 8 MB cada · compressão automática. '
          'Visíveis só para você, o profissional do pedido e administradores.',
          style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context)),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _add(context, ImageSource.gallery)
                : null,
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Galeria'),
          ),
          OutlinedButton.icon(
            onPressed: enabled && !kIsWeb
                ? () => _add(context, ImageSource.camera)
                : (enabled && kIsWeb
                    ? () => _add(context, ImageSource.camera)
                    : null),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(kIsWeb ? 'Câmera / arquivo' : 'Câmera'),
          ),
        ]),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final p = photos[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        p.bytes,
                        width: 104,
                        height: 104,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (enabled)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _miniBtn(
                            Icons.swap_horiz_rounded,
                            () => _replace(context, i),
                          ),
                          const SizedBox(width: 4),
                          _miniBtn(Icons.close_rounded, () => _remove(i)),
                        ]),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text('${photos.length}/${OrderPhotos.maxCount} foto(s)',
              style: TextStyle(fontSize: 12, color: Brand.inkMuted(context))),
        ],
      ],
    );
  }

  Widget _miniBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      );
}

/// Grade somente leitura de URLs remotas (cliente / profissional).
class OrderPhotoGallery extends StatelessWidget {
  final List<String> urls;
  final String emptyLabel;
  const OrderPhotoGallery({
    super.key,
    required this.urls,
    this.emptyLabel = 'Nenhuma foto anexada',
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Text(emptyLabel,
          style: TextStyle(fontSize: 13, color: Brand.inkMuted(context)));
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final url = urls[i];
          return GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                url,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 96,
                  height: 96,
                  color: Brand.line(context),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
