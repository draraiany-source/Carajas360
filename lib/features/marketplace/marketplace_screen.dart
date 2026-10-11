import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/demo_data.dart';
import '../../core/utils/query_errors.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../checkout/cart.dart';
import '../checkout/cart_service.dart';
import '../checkout/checkout_screen.dart';

class MarketProduct {
  final String id, name, emoji, category, store, storeId;
  final double price, rating;
  MarketProduct(
      {required this.id,
      required this.name,
      required this.emoji,
      required this.category,
      required this.price,
      required this.store,
      this.storeId = 'demo',
      required this.rating});

  /// Linha do carrinho (preço só para exibição; o servidor recalcula).
  CartLine line(int qty) => CartLine(
      productId: id,
      storeId: storeId,
      storeName: store,
      name: name,
      emoji: emoji,
      unitPriceCents: (price * 100).round(),
      qty: qty);
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketState();
}

class _MarketState extends State<MarketplaceScreen> {
  int _cat = 0;
  Cart get _cart => CartService.instance.cart;
  StreamSubscription<List<ProductModel>>? _prodSub;
  Object? _prodError;

  @override
  void initState() {
    super.initState();
    _listenProducts();
    CartService.instance.addListener(_onCart);
  }

  void _onCart() {
    if (mounted) setState(() {});
  }

  /// Catálogo real (Firestore). Falha NÃO é substituída por lojas e
  /// preços de demonstração: a tela mostra o erro com "Tentar novamente".
  void _listenProducts() {
    _prodSub?.cancel();
    setState(() {
      _prodError = null;
      _storeProducts = null;
    });
    _prodSub = FS.productsStream().listen((list) {
      if (!mounted) return;
      setState(() => _storeProducts = list
          .where((p) => p.inStock)
          .map((p) => MarketProduct(
                id: p.id,
                name: p.name,
                emoji: p.emoji ?? '📦',
                category: p.category,
                price: p.finalPrice,
                store: p.storeName,
                storeId: p.storeId,
                rating: p.rating,
              ))
          .toList());
    }, onError: (Object e) {
      if (mounted) setState(() => _prodError = e);
    });
  }

  @override
  void dispose() {
    _prodSub?.cancel();
    CartService.instance.removeListener(_onCart);
    super.dispose();
  }

  static const _cats = [
    {'id': 'all', 'name': 'Todos', 'emoji': '🏪'},
    {'id': 'market', 'name': 'Mercado', 'emoji': '🛒'},
    {'id': 'pharmacy', 'name': 'Farmácia', 'emoji': '💊'},
    {'id': 'pet', 'name': 'Pet Shop', 'emoji': '🐾'},
    {'id': 'materials', 'name': 'Materiais', 'emoji': '🔩'},
    {'id': 'food', 'name': 'Refeições', 'emoji': '🍔'},
    {'id': 'agro', 'name': 'Agro', 'emoji': '🌾'},
    {'id': 'machines', 'name': 'Máquinas', 'emoji': '🚜'},
    {'id': 'tools', 'name': 'Ferramentas', 'emoji': '🧰'},
  ];

  /// Catálogo FICTÍCIO apenas para desenvolvimento local
  /// (DEMO_DATA=true em dev). Nunca aparece em homologação/produção.
  final _demoProducts = [
    MarketProduct(
        id: 'p1',
        name: 'Arroz Tipo 1 5kg',
        emoji: '🌾',
        category: 'market',
        price: 22.90,
        store: 'SuperMarket',
        rating: 4.8),
    MarketProduct(
        id: 'p2',
        name: 'Feijão Carioca 1kg',
        emoji: '🫘',
        category: 'market',
        price: 8.50,
        store: 'SuperMarket',
        rating: 4.6),
    MarketProduct(
        id: 'p3',
        name: 'Óleo de Soja 900ml',
        emoji: '🫙',
        category: 'market',
        price: 6.90,
        store: 'SuperMarket',
        rating: 4.5),
    MarketProduct(
        id: 'p4',
        name: 'Frango Inteiro 2kg',
        emoji: '🍗',
        category: 'market',
        price: 18.90,
        store: 'FrigoFresh',
        rating: 4.7),
    MarketProduct(
        id: 'p6',
        name: 'Dipirona 500mg c/10',
        emoji: '💊',
        category: 'pharmacy',
        price: 3.50,
        store: 'FarmaTop',
        rating: 4.9),
    MarketProduct(
        id: 'p7',
        name: 'Paracetamol 750mg c/10',
        emoji: '💊',
        category: 'pharmacy',
        price: 4.20,
        store: 'FarmaTop',
        rating: 4.8),
    MarketProduct(
        id: 'p8',
        name: 'Ração Golden 1kg',
        emoji: '🐕',
        category: 'pet',
        price: 29.90,
        store: 'PetShopMais',
        rating: 4.9),
    MarketProduct(
        id: 'p9',
        name: 'Areia Higiênica 4kg',
        emoji: '🐱',
        category: 'pet',
        price: 18.50,
        store: 'PetShopMais',
        rating: 4.7),
    MarketProduct(
        id: 'p10',
        name: 'Cimento CP-II 50kg',
        emoji: '🏗️',
        category: 'materials',
        price: 32.90,
        store: 'ConstBela',
        rating: 4.6),
    MarketProduct(
        id: 'p11',
        name: 'Tinta Látex Branca 18L',
        emoji: '🎨',
        category: 'materials',
        price: 89.90,
        store: 'ConstBela',
        rating: 4.8),
    MarketProduct(
        id: 'p12',
        name: 'X-Burger Artesanal',
        emoji: '🍔',
        category: 'food',
        price: 28.90,
        store: 'Burguer 99',
        rating: 4.9),
    MarketProduct(
        id: 'p13',
        name: 'Pizza 8 Fatias',
        emoji: '🍕',
        category: 'food',
        price: 45.90,
        store: 'PizzaHouse',
        rating: 4.7),
    // ── Agro, máquinas e ferramentas (empresas do segmento) ──
    MarketProduct(
        id: 'p14',
        name: 'Semente de Milho 60k',
        emoji: '🌽',
        category: 'agro',
        price: 890.00,
        store: 'AgroCampo',
        rating: 4.8),
    MarketProduct(
        id: 'p15',
        name: 'Adubo NPK 20-05-20 50kg',
        emoji: '🌱',
        category: 'agro',
        price: 189.90,
        store: 'AgroCampo',
        rating: 4.7),
    MarketProduct(
        id: 'p16',
        name: 'Herbicida Seletivo 5L',
        emoji: '🧪',
        category: 'agro',
        price: 349.00,
        store: 'RuralMax',
        rating: 4.6),
    MarketProduct(
        id: 'p17',
        name: 'Arame Farpado 500m',
        emoji: '🚧',
        category: 'agro',
        price: 429.00,
        store: 'RuralMax',
        rating: 4.8),
    MarketProduct(
        id: 'p18',
        name: 'Sal Mineral Bovino 30kg',
        emoji: '🐄',
        category: 'agro',
        price: 98.00,
        store: 'AgroCampo',
        rating: 4.9),
    MarketProduct(
        id: 'p19',
        name: 'Pneu Trator 18.4-34',
        emoji: '🛞',
        category: 'machines',
        price: 3290.00,
        store: 'MáquinaSul',
        rating: 4.7),
    MarketProduct(
        id: 'p20',
        name: 'Bico Pulverizador (kit 20)',
        emoji: '💨',
        category: 'machines',
        price: 279.90,
        store: 'MáquinaSul',
        rating: 4.6),
    MarketProduct(
        id: 'p21',
        name: 'Filtro Óleo Colheitadeira',
        emoji: '🔩',
        category: 'machines',
        price: 156.00,
        store: 'PeçasAgro',
        rating: 4.8),
    MarketProduct(
        id: 'p22',
        name: 'Motobomba 3CV',
        emoji: '⚙️',
        category: 'machines',
        price: 1290.00,
        store: 'PeçasAgro',
        rating: 4.7),
    MarketProduct(
        id: 'p23',
        name: 'Roçadeira Lateral 43cc',
        emoji: '🌿',
        category: 'tools',
        price: 899.00,
        store: 'FerraTop',
        rating: 4.8),
    MarketProduct(
        id: 'p24',
        name: 'Máquina de Solda 200A',
        emoji: '🔥',
        category: 'tools',
        price: 749.00,
        store: 'FerraTop',
        rating: 4.9),
    MarketProduct(
        id: 'p25',
        name: 'Gerador 5,5 kVA',
        emoji: '🔌',
        category: 'tools',
        price: 3490.00,
        store: 'FerraTop',
        rating: 4.7),
  ];

  /// Produtos publicados por lojas no Firestore (null = carregando).
  List<MarketProduct>? _storeProducts;

  List<MarketProduct> get _allProducts => [
        if (DemoData.allow) ..._demoProducts,
        ...?_storeProducts,
      ];

  List<MarketProduct> get _filtered {
    final cat = _cats[_cat]['id'];
    return cat == 'all'
        ? _allProducts
        : _allProducts.where((p) => p.category == cat).toList();
  }

  int get _totalItems => _cart.totalItems;
  double get _totalPrice =>
      _cart.lines.fold<int>(0, (t, l) => t + l.subtotalCents) / 100;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: GradHeader(
                  gradient: AppGradients.secondary,
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🛒 MercadoConecta',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22)),
                                Text('Entrega rápida na sua porta',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12))
                              ]),
                          Row(children: [
                            if (_totalItems > 0)
                              Stack(children: [
                                GestureDetector(
                                    onTap: () => Navigator.pushNamed(
                                        context, Routes.stores),
                                    child: Container(
                                        width: 42,
                                        height: 42,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.25),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Icon(
                                            Icons.storefront_rounded,
                                            color: Colors.white))),
                                GestureDetector(
                                    onTap: _checkout,
                                    child: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: const Icon(
                                            Icons.shopping_cart_rounded,
                                            color: AppColors.secondary))),
                                Positioned(
                                    top: 0,
                                    right: 0,
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
                                                fontWeight: FontWeight.w800)))),
                              ]),
                            if (_totalItems > 0) const SizedBox(width: 8),
                            GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 18))),
                          ]),
                        ]),
                    const SizedBox(height: 14),
                    const AppSearchBar(hint: 'Buscar produtos, lojas...'),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.delivery_dining_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text('Frete e prazo informados pela loja no pedido',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600))
                    ]),
                  ]))),
          SliverToBoxAdapter(
              child: Container(
                  color: AppColors.white,
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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
                                            : AppColors.border)),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(c['emoji']!,
                                          style: const TextStyle(fontSize: 15)),
                                      const SizedBox(width: 6),
                                      Text(c['name']!,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: sel
                                                  ? Colors.white
                                                  : AppColors.textDark))
                                    ])));
                      }))))),
          if (_prodError != null)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyState(
                        emoji: '⚠️',
                        title: 'Catálogo indisponível',
                        subtitle: friendlyQueryError(_prodError),
                        actionLabel: 'Tentar novamente',
                        onAction: _listenProducts)))
          else if (_storeProducts == null)
            const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator())))
          else if (_filtered.isEmpty)
            SliverToBoxAdapter(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: EmptyState(
                        emoji: '🛒',
                        title: 'Nenhum produto disponível',
                        subtitle: 'Ainda não há produtos publicados por lojas '
                            'nesta categoria.',
                        asset: AppAssets.mktSemProdutos)))
          else
          SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((_, i) {
                  final p = _filtered[i];
                  final qty = _cart.qtyOf(p.id);
                  return Container(
                      decoration: AppDecorations.card(r: 16),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(p.emoji,
                                      style: const TextStyle(fontSize: 36)),
                                  StreamBuilder<bool>(
                                    stream: FS.isProductFavoriteStream(p.id),
                                    builder: (_, snap) {
                                      final isFav = snap.data ?? false;
                                      return GestureDetector(
                                        onTap: () async {
                                          await FS.toggleProductFavorite(p.id);
                                        },
                                        child: Icon(
                                            isFav
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            color: isFav
                                                ? AppColors.error
                                                : AppColors.textHint,
                                            size: 20),
                                      );
                                    },
                                  ),
                                ]),
                            const SizedBox(height: 6),
                            Text(p.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.textDark),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(p.store,
                                style: const TextStyle(
                                    fontSize: 10, color: AppColors.textLight)),
                            const Spacer(),
                            Row(children: [
                              const Icon(Icons.star_rounded,
                                  color: AppColors.warning, size: 12),
                              Text(' ${p.rating}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))
                            ]),
                            const SizedBox(height: 6),
                            Text(PaySvc.fmt(p.price),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: AppColors.secondary)),
                            const SizedBox(height: 8),
                            qty == 0
                                ? SizedBox(
                                    width: double.infinity,
                                    height: 32,
                                    child: ElevatedButton(
                                        onPressed: () => CartService.instance
                                            .setQty(p.line(1), 1),
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppColors.secondary,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10))),
                                        child: const Text('+ Adicionar',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white))))
                                : Row(children: [
                                    GestureDetector(
                                        onTap: () => CartService.instance
                                            .setQty(p.line(qty), qty - 1),
                                        child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                                color: AppColors.background,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.remove,
                                                size: 16,
                                                color: AppColors.textDark))),
                                    Expanded(
                                        child: Text('$qty',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15))),
                                    GestureDetector(
                                        onTap: () => CartService.instance
                                            .setQty(p.line(qty), qty + 1),
                                        child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                                color: AppColors.secondary,
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.add,
                                                size: 16,
                                                color: Colors.white))),
                                  ]),
                          ]));
                }, childCount: _filtered.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.65),
              )),
        ]),
        bottomNavigationBar: _totalItems > 0
            ? Container(
                decoration: BoxDecoration(color: AppColors.white, boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ]),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
                child: ElevatedButton(
                    onPressed: _checkout,
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
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text('$_totalItems',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13))),
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
                        ])),
              )
            : null,
      );

  void _checkout() {
    if (_cart.isEmpty) {
      showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SheetHandle(),
                  const SizedBox(height: 20),
                  SvgPicture.asset(AppAssets.mktCarrinhoVazio,
                      width: 150, height: 150),
                  const SizedBox(height: 16),
                  const Text('Seu carrinho está vazio',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Adicione produtos para continuar',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textLight)),
                  const SizedBox(height: 20),
                ]),
              ));
      return;
    }
    // Carrinho por loja → checkout com valores do servidor. Nada é
    // cobrado nem removido do carrinho antes do pedido ser pago.
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }
}
