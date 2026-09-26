import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/category_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/firebase_bootstrap.dart';
import '../../core/utils/tap_guard.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../wallet/wallet_screen.dart';

class MarketProduct {
  final String id, name, category, store;
  final String? emoji, imageUrl, description;
  final double price;
  final double? oldPrice;
  final double rating;
  final String deliveryEta;
  final bool available;
  final bool isHomologSeed;

  const MarketProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.store,
    required this.price,
    required this.rating,
    this.emoji,
    this.imageUrl,
    this.description,
    this.oldPrice,
    this.deliveryEta = '30-60 min',
    this.available = true,
    this.isHomologSeed = false,
  });

  double get displayPrice => price;
  bool get onSale => oldPrice != null && oldPrice! > price;
  int get discountPercent =>
      onSale ? (((oldPrice! - price) / oldPrice!) * 100).round() : 0;
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketState();
}

class _MarketState extends State<MarketplaceScreen> {
  int _cat = 0;
  final Map<String, int> _cart = {};
  bool _paying = false;
  bool _loadingProducts = true;
  bool _streamErrorShown = false;
  String _query = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  StreamSubscription<List<ProductModel>>? _prodSub;
  List<MarketProduct> _storeProducts = const [];

  String _checkoutAddress = '';
  String _deliveryMode = 'delivery'; // delivery|pickup

  static const _cats = [
    {'id': 'all', 'name': 'Todos'},
    {'id': 'market', 'name': 'Mercado'},
    {'id': 'pharmacy', 'name': 'Farmácia'},
    {'id': 'pet', 'name': 'Pet Shop'},
    {'id': 'materials', 'name': 'Materiais'},
    {'id': 'food', 'name': 'Refeições'},
    {'id': 'agro', 'name': 'Agro'},
    {'id': 'machines', 'name': 'Máquinas'},
    {'id': 'tools', 'name': 'Ferramentas'},
  ];

  static IconData _catIcon(String id) {
    switch (id) {
      case 'all':
        return Icons.storefront_rounded;
      case 'market':
        return Icons.shopping_cart_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'pet':
        return Icons.pets_rounded;
      case 'materials':
        return Icons.construction_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'agro':
        return Icons.agriculture_rounded;
      case 'machines':
        return Icons.precision_manufacturing_rounded;
      case 'tools':
        return Icons.handyman_rounded;
      default:
        return CategoryIcons.forModule(id);
    }
  }

  // SEED/MOCK/HOMOLOGAÇÃO — não usar em produção
  static const _homologSeedProducts = <MarketProduct>[
    MarketProduct(
        id: 'p1',
        name: 'Arroz Tipo 1 5kg',
        emoji: '🌾',
        category: 'market',
        price: 22.90,
        oldPrice: 26.90,
        store: 'SuperMarket',
        rating: 4.8,
        isHomologSeed: true),
    MarketProduct(
        id: 'p2',
        name: 'Feijão Carioca 1kg',
        emoji: '🫘',
        category: 'market',
        price: 8.50,
        store: 'SuperMarket',
        rating: 4.6,
        isHomologSeed: true),
    MarketProduct(
        id: 'p3',
        name: 'Óleo de Soja 900ml',
        emoji: '🫙',
        category: 'market',
        price: 6.90,
        store: 'SuperMarket',
        rating: 4.5,
        isHomologSeed: true),
    MarketProduct(
        id: 'p4',
        name: 'Frango Inteiro 2kg',
        emoji: '🍗',
        category: 'market',
        price: 18.90,
        store: 'FrigoFresh',
        rating: 4.7,
        isHomologSeed: true),
    MarketProduct(
        id: 'p6',
        name: 'Dipirona 500mg c/10',
        emoji: '💊',
        category: 'pharmacy',
        price: 3.50,
        store: 'FarmaTop',
        rating: 4.9,
        isHomologSeed: true),
    MarketProduct(
        id: 'p7',
        name: 'Paracetamol 750mg c/10',
        emoji: '💊',
        category: 'pharmacy',
        price: 4.20,
        store: 'FarmaTop',
        rating: 4.8,
        isHomologSeed: true),
    MarketProduct(
        id: 'p8',
        name: 'Ração Golden 1kg',
        emoji: '🐕',
        category: 'pet',
        price: 29.90,
        store: 'PetShopMais',
        rating: 4.9,
        isHomologSeed: true),
    MarketProduct(
        id: 'p9',
        name: 'Areia Higiênica 4kg',
        emoji: '🐱',
        category: 'pet',
        price: 18.50,
        store: 'PetShopMais',
        rating: 4.7,
        isHomologSeed: true),
    MarketProduct(
        id: 'p10',
        name: 'Cimento CP-II 50kg',
        emoji: '🏗️',
        category: 'materials',
        price: 32.90,
        store: 'ConstBela',
        rating: 4.6,
        isHomologSeed: true),
    MarketProduct(
        id: 'p11',
        name: 'Tinta Látex Branca 18L',
        emoji: '🎨',
        category: 'materials',
        price: 89.90,
        store: 'ConstBela',
        rating: 4.8,
        isHomologSeed: true),
    MarketProduct(
        id: 'p12',
        name: 'X-Burger Artesanal',
        emoji: '🍔',
        category: 'food',
        price: 28.90,
        store: 'Burguer 99',
        rating: 4.9,
        deliveryEta: '25-40 min',
        isHomologSeed: true),
    MarketProduct(
        id: 'p13',
        name: 'Pizza 8 Fatias',
        emoji: '🍕',
        category: 'food',
        price: 45.90,
        oldPrice: 52.90,
        store: 'PizzaHouse',
        rating: 4.7,
        deliveryEta: '35-50 min',
        isHomologSeed: true),
    MarketProduct(
        id: 'p14',
        name: 'Semente de Milho 60k',
        emoji: '🌽',
        category: 'agro',
        price: 890.00,
        store: 'AgroCampo',
        rating: 4.8,
        deliveryEta: '1-2 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p15',
        name: 'Adubo NPK 20-05-20 50kg',
        emoji: '🌱',
        category: 'agro',
        price: 189.90,
        store: 'AgroCampo',
        rating: 4.7,
        deliveryEta: '1-2 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p16',
        name: 'Herbicida Seletivo 5L',
        emoji: '🧪',
        category: 'agro',
        price: 349.00,
        store: 'RuralMax',
        rating: 4.6,
        deliveryEta: '1-2 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p17',
        name: 'Arame Farpado 500m',
        emoji: '🚧',
        category: 'agro',
        price: 429.00,
        store: 'RuralMax',
        rating: 4.8,
        deliveryEta: '1-2 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p18',
        name: 'Sal Mineral Bovino 30kg',
        emoji: '🐄',
        category: 'agro',
        price: 98.00,
        store: 'AgroCampo',
        rating: 4.9,
        deliveryEta: '1-2 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p19',
        name: 'Pneu Trator 18.4-34',
        emoji: '🛞',
        category: 'machines',
        price: 3290.00,
        store: 'MáquinaSul',
        rating: 4.7,
        deliveryEta: '2-4 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p20',
        name: 'Bico Pulverizador (kit 20)',
        emoji: '💨',
        category: 'machines',
        price: 279.90,
        store: 'MáquinaSul',
        rating: 4.6,
        deliveryEta: '2-4 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p21',
        name: 'Filtro Óleo Colheitadeira',
        emoji: '🔩',
        category: 'machines',
        price: 156.00,
        store: 'PeçasAgro',
        rating: 4.8,
        deliveryEta: '2-4 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p22',
        name: 'Motobomba 3CV',
        emoji: '⚙️',
        category: 'machines',
        price: 1290.00,
        store: 'PeçasAgro',
        rating: 4.7,
        deliveryEta: '2-4 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p23',
        name: 'Roçadeira Lateral 43cc',
        emoji: '🌿',
        category: 'tools',
        price: 899.00,
        store: 'FerraTop',
        rating: 4.8,
        deliveryEta: '1-3 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p24',
        name: 'Máquina de Solda 200A',
        emoji: '🔥',
        category: 'tools',
        price: 749.00,
        store: 'FerraTop',
        rating: 4.9,
        deliveryEta: '1-3 dias',
        isHomologSeed: true),
    MarketProduct(
        id: 'p25',
        name: 'Gerador 5,5 kVA',
        emoji: '🔌',
        category: 'tools',
        price: 3490.00,
        store: 'FerraTop',
        rating: 4.7,
        deliveryEta: '1-3 dias',
        isHomologSeed: true),
  ];

  static bool get _seedEnabled =>
      FirebaseBootstrap.hasPlaceholderKeys || kDebugMode;

  List<MarketProduct> get _seedProducts =>
      _seedEnabled ? _homologSeedProducts : const [];

  List<MarketProduct> get _allProducts => [..._seedProducts, ..._storeProducts];

  String _catName(String id) {
    for (final c in _cats) {
      if (c['id'] == id) return c['name']!;
    }
    return id;
  }

  List<MarketProduct> get _filtered {
    final cat = _cats[_cat]['id']!;
    var list = cat == 'all'
        ? _allProducts
        : _allProducts.where((p) => p.category == cat).toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.store.toLowerCase().contains(q) ||
              _catName(p.category).toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  int get _totalItems => _cart.values.fold(0, (s, q) => s + q);

  MarketProduct _emptyProduct([String id = '']) => MarketProduct(
        id: id,
        name: 'Produto',
        category: '',
        store: '',
        price: 0,
        rating: 0,
        emoji: '📦',
      );

  MarketProduct _findProduct(String id) => _allProducts.firstWhere(
        (p) => p.id == id,
        orElse: () => _emptyProduct(id),
      );

  double get _totalPrice => _cart.entries.fold(0.0, (s, e) {
        final p = _findProduct(e.key);
        return s + (p.price * e.value);
      });

  int _cols(double w) => w >= 1200
      ? 5
      : w >= 900
          ? 4
          : w >= 600
              ? 3
              : 2;

  double _extent(double w) => w >= 900 ? 200 : 220;

  @override
  void initState() {
    super.initState();
    _prodSub = FS.productsStream().listen((list) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _storeProducts = list
            .where((p) => p.active)
            .map((p) => MarketProduct(
                  id: p.id,
                  name: p.name,
                  emoji: p.emoji,
                  imageUrl: p.imageUrl,
                  description: p.description,
                  category: p.category,
                  price: p.finalPrice,
                  oldPrice: p.onSale ? p.price : null,
                  store: p.storeName,
                  rating: p.rating,
                  available: p.inStock,
                  isHomologSeed: false,
                ))
            .toList();
      });
    }, onError: (_) {
      if (!mounted) return;
      setState(() => _loadingProducts = false);
      if (!_streamErrorShown) {
        _streamErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Catálogo online indisponível. Exibindo itens locais.'),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _prodSub?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _query = v);
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _cat = 0;
      _query = '';
    });
  }

  void _setQty(String id, int qty) {
    setState(() {
      if (qty <= 0) {
        _cart.remove(id);
      } else {
        _cart[id] = qty;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CarajasAppBar(title: 'Mercado'),
      body: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = _cols(w);
        final extent = _extent(w);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: GradHeader(
              gradient: AppGradients.secondary,
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.storefront_rounded,
                                color: Colors.white, size: 26),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text('Mercado 360',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22)),
                            ),
                          ]),
                          SizedBox(height: 4),
                          Text('Entrega rápida na sua porta',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(children: [
                      _HeaderIconBtn(
                        icon: Icons.storefront_rounded,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.stores),
                      ),
                      const SizedBox(width: 8),
                      Stack(clipBehavior: Clip.none, children: [
                        _HeaderIconBtn(
                          icon: Icons.shopping_cart_rounded,
                          filled: true,
                          onTap: _checkout,
                        ),
                        if (_totalItems > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Text('$_totalItems',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ]),
                    ]),
                  ],
                ),
                const SizedBox(height: 14),
                _MarketSearchField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.delivery_dining_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text('Entrega: 30-60 min  •  Grátis acima de R\$ 50',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: List.generate(_cats.length, (i) {
                    final c = _cats[i];
                    final sel = _cat == i;
                    return GestureDetector(
                      onTap: () => setState(() => _cat = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.secondary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel
                                  ? AppColors.secondary
                                  : AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_catIcon(c['id']!),
                                size: 16,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textDark),
                            const SizedBox(width: 6),
                            Text(c['name']!,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: sel
                                        ? Colors.white
                                        : AppColors.textDark)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          if (_loadingProducts && _storeProducts.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.secondary,
                  backgroundColor: AppColors.border,
                ),
              ),
            ),
          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                emoji: '🔍',
                icon: Icons.search_off_rounded,
                title: 'Nenhum resultado encontrado',
                subtitle: 'Tente limpar os filtros ou buscar outro termo.',
                actionLabel: 'Limpar filtros',
                onAction: _clearFilters,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = filtered[i];
                    return _ProductCard(
                      product: p,
                      qty: _cart[p.id] ?? 0,
                      onAdd: () => _setQty(p.id, 1),
                      onInc: () => _setQty(p.id, (_cart[p.id] ?? 0) + 1),
                      onDec: () => _setQty(p.id, (_cart[p.id] ?? 1) - 1),
                      onTap: () => _openProductDetail(p),
                      onToggleFavorite: () => FS.toggleProductFavorite(p.id),
                    );
                  },
                  childCount: filtered.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: extent,
                ),
              ),
            ),
        ]);
      }),
      bottomNavigationBar: _totalItems > 0
          ? Container(
              decoration: BoxDecoration(color: AppColors.white, boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -4))
              ]),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: ElevatedButton(
                onPressed: _paying ? null : TapGuard.wrap(_checkout),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('$_totalItems',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                    ),
                    const Text('Finalizar pedido',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    Text(PaySvc.fmt(_totalPrice),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _openProductDetail(MarketProduct p) {
    var qty = _cart[p.id] ?? 1;
    if (qty < 1) qty = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: _ProductImage(product: p, height: 180),
                  ),
                ),
                const SizedBox(height: 14),
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(p.store,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textLight)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 16),
                  Text(' ${p.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 12),
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.textHint),
                  Text(' ${p.deliveryEta}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text(PaySvc.fmt(p.price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: AppColors.secondary)),
                  if (p.onSale) ...[
                    const SizedBox(width: 8),
                    Text(PaySvc.fmt(p.oldPrice!),
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 13,
                            color: AppColors.textHint)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('-${p.discountPercent}%',
                          style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ]),
                if (p.description != null &&
                    p.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(p.description!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                          height: 1.4)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    _QtyStepper(
                      qty: qty,
                      onDec: () => setLocal(() {
                        if (qty > 1) qty--;
                      }),
                      onInc: () => setLocal(() => qty++),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !p.available
                            ? null
                            : TapGuard.wrap(() {
                                _setQty(p.id, qty);
                                Navigator.pop(ctx);
                              }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(p.available ? 'Adicionar' : 'Indisponível',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _checkout() {
    if (_cart.isEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SheetHandle(),
            const SizedBox(height: 20),
            SafeSvg(AppAssets.mktCarrinhoVazio,
                width: 150,
                height: 150,
                fallback: const Icon(Icons.shopping_cart_outlined,
                    size: 56, color: AppColors.textHint)),
            const SizedBox(height: 16),
            const Text('Seu carrinho está vazio',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Adicione produtos para continuar',
                style: TextStyle(fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 20),
          ]),
        ),
      );
      return;
    }
    _showCheckoutFlow();
  }

  Future<void> _showCheckoutFlow() async {
    var step = 0;
    final addressCtrl = TextEditingController(text: _checkoutAddress);
    var deliveryIdx = _deliveryMode == 'pickup' ? 1 : 0;

    final uid = AuthService.uid;
    if (uid != null && addressCtrl.text.isEmpty) {
      try {
        final u = await FS.userStream(uid).first;
        if (u?.address != null && u!.address!.trim().isNotEmpty) {
          addressCtrl.text = u.address!;
        }
      } catch (_) {/* offline */}
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget stepBody() {
          switch (step) {
            case 0:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Revise o carrinho',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  ..._cart.entries.map((e) {
                    final p = _findProduct(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                              Text(PaySvc.fmt(p.price * e.value),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        _QtyStepper(
                          qty: e.value,
                          onDec: () {
                            _setQty(e.key, e.value - 1);
                            setLocal(() {});
                            if (_cart.isEmpty) Navigator.pop(ctx);
                          },
                          onInc: () {
                            _setQty(e.key, e.value + 1);
                            setLocal(() {});
                          },
                        ),
                      ]),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(PaySvc.fmt(_totalPrice),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.secondary)),
                    ],
                  ),
                ],
              );
            case 1:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Endereço de entrega',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Rua, número, bairro, referência',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ],
              );
            case 2:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Modo de recebimento',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TogglePills(
                    options: const ['Entrega', 'Retirada'],
                    selected: deliveryIdx,
                    activeColor: AppColors.secondary,
                    onSelect: (i) => setLocal(() => deliveryIdx = i),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    deliveryIdx == 0
                        ? 'Receba em casa em 30-60 min.'
                        : 'Retire no estabelecimento da loja.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              );
            default:
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pagamento',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Total: ${PaySvc.fmt(_totalPrice)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary)),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bolt_rounded,
                        color: AppColors.secondary),
                    title: const Text('PIX',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Confirmação instantânea',
                        style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: TapGuard.wrap(() => _startPayment(
                        ctx, addressCtrl.text, deliveryIdx,
                        pix: true)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.credit_card_rounded,
                        color: AppColors.primary),
                    title: const Text('Cartão de crédito',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Em até 12x',
                        style: TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: TapGuard.wrap(() => _startPayment(
                        ctx, addressCtrl.text, deliveryIdx,
                        pix: false)),
                  ),
                ],
              );
          }
        }

        const labels = ['Carrinho', 'Endereço', 'Entrega', 'Pagamento'];
        return Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              const SizedBox(height: 8),
              Text('Checkout · ${labels[step]}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight)),
              const SizedBox(height: 12),
              stepBody(),
              const SizedBox(height: 16),
              if (step < 3)
                Row(children: [
                  if (step > 0)
                    TextButton(
                      onPressed: () => setLocal(() => step--),
                      child: const Text('Voltar'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: TapGuard.wrap(() {
                      if (step == 2 &&
                          deliveryIdx == 0 &&
                          addressCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Informe o endereço de entrega')),
                        );
                        return;
                      }
                      setLocal(() => step++);
                    }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Continuar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
            ],
          ),
        );
      }),
    );

    addressCtrl.dispose();
  }

  Future<void> _startPayment(
    BuildContext sheetCtx,
    String address,
    int deliveryIdx, {
    required bool pix,
  }) async {
    if (!AuthService.isAuth) {
      Navigator.pop(sheetCtx);
      await Navigator.pushNamed(context, Routes.login, arguments: {
        'returnRoute': Routes.marketplace,
      });
      return;
    }

    _checkoutAddress = address.trim();
    _deliveryMode = deliveryIdx == 1 ? 'pickup' : 'delivery';
    if (_deliveryMode == 'delivery' && _checkoutAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o endereço de entrega')),
      );
      return;
    }

    Navigator.pop(sheetCtx);
    if (!mounted) return;

    Future<void> onPaid() async {
      await _finalizeOrder();
      if (!mounted) return;
      _showOrderConfirmation();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => pix
            ? PixScreen(
                amount: _totalPrice,
                desc: 'Pedido Mercado 360',
                onPaid: onPaid,
              )
            : CardPaymentScreen(
                amount: _totalPrice,
                desc: 'Pedido Mercado 360',
                onPaid: onPaid,
              ),
      ),
    );
  }

  Future<void> _finalizeOrder() async {
    setState(() => _paying = true);
    final items = _cart.entries.map((e) {
      final p = _findProduct(e.key);
      return {
        'productId': e.key,
        'name': p.name,
        'qty': e.value,
        'price': p.price,
        'store': p.store,
      };
    }).toList();

    await FS.createCartOrder({
      'items': items,
      'total': _totalPrice,
      'price': _totalPrice,
      'category': 'marketplace',
      'title': 'Pedido Mercado 360',
      'address': _checkoutAddress,
      'deliveryMode': _deliveryMode,
    });
    _cart.clear();
    if (mounted) setState(() => _paying = false);
  }

  void _showOrderConfirmation() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SheetHandle(),
          const SizedBox(height: 16),
          SafeSvg(AppAssets.mktPedidoRealizado,
              width: 140,
              height: 140,
              fallback: const Icon(Icons.check_circle_rounded,
                  size: 64, color: AppColors.success)),
          const SizedBox(height: 12),
          const Text('Pedido realizado!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Acompanhe o status em Meus pedidos.',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: TapGuard.wrap(() {
                Navigator.pop(context);
                Navigator.pushNamed(context, Routes.myOrders);
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ver pedidos',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _HeaderIconBtn({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: TapGuard.wrap(onTap),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: filled ? AppColors.secondary : Colors.white, size: 22),
        ),
      );
}

class _MarketSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _MarketSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          const Icon(Icons.search_rounded, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Buscar produtos, lojas...',
                hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      );
}

class _ProductCard extends StatelessWidget {
  final MarketProduct product;
  final int qty;
  final VoidCallback onAdd, onInc, onDec, onTap, onToggleFavorite;
  const _ProductCard({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onInc,
    required this.onDec,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: TapGuard.wrap(onTap),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: AppDecorations.card(r: 14),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: _ProductImage(product: p, height: 90),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: StreamBuilder<bool>(
                    stream: FS.isProductFavoriteStream(p.id),
                    builder: (_, snap) {
                      final isFav = snap.data ?? false;
                      return GestureDetector(
                        onTap: TapGuard.wrap(onToggleFavorite),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color:
                                isFav ? AppColors.error : AppColors.textHint,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!p.available)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('Indisponível',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11)),
                    ),
                  ),
                if (p.onSale)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text('-${p.discountPercent}%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                      color: AppColors.textDark)),
              Text(p.store,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textLight)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.warning, size: 12),
                Text(' ${p.rating.toStringAsFixed(1)}',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(p.deliveryEta,
                    style: const TextStyle(
                        fontSize: 9, color: AppColors.textHint)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Text(PaySvc.fmt(p.price),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.secondary)),
                if (p.onSale) ...[
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(PaySvc.fmt(p.oldPrice!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10,
                            color: AppColors.textHint)),
                  ),
                ],
              ]),
              const Spacer(),
              if (!p.available)
                const SizedBox(
                  height: 30,
                  child: Center(
                    child: Text('Sem estoque',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textHint)),
                  ),
                )
              else if (qty == 0)
                SizedBox(
                  width: double.infinity,
                  height: 30,
                  child: ElevatedButton(
                    onPressed: TapGuard.wrap(onAdd),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Adicionar',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                )
              else
                _QtyStepper(
                    qty: qty, onDec: onDec, onInc: onInc, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final MarketProduct product;
  final double height;
  const _ProductImage({required this.product, required this.height});

  Color get _bg {
    final hues = [
      AppColors.secondary.withValues(alpha: 0.12),
      AppColors.primary.withValues(alpha: 0.10),
      AppColors.warning.withValues(alpha: 0.12),
      const Color(0xFFE8F5E9),
    ];
    return hues[product.id.hashCode.abs() % hues.length];
  }

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final initial = product.store.isNotEmpty
        ? product.store[0].toUpperCase()
        : (product.name.isNotEmpty ? product.name[0].toUpperCase() : '?');
    return Container(
      height: height,
      width: double.infinity,
      color: _bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (product.isHomologSeed &&
                product.emoji != null &&
                product.emoji!.isNotEmpty)
              Text(product.emoji!, style: const TextStyle(fontSize: 22))
            else
              Icon(Icons.inventory_2_outlined,
                  size: 28,
                  color: AppColors.textHint.withValues(alpha: 0.7)),
            const SizedBox(height: 4),
            Text(initial,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textDark.withValues(alpha: 0.45))),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec, onInc;
  final bool compact;
  const _QtyStepper({
    required this.qty,
    required this.onDec,
    required this.onInc,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 32.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: TapGuard.wrap(onDec),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: const Icon(Icons.remove, size: 16, color: AppColors.textDark),
        ),
      ),
      SizedBox(
        width: compact ? 28 : 36,
        child: Text('$qty',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: compact ? 13 : 15)),
      ),
      GestureDetector(
        onTap: TapGuard.wrap(onInc),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: const Icon(Icons.add, size: 16, color: Colors.white),
        ),
      ),
    ]);
  }
}
