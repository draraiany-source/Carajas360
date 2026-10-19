import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

class _GCtx {
  final String title, icon, origin, dest;
  final Color color;
  const _GCtx(
      {required this.title,
      required this.icon,
      required this.origin,
      required this.dest,
      required this.color});
}

const _ctxMap = {
  'servico': _GCtx(
      title: 'Profissional a caminho',
      icon: '🔧',
      origin: 'Profissional',
      dest: 'Sua localização',
      color: AppColors.primary),
  'saude': _GCtx(
      title: 'Profissional de Saúde',
      icon: '🩺',
      origin: 'Profissional de saúde',
      dest: 'Sua casa',
      color: AppColors.health),
  'mercado': _GCtx(
      title: 'Entrega a caminho',
      icon: '🛵',
      origin: 'Loja',
      dest: 'Seu endereço',
      color: AppColors.secondary),
  'aluguel': _GCtx(
      title: 'Rastreamento ativo',
      icon: '📍',
      origin: 'Item retirado',
      dest: 'Sua localização',
      color: AppColors.navy),
};

class GpsScreen extends StatefulWidget {
  final String ctxKey;
  final String? deliveryId;
  final String? orderId;
  const GpsScreen(
      {super.key, this.ctxKey = 'servico', this.deliveryId, this.orderId});
  @override
  State<GpsScreen> createState() => _GpsState();
}

class _GpsState extends State<GpsScreen> {
  GoogleMapController? _map;
  StreamSubscription? _gpsSub;

  // Sem posição: centraliza na região de Carajás (Parauapebas).
  static const _fallbackOrigin = LatLng(-6.07, -49.90);
  LatLng? _dest;
  LatLng? _pos;
  bool _locating = true;

  _GCtx get _ctx => _ctxMap[widget.ctxKey] ?? _ctxMap['servico']!;
  bool get _live => (widget.deliveryId ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Sem entrega real vinculada não há rastreamento (nada simulado).
    if (!_live) return;
    _resolveUserLocation();
    _gpsSub = FS.gpsStream(widget.deliveryId!).listen((data) {
      final lat = data?['lat'], lng = data?['lng'];
      if (lat is num && lng is num && mounted) {
        setState(() => _pos = LatLng(lat.toDouble(), lng.toDouble()));
        _map?.animateCamera(CameraUpdate.newLatLng(_pos!));
      }
    });
  }

  // Destino = localização real do usuário (se permitido).
  Future<void> _resolveUserLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          !await Geolocator.isLocationServiceEnabled()) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _dest = LatLng(pos.latitude, pos.longitude);
        _locating = false;
      });
      if (_pos == null) {
        _map?.animateCamera(CameraUpdate.newLatLngZoom(_dest!, 14.5));
      }
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_live) {
      return Scaffold(
        appBar: AppBar(title: Text(_ctx.title)),
        body: EmptyState(
          emoji: '📍',
          title: 'Acompanhamento em tempo real indisponível',
          subtitle:
              'Este pedido não tem rastreamento ao vivo. Combine os detalhes '
              'com o profissional pelo chat.',
          actionLabel: 'Voltar',
          onAction: () => Navigator.pop(context),
        ),
      );
    }
    return Scaffold(
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _pos ?? _dest ?? _fallbackOrigin, zoom: 14.5),
          onMapCreated: (c) => _map = c,
          markers: {
            if (_dest != null)
              Marker(
                  markerId: const MarkerId('dest'),
                  position: _dest!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed)),
            if (_pos != null)
              Marker(
                  markerId: const MarkerId('mover'),
                  position: _pos!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange)),
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        if (_locating)
          const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(child: _LocatingBadge())),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Semantics(
                  button: true,
                  label: 'Voltar',
                  excludeSemantics: true,
                  child: Tooltip(
                  message: 'Voltar',
                  child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 16,
                                offset: const Offset(0, 4))
                          ]),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: AppColors.textDark)),
                ))))),
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 32,
                        offset: Offset(0, -8))
                  ]),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
              child: _tracking(),
            )),
      ]),
    );
  }

  Widget _tracking() => Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        const SizedBox(height: 16),
        Text(_ctx.title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Text(
            _pos == null
                ? 'Aguardando a primeira posição...'
                : 'Localização atualizada em tempo real',
            style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
        const SizedBox(height: 14),
        Container(
            decoration: AppDecorations.card(r: 16, elevated: false),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _ctx.color,
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(_ctx.icon, style: const TextStyle(fontSize: 22))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_ctx.origin,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textDark)),
                    Text('→ ${_ctx.dest}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight))
                  ])),
            ])),
      ]);
}

class _LocatingBadge extends StatelessWidget {
  const _LocatingBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 8),
          const Text('Obtendo sua localização...',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark)),
        ]),
      );
}
