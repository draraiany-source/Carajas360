import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'catalog.dart';

/// Estado do catálogo exibido pelas telas.
class CatalogState {
  final Catalog catalog;
  final bool loading;
  final Object? error;

  /// Dados vieram do cache local (sem confirmação do servidor).
  final bool fromCache;

  /// Versão publicada (catalogMeta/current.version).
  final int? version;

  /// O catálogo mudou no servidor durante a sessão.
  final bool updatedRemotely;

  const CatalogState({
    required this.catalog,
    this.loading = false,
    this.error,
    this.fromCache = false,
    this.version,
    this.updatedRemotely = false,
  });

  static final initial = CatalogState(catalog: Catalog.empty, loading: true);

  bool get hasData => !catalog.isEmpty;

  CatalogState copyWith({
    Catalog? catalog,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? fromCache,
    int? version,
    bool? updatedRemotely,
  }) =>
      CatalogState(
        catalog: catalog ?? this.catalog,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        fromCache: fromCache ?? this.fromCache,
        version: version ?? this.version,
        updatedRemotely: updatedRemotely ?? this.updatedRemotely,
      );
}

/// Fonte única do catálogo no app (coleção `catalogNodes`). Alterações
/// feitas no admin chegam em tempo real, sem nova versão do app. Com
/// persistência offline do Firestore, o último catálogo fica em cache e
/// é sinalizado como tal.
class CatalogService {
  CatalogService._();
  static final instance = CatalogService._();

  final ValueNotifier<CatalogState> state =
      ValueNotifier<CatalogState>(CatalogState.initial);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nodesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metaSub;
  bool _started = false;

  /// Atalho síncrono para o catálogo atual (vazio até carregar).
  Catalog get catalog => state.value.catalog;

  /// Inicia a assinatura (idempotente). Chamado pelos widgets.
  void ensureStarted() {
    if (_started) return;
    _started = true;
    _listen();
  }

  void _listen() {
    final db = FirebaseFirestore.instance;
    _nodesSub?.cancel();
    _nodesSub = db
        .collection('catalogNodes')
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      final nodes =
          snap.docs.map((d) => CatalogNode.fromMap(d.id, d.data())).toList();
      state.value = state.value.copyWith(
        catalog: Catalog(nodes),
        loading: false,
        clearError: true,
        fromCache: snap.metadata.isFromCache,
      );
    }, onError: (Object e) {
      state.value = state.value.copyWith(loading: false, error: e);
    });
    _metaSub?.cancel();
    _metaSub = db.collection('catalogMeta').doc('current').snapshots().listen(
        (s) {
      final v = (s.data()?['version'] as num?)?.toInt();
      final prev = state.value.version;
      state.value = state.value.copyWith(
          version: v,
          updatedRemotely:
              prev != null && v != null && v > prev && !s.metadata.isFromCache);
    }, onError: (_) {});
  }

  /// Tentar novamente após erro.
  void retry() {
    state.value = state.value.copyWith(loading: true, clearError: true);
    _listen();
  }

  /// O aviso de "catálogo atualizado" foi exibido.
  void acknowledgeUpdate() {
    if (state.value.updatedRemotely) {
      state.value = state.value.copyWith(updatedRemotely: false);
    }
  }
}
