import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/query_errors.dart';
import '../../shared/widgets/widgets.dart';
import 'paged_list.dart';

export 'paged_list.dart';

/// Página de uma consulta do Firestore a partir do cursor.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> firestorePage(
    Query<Map<String, dynamic>> q,
    QueryDocumentSnapshot<Map<String, dynamic>>? after,
    int limit) async {
  if (after != null) q = q.startAfterDocument(after);
  return (await q.limit(limit).get()).docs;
}

/// Controlador paginado para uma consulta do Firestore.
PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> pagedQuery(
        Query<Map<String, dynamic>> Function() query,
        {int pageSize = 50,
        bool Function(QueryDocumentSnapshot<Map<String, dynamic>>)? keep}) =>
    PagedList(
        fetch: (after, limit) => firestorePage(query(), after, limit),
        idOf: (d) => d.id,
        pageSize: pageSize,
        keep: keep);

/// Lista com "Carregar mais", puxar para atualizar, erro e vazio.
class PagedListView<D> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.all(16),
  });

  final PagedList<D> controller;
  final Widget Function(BuildContext, D) itemBuilder;
  final Widget empty;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final items = c.items;
        if (items.isEmpty) {
          if (c.error != null) {
            return QueryErrorView(error: c.error, onRetry: c.refresh);
          }
          if (!c.loadedOnce || c.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!c.hasMore) {
            return RefreshIndicator(
                onRefresh: c.refresh,
                child: ListView(children: [
                  if (header != null) header!,
                  const SizedBox(height: 40),
                  empty,
                ]));
          }
        }
        final extra = header != null ? 1 : 0;
        return RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView.builder(
              padding: padding,
              itemCount: items.length + extra + 1,
              itemBuilder: (ctx, i) {
                if (header != null && i == 0) return header!;
                final j = i - extra;
                if (j < items.length) return itemBuilder(ctx, items[j]);
                return _footer(c);
              }),
        );
      });

  Widget _footer(PagedList<D> c) {
    if (c.loading) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()));
    }
    if (c.error != null) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Text(friendlyQueryError(c.error),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.error)),
            TextButton(onPressed: c.loadMore, child: const Text('Tentar novamente')),
          ]));
    }
    if (c.hasMore) {
      return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
              child: OutlinedButton(
                  key: const Key('paged-load-more'),
                  onPressed: c.loadMore,
                  child: const Text('Carregar mais'))));
    }
    return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: Text('Fim da lista',
                style: TextStyle(fontSize: 11, color: AppColors.textLight))));
  }
}
