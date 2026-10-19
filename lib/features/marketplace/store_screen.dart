import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../checkout/cart.dart';
import '../checkout/cart_service.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/market_order_screen.dart';
import '../checkout/payments_api.dart';
import '../../core/auth/access_control.dart';
import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/catalog/catalog_widgets.dart';

/// Converte valor digitado em reais ("1.234,56", "12,5", "12.50").
/// Com vírgula, pontos são milhar; sem vírgula, "1.234" também é milhar.
/// Devolve null se não for número.
double? parseBrlNumber(String raw) {
  var t = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    t = t.replaceAll('.', '');
  }
  return double.tryParse(t);
}

/// Estoque digitado: vazio = 0; negativo ou inválido = null.
int? parseStock(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return 0;
  final v = int.tryParse(t);
  return (v == null || v < 0) ? null : v;
}

// ─────────────────────────────────────────────────────────────
// MINHA LOJA (Vol.12: Marketplace — lojas de empresas)
// Cadastro da loja, catálogo, estoque e promoções. Carrinho,
// pedidos, cupons, favoritos e avaliações são os já existentes.
// ─────────────────────────────────────────────────────────────
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Minha loja'),
            backgroundColor: AppColors.delivery,
            foregroundColor: Colors.white),
        // Sem login: convida a entrar (não mostra o cadastro que falharia).
        body: !AuthService.isAuth
            ? EmptyState(
                emoji: '🏪',
                title: 'Entre para gerenciar sua loja',
                subtitle: 'É preciso ter uma conta para abrir e gerenciar uma loja.',
                actionLabel: 'Entrar',
                onAction: () => loginAndResume(context))
            : StreamBuilder<StoreModel?>(
          stream: FS.myStoreStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            // Erro de leitura não pode virar o formulário de nova loja.
            if (snap.hasError) return QueryErrorView(error: snap.error);
            final store = snap.data;
            return store == null ? _StoreForm() : _StoreDashboard(store: store);
          },
        ),
      );
}

// ── Cadastro da loja ─────────────────────────────────────────
class _StoreForm extends StatefulWidget {
  @override
  State<_StoreForm> createState() => _StoreFormState();
}

class _StoreFormState extends State<_StoreForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cnpj = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _selectedCats = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _cnpj, _desc, _phone, _city, _state]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selectedCats.isEmpty) {
      snack(context, 'Selecione ao menos uma categoria', bg: AppColors.error);
      return;
    }
    setState(() => _saving = true);
    String? id;
    Object? err;
    try {
      id = await FS.saveStore(StoreModel(
        id: '',
        ownerId: '',
        name: _name.text.trim(),
        cnpj: _cnpj.text.trim(),
        description: _desc.text.trim(),
        phone: _phone.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim().toUpperCase(),
        categories: _selectedCats.toList(),
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('saveStore: $e');
      err = e;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    snack(
        context,
        id != null
            ? '✅ Loja criada!'
            : err != null
                ? 'Falha ao criar a loja: $err'
                : 'Falha ao criar a loja. Verifique se você está logado.',
        bg: id != null ? AppColors.secondary : AppColors.error);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
            key: _form,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration:
                    AppDecorations.gradient(AppGradients.delivery, r: 18),
                padding: const EdgeInsets.all(18),
                width: double.infinity,
                child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🏪 Abra sua loja',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text(
                          'Anuncie seus produtos e venda para todo o marketplace.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
              ),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Nome da loja *'),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Informe o nome'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _cnpj,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'CNPJ')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefone')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    flex: 3,
                    child: TextFormField(
                        controller: _city,
                        decoration:
                            const InputDecoration(labelText: 'Cidade'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        controller: _state,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'UF'))),
              ]),
              const SizedBox(height: 18),
              const Text('Categorias da loja *',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                    // Fonte única: catálogo administrável.
                    child: CatalogBuilder(
                        compact: true,
                        builder: (_, catalog) => CatalogMultiSelect(
                            catalog: catalog,
                            vertical: CatalogVertical.market,
                            selected: _selectedCats,
                            onChanged: (v) => setState(() => _selectedCats
                              ..clear()
                              ..addAll(v))))),
              ),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.delivery,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Criar loja',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                  )),
              const SizedBox(height: 30),
            ])),
      );
}

// ── Painel da loja ───────────────────────────────────────────
class _StoreDashboard extends StatelessWidget {
  final StoreModel store;
  const _StoreDashboard({required this.store});

  @override
  Widget build(BuildContext context) => CustomScrollView(slivers: [
        // Banner da loja — toque para enviar/trocar a imagem.
        SliverToBoxAdapter(
            child: GestureDetector(
          onTap: () => _pickImage(context, 'banner'),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: store.bannerUrl == null ? AppGradients.delivery : null,
              image: store.bannerUrl != null
                  ? DecorationImage(
                      image: CachedNetworkImageProvider(store.bannerUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: store.bannerUrl == null
                ? const Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text('Adicionar banner da loja',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])
                : null,
          ),
        )),
        SliverToBoxAdapter(child: _DeliverySettings(store: store)),
        SliverToBoxAdapter(
            child: Container(
          decoration: AppDecorations.gradient(AppGradients.delivery, r: 0),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                onTap: () => _pickImage(context, 'logo'),
                child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      image: store.logoUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(store.logoUrl!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: store.logoUrl == null
                        ? const Text('🏪', style: TextStyle(fontSize: 26))
                        : null),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(store.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800))),
                      if (store.verified)
                        const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified_rounded,
                                color: Colors.white, size: 18)),
                    ]),
                    Text('${store.city ?? ''} ${store.state ?? ''}'.trim(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ])),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _stat('${store.totalProducts}', 'Produtos'),
              // Sem avaliações: não exibe nota 0,0.
              _stat(store.totalReviews > 0 ? store.rating.toStringAsFixed(1) : '—',
                  'Avaliação'),
              _stat('${store.totalReviews}', 'Avaliações'),
            ]),
          ]),
        )),
        SliverToBoxAdapter(
            child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _menu(
                context,
                '📦',
                'Catálogo e estoque',
                'Adicionar e editar produtos',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _CatalogScreen(store: store)))),
            _menu(
                context,
                '🏷️',
                'Promoções',
                'Defina preço promocional nos produtos',
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => _CatalogScreen(store: store)))),
            // Cupons são criados só pelo admin (sem item aqui).
            _menu(context, '📋', 'Pedidos', 'Acompanhe as vendas',
                () => Navigator.pushNamed(context, Routes.storeOrders)),
          ]),
        )),
      ]);

  /// Seleciona uma imagem da galeria e a envia como logo ou banner.
  Future<void> _pickImage(BuildContext context, String kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: kind == 'banner' ? 1600 : 600,
    );
    if (picked == null) return;
    if (context.mounted)
      snack(context, 'Enviando imagem...', bg: AppColors.primary);
    final url = await FS.uploadStoreImage(
        store.id, await picked.readAsBytes(), picked.name, kind);
    if (!context.mounted) return;
    snack(context,
        url != null ? '✅ Imagem atualizada!' : 'Falha ao enviar a imagem.',
        bg: url != null ? AppColors.secondary : AppColors.error);
  }

  Widget _stat(String v, String l) => Expanded(
          child: Column(children: [
        Text(v,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        Text(l, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]));

  Widget _menu(BuildContext c, String icon, String title, String sub,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: AppDecorations.card(r: 16),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textLight)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
          ]),
        ),
      );
}

// ── Catálogo / estoque ───────────────────────────────────────
class _CatalogScreen extends StatelessWidget {
  final StoreModel store;
  const _CatalogScreen({required this.store});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Catálogo'),
            backgroundColor: AppColors.delivery,
            foregroundColor: Colors.white),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _productSheet(context),
          backgroundColor: AppColors.secondary,
          child: const Icon(Icons.add),
        ),
        body: StreamBuilder<List<ProductModel>>(
          stream: FS.productsStream(storeId: store.id),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return QueryErrorView(error: snap.error);
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return const EmptyState(
                  emoji: '📦',
                  title: 'Nenhum produto',
                  subtitle: 'Toque no + para anunciar seu primeiro produto');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final p = items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppDecorations.card(r: 16),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(p.emoji ?? '📦',
                            style: const TextStyle(fontSize: 22))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          Row(children: [
                            if (p.onSale) ...[
                              Text(PaySvc.fmt(p.price),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                      decoration: TextDecoration.lineThrough)),
                              const SizedBox(width: 6),
                            ],
                            Text(PaySvc.fmt(p.finalPrice),
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.delivery)),
                            if (p.onSale)
                              Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: AppTag('-${p.discountPercent}%',
                                      bg: const Color(0xFFFFEBEE),
                                      fg: AppColors.error)),
                          ]),
                          Text(
                              p.inStock ? 'Estoque: ${p.stock}' : 'Sem estoque',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: p.inStock
                                      ? AppColors.textLight
                                      : AppColors.error)),
                        ])),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.primary),
                      onPressed: () => _productSheet(context, edit: p),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: AppColors.error),
                      onPressed: () => _confirmRemove(context, p),
                    ),
                  ]),
                );
              },
            );
          },
        ),
      );

  Future<void> _confirmRemove(BuildContext context, ProductModel p) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Excluir produto?'),
              content: Text('"${p.name}" deixará de aparecer no marketplace.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Voltar')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Excluir',
                        style: TextStyle(color: AppColors.error))),
              ],
            ));
    if (ok != true) return;
    try {
      await FS.removeProduct(p.id, store.id);
      if (context.mounted) {
        snack(context, 'Produto excluído', bg: AppColors.secondary);
      }
    } catch (e) {
      if (context.mounted) {
        snack(context, 'Não foi possível excluir o produto: $e',
            bg: AppColors.error);
      }
    }
  }

  void _productSheet(BuildContext context, {ProductModel? edit}) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ProductSheet(store: store, edit: edit));
  }
}

/// Formulário de produto (dono dos controllers: libera no dispose).
class _ProductSheet extends StatefulWidget {
  final StoreModel store;
  final ProductModel? edit;
  const _ProductSheet({required this.store, this.edit});
  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  // Preço pré-preenchido no formato brasileiro (vírgula decimal).
  static String _fmt(double? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _price = TextEditingController(text: _fmt(widget.edit?.price));
  late final _promo =
      TextEditingController(text: _fmt(widget.edit?.promoPrice));
  late final _stock =
      TextEditingController(text: '${widget.edit?.stock ?? 0}');
  late final _emoji = TextEditingController(text: widget.edit?.emoji ?? '📦');
  late final _desc =
      TextEditingController(text: widget.edit?.description ?? '');
  late String _cat = widget.edit?.category ??
      (widget.store.categories.isNotEmpty
          ? widget.store.categories.first
          : 'materials');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _price, _promo, _stock, _emoji, _desc]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Categorias da loja (+ a atual do produto, se não estiver nelas).
  List<String> get _catOptions => {
        ...widget.store.categories,
        _cat,
      }.toList();

  Future<void> _save() async {
    final v = parseBrlNumber(_price.text) ?? 0;
    if (_name.text.trim().isEmpty || v <= 0) {
      snack(context, 'Informe nome e preço válidos', bg: AppColors.error);
      return;
    }
    final stock = parseStock(_stock.text);
    if (stock == null) {
      snack(context, 'Estoque inválido (use 0 ou mais)', bg: AppColors.error);
      return;
    }
    final pr = parseBrlNumber(_promo.text);
    final edit = widget.edit;
    setState(() => _saving = true);
    try {
      await FS.saveProduct(ProductModel(
        id: edit?.id ?? '',
        storeId: widget.store.id,
        storeName: widget.store.name,
        name: _name.text.trim(),
        category: _cat,
        description: _desc.text.trim(),
        emoji: _emoji.text.trim().isEmpty ? '📦' : _emoji.text.trim(),
        price: v,
        promoPrice: (pr != null && pr > 0 && pr < v) ? pr : null,
        stock: stock,
        createdAt: DateTime.now(),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        snack(context, 'Não foi possível salvar o produto: $e',
            bg: AppColors.error);
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = CatalogService.instance.catalog;
    const money = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SheetHandle(),
        const SizedBox(height: 14),
        Text(widget.edit == null ? 'Novo produto' : 'Editar produto',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Row(children: [
          SizedBox(
              width: 70,
              child: TextField(
                  controller: _emoji,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Ícone'))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Nome do produto *'))),
        ]),
        const SizedBox(height: 12),
        // Categoria escolhida pelo lojista entre as da loja.
        DropdownButtonFormField<String>(
          key: const Key('product-category'),
          initialValue: _cat,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Categoria'),
          items: [
            for (final id in _catOptions)
              DropdownMenuItem(
                  value: id,
                  child: Text(catalog.nameOf(id),
                      overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _cat = v ?? _cat),
        ),
        const SizedBox(height: 12),
        TextField(
            controller: _desc,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Descrição')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TextField(
                  controller: _price,
                  keyboardType: money,
                  decoration: const InputDecoration(
                      labelText: 'Preço *', prefixText: 'R\$ '))),
          const SizedBox(width: 10),
          Expanded(
              child: TextField(
                  controller: _promo,
                  keyboardType: money,
                  decoration: const InputDecoration(
                      labelText: 'Promoção', prefixText: 'R\$ '))),
        ]),
        const SizedBox(height: 12),
        TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Estoque')),
        const SizedBox(height: 18),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.delivery,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              child: Text(
                  widget.edit == null ? 'Publicar produto' : 'Salvar alterações',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            )),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VITRINE DE LOJAS — lista pública das lojas do marketplace
// ─────────────────────────────────────────────────────────────
class StoresListScreen extends StatelessWidget {
  const StoresListScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: const Text('Lojas'),
            backgroundColor: AppColors.delivery,
            foregroundColor: Colors.white),
        body: StreamBuilder<List<StoreModel>>(
          stream: FS.storesStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return QueryErrorView(error: snap.error);
            final stores = snap.data ?? [];
            if (stores.isEmpty) {
              return const EmptyState(
                  emoji: '🏪',
                  title: 'Nenhuma loja ainda',
                  subtitle: 'As lojas cadastradas aparecerão aqui');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: stores.length,
              itemBuilder: (_, i) {
                final s = stores[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => StoreProfileScreen(store: s))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: AppDecorations.card(r: 16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      SizedBox(
                          height: 88,
                          width: double.infinity,
                          child: s.bannerUrl == null
                              ? Container(
                                  decoration: const BoxDecoration(
                                      gradient: AppGradients.delivery))
                              : CachedNetworkImage(
                                  imageUrl: s.bannerUrl!, fit: BoxFit.cover)),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12)),
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                child: s.logoUrl == null
                                    ? const Text('🏪',
                                        style: TextStyle(fontSize: 20))
                                    : CachedNetworkImage(
                                        imageUrl: s.logoUrl!,
                                        fit: BoxFit.cover,
                                        width: 44,
                                        height: 44)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Flexible(
                                        child: Text(s.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14))),
                                    if (s.verified)
                                      const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.verified_rounded,
                                              size: 15,
                                              color: AppColors.primary)),
                                  ]),
                                  Text(
                                      '${s.totalProducts} produtos · ${s.city ?? ''}',
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textLight)),
                                ])),
                            if (s.totalReviews > 0)
                              Row(children: [
                                const Icon(Icons.star_rounded,
                                    size: 15, color: AppColors.gold),
                                Text(' ${s.rating.toStringAsFixed(1)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ]),
                          ])),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// PERFIL PÚBLICO DA LOJA — vitrine de produtos para o comprador
// ─────────────────────────────────────────────────────────────
class StoreProfileScreen extends StatelessWidget {
  final StoreModel store;
  const StoreProfileScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        // Atalho para o carrinho quando há itens.
        floatingActionButton: ListenableBuilder(
            listenable: CartService.instance,
            builder: (context, _) {
              final n = CartService.instance.cart.totalItems;
              if (n == 0) return const SizedBox.shrink();
              return FloatingActionButton.extended(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.shopping_cart_rounded),
                  label: Text('Ver carrinho ($n)'),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen())));
            }),
        body: CustomScrollView(slivers: [
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            backgroundColor: AppColors.delivery,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: store.bannerUrl == null
                  ? Container(
                      decoration:
                          const BoxDecoration(gradient: AppGradients.delivery))
                  : CachedNetworkImage(
                      imageUrl: store.bannerUrl!, fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8)
                      ]),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: store.logoUrl == null
                      ? const Text('🏪', style: TextStyle(fontSize: 26))
                      : CachedNetworkImage(
                          imageUrl: store.logoUrl!,
                          fit: BoxFit.cover,
                          width: 58,
                          height: 58)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Flexible(
                          child: Text(store.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w900))),
                      if (store.verified)
                        const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(Icons.verified_rounded,
                                size: 17, color: AppColors.primary)),
                    ]),
                    Text('${store.city ?? ''} ${store.state ?? ''}'.trim(),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    if (store.totalReviews > 0)
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            size: 15, color: AppColors.gold),
                        Text(
                            ' ${store.rating.toStringAsFixed(1)} (${store.totalReviews} avaliações)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                  ])),
            ]),
          )),
          if (store.description != null && store.description!.isNotEmpty)
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(store.description!,
                  style: const TextStyle(
                      fontSize: 13, height: 1.5, color: AppColors.textMedium)),
            )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SecHeader(title: 'Produtos (${store.totalProducts})'),
          )),
          StreamBuilder<List<ProductModel>>(
            stream: FS.productsStream(storeId: store.id),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator())));
              }
              if (snap.hasError) {
                return SliverToBoxAdapter(
                    child: QueryErrorView(error: snap.error));
              }
              final items = snap.data ?? [];
              if (items.isEmpty) {
                return const SliverToBoxAdapter(
                    child: Padding(
                  padding: EdgeInsets.all(30),
                  child: EmptyState(
                      emoji: '📦',
                      title: 'Sem produtos',
                      subtitle: 'Esta loja ainda não publicou produtos'),
                ));
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: .78),
                  delegate: SliverChildBuilderDelegate((_, i) {
                    final p = items[i];
                    return Container(
                      decoration: AppDecorations.card(r: 14),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Text(p.emoji ?? '📦',
                                  style: const TextStyle(fontSize: 34)),
                            )),
                            const SizedBox(height: 8),
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Row(children: [
                              Text(PaySvc.fmt(p.finalPrice),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.delivery)),
                              if (p.onSale)
                                Padding(
                                    padding: const EdgeInsets.only(left: 5),
                                    child: AppTag('-${p.discountPercent}%',
                                        bg: const Color(0xFFFFEBEE),
                                        fg: AppColors.error)),
                            ]),
                            const SizedBox(height: 6),
                            _AddToCart(product: p, store: store),
                          ]),
                    );
                  }, childCount: items.length),
                ),
              );
            },
          ),
        ]),
      );
}

/// Botão de carrinho do card da vitrine (mesmo carrinho do marketplace).
class _AddToCart extends StatelessWidget {
  final ProductModel product;
  final StoreModel store;
  const _AddToCart({required this.product, required this.store});

  CartLine _line(int qty) => CartLine(
      productId: product.id,
      storeId: product.storeId.isNotEmpty ? product.storeId : store.id,
      storeName: product.storeName.isNotEmpty ? product.storeName : store.name,
      name: product.name,
      emoji: product.emoji ?? '📦',
      unitPriceCents: (product.finalPrice * 100).round(),
      qty: qty);

  @override
  Widget build(BuildContext context) {
    if (!product.inStock) {
      return const SizedBox(
          height: 30,
          child: Center(
              child: Text('Sem estoque',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error))));
    }
    return ListenableBuilder(
        listenable: CartService.instance,
        builder: (context, _) {
          final qty = CartService.instance.cart.qtyOf(product.id);
          if (qty == 0) {
            return SizedBox(
                width: double.infinity,
                height: 30,
                child: ElevatedButton(
                    onPressed: () =>
                        CartService.instance.setQty(_line(1), 1),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('+ Adicionar',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white))));
          }
          return SizedBox(
              height: 30,
              child: Row(children: [
                IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () =>
                        CartService.instance.setQty(_line(qty), qty - 1)),
                Expanded(
                    child: Text('$qty',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: const Icon(Icons.add_circle_outline,
                        color: AppColors.secondary),
                    onPressed: () =>
                        CartService.instance.setQty(_line(qty), qty + 1)),
              ]));
        });
  }
}

/// Frete e modos de entrega da loja. O servidor usa estes campos para
/// calcular o total do pedido (o app nunca define o frete).
class _DeliverySettings extends StatefulWidget {
  final StoreModel store;
  const _DeliverySettings({required this.store});
  @override
  State<_DeliverySettings> createState() => _DeliverySettingsState();
}

class _DeliverySettingsState extends State<_DeliverySettings> {
  late final _fee = TextEditingController(
      text: ((widget.store.deliveryFeeCents ?? 0) / 100).toStringAsFixed(2));
  late bool _delivery = widget.store.deliveryEnabled;
  late bool _pickup = widget.store.pickupEnabled;
  bool _saving = false;

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cents =
        ((parseBrlNumber(_fee.text) ?? -1) * 100).round();
    if (cents < 0 || cents > 100000) {
      snack(context, 'Frete inválido (R\$ 0 a R\$ 1.000)', bg: AppColors.error);
      return;
    }
    if (!_delivery && !_pickup) {
      snack(context, 'Ative entrega ou retirada', bg: AppColors.error);
      return;
    }
    setState(() => _saving = true);
    final ok = await FS.updateStoreDelivery(widget.store.id,
        deliveryFeeCents: cents, deliveryEnabled: _delivery, pickupEnabled: _pickup);
    if (!mounted) return;
    setState(() => _saving = false);
    snack(context, ok ? 'Entrega atualizada' : 'Não foi possível salvar',
        bg: ok ? AppColors.secondary : AppColors.error);
  }

  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: AppDecorations.card(r: 16),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('🚚 Entrega e pedidos',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StoreOrdersScreen())),
              child: const Text('Pedidos recebidos')),
        ]),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Faz entrega'),
            value: _delivery,
            onChanged: (v) => setState(() => _delivery = v)),
        if (_delivery)
          TextField(
              controller: _fee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Taxa de entrega', prefixText: 'R\$ ')),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Aceita retirada na loja'),
            value: _pickup,
            onChanged: (v) => setState(() => _pickup = v)),
        Text('Taxa atual: ${brl(widget.store.deliveryFeeCents ?? 0)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _saving ? null : _save, child: const Text('Salvar'))),
      ]));
}
