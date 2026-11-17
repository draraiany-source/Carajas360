import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/demo_data.dart';
import '../../core/utils/app_error.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../support/support_screens.dart';
import '../../core/utils/provider_entry.dart';

enum _ProfileSection {
  personal,
  addresses,
  notifications,
  security,
  privacy,
  help,
  shortcuts,
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _kNotifOrders = 'profile_pref_notif_orders';
  static const _kNotifMessages = 'profile_pref_notif_messages';
  static const _kNotifPromos = 'profile_pref_notif_promos';

  _ProfileSection _selected = _ProfileSection.personal;
  bool _notifOrders = true;
  bool _notifMessages = true;
  bool _notifPromos = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _notifOrders = p.getBool(_kNotifOrders) ?? true;
        _notifMessages = p.getBool(_kNotifMessages) ?? true;
        _notifPromos = p.getBool(_kNotifPromos) ?? false;
      });
    } catch (_) {
      // Mantém os padrões se o armazenamento local não estiver disponível.
    }
  }

  Future<void> _setPref(String key, bool value, void Function() apply) async {
    setState(apply);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(key, value);
    } catch (_) {
      if (mounted) {
        snack(context, 'Não foi possível salvar a preferência neste aparelho.',
            bg: AppColors.error);
      }
    }
  }

  static const _sectionMeta = <_ProfileSection, (IconData, String)>{
    _ProfileSection.personal: (Icons.person_outline_rounded, 'Dados pessoais'),
    _ProfileSection.addresses: (Icons.location_on_outlined, 'Endereços'),
    _ProfileSection.notifications:
        (Icons.notifications_none_rounded, 'Notificações'),
    _ProfileSection.security: (Icons.lock_outline_rounded, 'Segurança'),
    _ProfileSection.privacy:
        (Icons.privacy_tip_outlined, 'Privacidade'),
    _ProfileSection.help: (Icons.help_outline_rounded, 'Central de ajuda'),
    _ProfileSection.shortcuts: (Icons.apps_rounded, 'Atalhos do app'),
  };

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: uid == null
          ? _signedOut(context)
          : StreamBuilder<UserModel?>(
              stream: FS.userStream(uid),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return const EmptyState(
                    emoji: '⚠️',
                    title: 'Não foi possível carregar o perfil',
                    subtitle:
                        'Verifique a conexão ou tente sair e entrar de novo.',
                  );
                }
                return _signedIn(context, snap.data);
              },
            ),
    );
  }

  // ───────────────────────── Chrome compartilhado ─────────────────────────

  List<Widget> _chrome(BuildContext context, {required String subtitle}) => [
        const SizedBox(height: 16),
        BrandBreadcrumb(items: [
          ('Início', () => AppNav.safeBack(context)),
          ('Meu perfil', null),
        ]),
        const SizedBox(height: 12),
        if (HomologCatalog.enabled) ...[
          const BrandDemoNotice(),
          const SizedBox(height: 12),
        ],
        BrandPageHero(
          title: 'Meu perfil e configurações',
          subtitle: subtitle,
          height: 120,
        ),
        const SizedBox(height: 16),
      ];

  Widget _signedIn(BuildContext context, UserModel? user) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return ListView(
      children: [
        BrandContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._chrome(context,
                  subtitle:
                      'Gerencie seus dados, notificações, segurança e privacidade.'),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 300, child: _sidebar(context, user)),
                    const SizedBox(width: 20),
                    Expanded(child: _sectionContent(context, user, _selected)),
                  ],
                )
              else
                _mobileBody(context, user),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Sidebar (wide) ─────────────────────────

  Widget _profileHeader(BuildContext context, UserModel? user) {
    final name = user?.name.isNotEmpty == true ? user!.name : 'Usuário';
    final xp = user?.xp ?? 0;
    return Column(children: [
      Stack(children: [
        AppAvatar(
            url: user?.photoUrl,
            name: user?.name ?? '?',
            size: 80,
            bg: AppColors.warning,
            r: 24),
        Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => _pickAndUploadPhoto(context),
              child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                      color: Brand.green, shape: BoxShape.circle),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 16, color: Colors.white)),
            )),
      ]),
      const SizedBox(height: 12),
      Text(name,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Brand.ink(context),
              fontWeight: FontWeight.w800,
              fontSize: 18)),
      if (user?.email.isNotEmpty == true) ...[
        const SizedBox(height: 2),
        Text(user!.email,
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.inkMuted(context), fontSize: 12.5)),
      ],
      const SizedBox(height: 8),
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
              color: Brand.greenLight,
              borderRadius: BorderRadius.circular(20)),
          child: Text('${user?.levelName ?? '⭐ Iniciante'} · $xp XP',
              style: const TextStyle(
                  color: Brand.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 12))),
    ]);
  }

  Widget _sidebar(BuildContext context, UserModel? user) {
    const order = [
      _ProfileSection.personal,
      _ProfileSection.addresses,
      _ProfileSection.notifications,
      _ProfileSection.security,
      _ProfileSection.privacy,
      _ProfileSection.help,
      _ProfileSection.shortcuts,
    ];
    return BrandSoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _profileHeader(context, user),
        const SizedBox(height: 14),
        Divider(color: Brand.line(context), height: 1),
        const SizedBox(height: 8),
        for (final s in order)
          _navTile(
            context,
            icon: _sectionMeta[s]!.$1,
            label: _sectionMeta[s]!.$2,
            selected: _selected == s,
            onTap: () => setState(() => _selected = s),
          ),
        Divider(color: Brand.line(context), height: 16),
        _navTile(
          context,
          icon: Icons.logout_rounded,
          label: 'Sair',
          selected: false,
          danger: true,
          onTap: () => _logout(context),
        ),
      ]),
    );
  }

  Widget _navTile(BuildContext context,
      {required IconData icon,
      required String label,
      required bool selected,
      required VoidCallback onTap,
      bool danger = false}) {
    final color = danger
        ? AppColors.error
        : selected
            ? Brand.green
            : Brand.ink(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? Brand.greenLight : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: color))),
              if (!danger)
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Brand.inkMuted(context)),
            ]),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Mobile ─────────────────────────

  Widget _mobileBody(BuildContext context, UserModel? user) {
    const order = [
      _ProfileSection.personal,
      _ProfileSection.addresses,
      _ProfileSection.notifications,
      _ProfileSection.security,
      _ProfileSection.privacy,
      _ProfileSection.help,
      _ProfileSection.shortcuts,
    ];
    return Column(children: [
      BrandSoftCard(
          padding: const EdgeInsets.all(18),
          child: _profileHeader(context, user)),
      for (final s in order) ...[
        const SizedBox(height: 14),
        _sectionContent(context, user, s),
      ],
      const SizedBox(height: 18),
      BrandPrimaryButton(
        label: 'Sair da conta',
        icon: Icons.logout_rounded,
        outlined: true,
        onPressed: () => _logout(context),
      ),
    ]);
  }

  // ───────────────────────── Conteúdo das seções ─────────────────────────

  Widget _sectionContent(
      BuildContext context, UserModel? user, _ProfileSection s) {
    switch (s) {
      case _ProfileSection.personal:
        return _personalCard(context, user);
      case _ProfileSection.addresses:
        return _addressCard(context, user);
      case _ProfileSection.notifications:
        return _notificationsCard(context);
      case _ProfileSection.security:
        return _securityCard(context, user);
      case _ProfileSection.privacy:
        return _privacyCard(context);
      case _ProfileSection.help:
        return _helpCard(context);
      case _ProfileSection.shortcuts:
        return _shortcuts(context, user);
    }
  }

  Widget _cardTitle(BuildContext context, String title, [String? subtitle]) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Brand.inkMuted(context))),
          ],
        ]),
      );

  Widget _infoRow(BuildContext context, String label, String? value) {
    final has = value != null && value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Brand.inkMuted(context)))),
        Expanded(
            child: Text(has ? value.trim() : 'Não informado',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: has ? FontWeight.w700 : FontWeight.w500,
                    color: has ? Brand.ink(context) : Brand.inkMuted(context)))),
      ]),
    );
  }

  Widget _personalCard(BuildContext context, UserModel? user) {
    final cityState = [
      if (user?.city?.trim().isNotEmpty == true) user!.city!.trim(),
      if (user?.state?.trim().isNotEmpty == true) user!.state!.trim(),
    ].join(' / ');
    return BrandSoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(context, 'Dados pessoais',
            'Informações da sua conta. E-mail e telefone não podem ser alterados por aqui.'),
        _infoRow(context, 'Nome', user?.name),
        Divider(color: Brand.line(context), height: 1),
        _infoRow(context, 'E-mail', user?.email),
        Divider(color: Brand.line(context), height: 1),
        _infoRow(context, 'Telefone', user?.phone),
        Divider(color: Brand.line(context), height: 1),
        _infoRow(context, 'Cidade', cityState),
        Divider(color: Brand.line(context), height: 1),
        _infoRow(context, 'Endereço', user?.address),
        const SizedBox(height: 16),
        BrandPrimaryButton(
          label: 'Editar nome e cidade',
          icon: Icons.edit_outlined,
          expanded: false,
          onPressed: () => _editProfile(context, user),
        ),
      ]),
    );
  }

  Widget _addressCard(BuildContext context, UserModel? user) {
    final hasAddress = user?.address?.trim().isNotEmpty == true;
    final cityState = [
      if (user?.city?.trim().isNotEmpty == true) user!.city!.trim(),
      if (user?.state?.trim().isNotEmpty == true) user!.state!.trim(),
    ].join(' / ');
    return BrandSoftCard(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _cardTitle(context, 'Endereços',
            'Usado nas solicitações de serviço e no GPS. Não é público.'),
        if (hasAddress) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Brand.greenLight.withValues(
                    alpha: Brand.isDark(context) ? 0.12 : 1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Brand.line(context))),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, color: Brand.green),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(user!.address!.trim(),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Brand.ink(context))),
                    if (cityState.isNotEmpty)
                      Text(cityState,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Brand.inkMuted(context))),
                  ])),
            ]),
          ),
        ] else
          Text('Nenhum endereço cadastrado.',
              style: TextStyle(color: Brand.inkMuted(context), fontSize: 13.5)),
        const SizedBox(height: 16),
        BrandPrimaryButton(
          label: hasAddress ? 'Editar endereço' : 'Cadastrar endereço',
          icon: Icons.add_location_alt_outlined,
          expanded: false,
          onPressed: () => _editAddress(context, user),
        ),
      ]),
    );
  }

  Widget _prefSwitch(BuildContext context, String title, String sub,
          bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Brand.green,
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Brand.ink(context))),
        subtitle: Text(sub,
            style: TextStyle(fontSize: 12, color: Brand.inkMuted(context))),
        value: value,
        onChanged: onChanged,
      );

  Widget _notificationsCard(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardTitle(context, 'Notificações',
              'Preferências salvas apenas neste aparelho (não sincronizadas com sua conta).'),
          _prefSwitch(
              context,
              'Pedidos e serviços',
              'Avisos sobre andamento de pedidos',
              _notifOrders,
              (v) => _setPref(_kNotifOrders, v, () => _notifOrders = v)),
          Divider(color: Brand.line(context), height: 1),
          _prefSwitch(
              context,
              'Mensagens',
              'Avisos de novas mensagens no chat',
              _notifMessages,
              (v) => _setPref(_kNotifMessages, v, () => _notifMessages = v)),
          Divider(color: Brand.line(context), height: 1),
          _prefSwitch(
              context,
              'Promoções e novidades',
              'Cupons e ofertas do Carajás 360',
              _notifPromos,
              (v) => _setPref(_kNotifPromos, v, () => _notifPromos = v)),
          const SizedBox(height: 16),
          BrandPrimaryButton(
            label: 'Ver minhas notificações',
            icon: Icons.notifications_none_rounded,
            expanded: false,
            outlined: true,
            onPressed: () => Navigator.pushNamed(context, Routes.notifications),
          ),
        ]),
      );

  Widget _securityCard(BuildContext context, UserModel? user) =>
      BrandSoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardTitle(context, 'Segurança', 'Proteja o acesso à sua conta.'),
          Text('Senha',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Brand.ink(context))),
          const SizedBox(height: 4),
          Text('Enviaremos um link de redefinição para o seu e-mail.',
              style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context))),
          const SizedBox(height: 10),
          BrandPrimaryButton(
            label: 'Alterar senha',
            icon: Icons.lock_reset_rounded,
            expanded: false,
            onPressed: () => _changePassword(context, user),
          ),
          const SizedBox(height: 18),
          Divider(color: Brand.line(context), height: 1),
          const SizedBox(height: 18),
          Text('Verificação em duas etapas',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Brand.ink(context))),
          const SizedBox(height: 4),
          // 2FA não está implementado: sem botão de configurar.
          Text('Ainda não disponível no Carajás 360.',
              style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context))),
        ]),
      );

  Widget _privacyCard(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: _cardTitle(context, 'Privacidade',
                      'Documentos legais e seus direitos (LGPD).'))),
          _item(
              context,
              '📄',
              'Termos de Uso',
              '',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LegalScreen(isPrivacy: false)))),
          _item(
              context,
              '🔏',
              'Política de Privacidade',
              '',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LegalScreen(isPrivacy: true)))),
          _item(context, '📦', 'Exportar meus dados', 'LGPD · portabilidade',
              () => _exportMyData(context)),
          _item(context, '🗑️', 'Excluir minha conta', 'LGPD · irreversível',
              () => _deleteMyAccount(context)),
        ]),
      );

  Widget _helpCard(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardTitle(context, 'Central de ajuda',
              'Dúvidas, suporte e contato com a equipe Carajás 360.'),
          BrandPrimaryButton(
            label: 'Abrir central de ajuda',
            icon: Icons.help_outline_rounded,
            expanded: false,
            onPressed: () => Navigator.pushNamed(context, Routes.support),
          ),
        ]),
      );

  /// Demais atalhos que já existiam no perfil (carteira, reservas, etc.).
  Widget _shortcuts(BuildContext context, UserModel? user) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('Financeiro', [
          _item(context, '👜', 'Minha carteira', 'Ver saldo disponível',
              () => Navigator.pushNamed(context, Routes.wallet)),
          _item(context, '🔑', 'Minhas reservas',
              'Locações de veículos e máquinas',
              () => Navigator.pushNamed(context, Routes.bookings)),
          _item(context, '📋', 'Meu histórico', 'Pedidos e serviços',
              () => Navigator.pushNamed(context, Routes.myOrders)),
          _item(context, '⭐', 'Favoritos', 'Profissionais salvos',
              () => Navigator.pushNamed(context, Routes.favorites)),
          _item(context, '🎟️', 'Cupons', 'Ver cupons disponíveis',
              () => Navigator.pushNamed(context, Routes.coupons)),
        ]),
        _section('Serviços', [
          _item(context, '✨', 'Carajás 360 IA',
              'Assistente inteligente do marketplace',
              () => Navigator.pushNamed(context, Routes.aiAssistant)),
          _item(context, '⚡', 'Resolve Carajás',
              'Pedir orçamento e ver propostas',
              () => Navigator.pushNamed(context, Routes.resolve)),
          _item(context, '📋', 'Meus Resolve', 'Solicitações abertas',
              () => Navigator.pushNamed(context, Routes.myResolve)),
          _item(context, '🏥', 'Saúde', 'Consultas e profissionais de saúde',
              () => Navigator.pushNamed(context, Routes.health)),
          _item(context, '📦', 'Entregas', 'Rastrear pedidos',
              () => Navigator.pushNamed(context, Routes.delivery)),
          _item(context, '🏆', 'Conquistas', 'Ver suas medalhas',
              () => _showBadges(context)),
          _item(context, '💎', 'Planos e assinaturas',
              'Conheça os planos do Carajás 360',
              () => Navigator.pushNamed(context, Routes.carajasPro)),
          _item(context, '📣', 'Divulgue seu serviço',
              'Cadastre-se como profissional',
              () => openProviderEntry(context)),
        ]),
        if (user?.type == UserType.provider)
          _section('Área do Prestador', [
            _item(context, '🔧', 'Meus Atendimentos',
                'Pedidos recebidos e agenda',
                () => Navigator.pushNamed(context, Routes.providerHome)),
            _item(context, '⚡', 'Oportunidades Resolve',
                'Enviar propostas a pedidos abertos',
                () => Navigator.pushNamed(
                    context, Routes.resolveOpportunities)),
          ]),
        if (user?.type == UserType.company)
          _section('Empresa', [
            _item(context, '🏢', 'Painel da Empresa', 'Equipe, leads e plano',
                () => Navigator.pushNamed(context, Routes.companyProfile)),
          ])
        else if (user?.type != UserType.admin)
          _section('Para empresas', [
            _item(context, '🏢', 'Cadastrar minha empresa',
                'Gerencie equipe e leads',
                () => Navigator.pushNamed(context, Routes.companyProfile)),
          ]),
        if (user?.type == UserType.admin)
          _section('Administração', [
            _item(context, '⚙️', 'Painel Admin',
                'Usuários, validação, financeiro',
                () => Navigator.pushNamed(context, Routes.admin)),
          ]),
        _section('App', [
          _item(
              context,
              '🎁',
              'Indique e ganhe',
              'Convide amigos e ganhe cashback',
              () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ReferralScreen()))),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) => _item(
                context,
                '🌗',
                'Tema',
                _themeLabel(mode),
                () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ThemeSettingsScreen()))),
          ),
          _item(context, 'ℹ️', 'Sobre o app', AppInfo.version,
              () => _showAbout(context)),
        ]),
      ]);

  // ───────────────────────── Deslogado ─────────────────────────

  Widget _signedOut(BuildContext context) => ListView(
        children: [
          BrandContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._chrome(context,
                    subtitle:
                        'Entre na sua conta para gerenciar seus dados e configurações.'),
                const EmptyState(
                  emoji: '👤',
                  title: 'Entre na sua conta',
                  subtitle: 'Acompanhe pedidos, mensagens e favoritos.',
                ),
                Center(
                  child: BrandPrimaryButton(
                    label: 'Entrar ou criar conta',
                    expanded: false,
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.login),
                  ),
                ),
                const SizedBox(height: 16),
                _section('Carajás 360', [
                  _item(context, '⭐', 'Favoritos', 'Profissionais salvos',
                      () => Navigator.pushNamed(context, Routes.favorites)),
                  _item(context, '💎', 'Planos e assinaturas',
                      'Conheça os planos do Carajás 360',
                      () => Navigator.pushNamed(context, Routes.carajasPro)),
                  _item(context, '📣', 'Divulgue seu serviço',
                      'Cadastre-se como profissional',
                      () => openProviderEntry(context)),
                  _item(context, '❓', 'Ajuda e suporte', 'Central de ajuda',
                      () => Navigator.pushNamed(context, Routes.support)),
                ]),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      );

  // ───────────────────────── Ações ─────────────────────────

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  Future<void> _exportMyData(BuildContext context) async {
    try {
      snack(context, 'Preparando exportação…');
      final data = await FS.exportMyData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Share.share(json, subject: 'Meus dados — ${AppInfo.name}');
      if (context.mounted) {
        snack(context, 'Dados exportados. Escolha onde salvar/compartilhar.',
            bg: AppColors.secondary);
      }
    } catch (e) {
      if (context.mounted) {
        snack(
            context,
            AppError.userMessage(e,
                message: 'Não foi possível exportar os dados.'),
            bg: AppColors.error);
      }
    }
  }

  Future<void> _deleteMyAccount(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text('Seu perfil e dados pessoais serão anonimizados. '
            'Pedidos, pagamentos, contratos e registros fiscais são mantidos '
            'pelo prazo legal, sem identificação. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AuthService.deleteAccount();
      if (context.mounted) {
        snack(context, 'Conta excluída e dados pessoais anonimizados.',
            bg: AppColors.secondary);
        Navigator.pushReplacementNamed(context, Routes.login);
      }
    } on AuthFailure catch (e) {
      if (context.mounted) snack(context, e.message, bg: AppColors.error);
    } catch (e) {
      if (context.mounted) {
        snack(
            context,
            AppError.userMessage(e,
                message: 'Não foi possível excluir a conta.'),
            bg: AppColors.error);
      }
    }
  }

  Widget _section(String title, List<Widget> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Brand.inkMuted(context)))),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BrandSoftCard(
              padding: EdgeInsets.zero, child: Column(children: items)),
        ),
      ]);

  Widget _item(BuildContext ctx, String icon, String title, String sub,
          VoidCallback onTap) =>
      ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 20)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Brand.ink(ctx))),
        subtitle: sub.isNotEmpty
            ? Text(sub,
                style: TextStyle(fontSize: 11, color: Brand.inkMuted(ctx)))
            : null,
        trailing: Icon(Icons.chevron_right_rounded,
            color: Brand.inkMuted(ctx)),
        onTap: onTap,
      );

  void _editAddress(BuildContext ctx, UserModel? user) {
    final addressCtrl = TextEditingController(text: user?.address ?? '');
    final cityCtrl = TextEditingController(text: user?.city ?? '');
    final stateCtrl = TextEditingController(text: user?.state ?? '');
    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        builder: (_) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                const SheetHandle(),
                const SizedBox(height: 16),
                const Text('Seu endereço',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Usado nas solicitações de serviço e no GPS. Não é público.',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.textLight)),
                const SizedBox(height: 16),
                TextFormField(
                    controller: addressCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'Rua, número, bairro',
                        prefixIcon: Icon(Icons.home_outlined))),
                const SizedBox(height: 10),
                TextFormField(
                    controller: cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        hintText: 'Cidade',
                        prefixIcon: Icon(Icons.location_city_outlined))),
                const SizedBox(height: 10),
                TextFormField(
                    controller: stateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 2,
                    decoration: const InputDecoration(
                        hintText: 'UF',
                        prefixIcon: Icon(Icons.map_outlined),
                        counterText: '')),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () async {
                          final street = addressCtrl.text.trim();
                          if (street.isEmpty) {
                            snack(ctx, 'Informe a rua e o número.',
                                bg: AppColors.warning);
                            return;
                          }
                          await FS.updateUser({
                            'address': street,
                            'city': cityCtrl.text.trim(),
                            'state': stateCtrl.text.trim().toUpperCase(),
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            snack(ctx, '✅ Endereço salvo',
                                bg: AppColors.secondary);
                          }
                        },
                        child: const Text('Salvar endereço'))),
              ]),
            ));
  }

  void _editProfile(BuildContext ctx, UserModel? user) {
    final nameCtrl = TextEditingController(text: user?.name);
    final cityCtrl = TextEditingController(text: user?.city);
    showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        builder: (_) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 8),
                const SheetHandle(),
                const SizedBox(height: 16),
                const Text('Editar perfil',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 10),
                TextFormField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Cidade',
                        prefixIcon: Icon(Icons.location_city_outlined))),
                const SizedBox(height: 14),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () async {
                          await FS.updateUser(
                              {'name': nameCtrl.text, 'city': cityCtrl.text});
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            snack(ctx, '✅ Perfil atualizado!',
                                bg: AppColors.secondary);
                          }
                        },
                        child: const Text('Salvar alterações'))),
              ]),
            ));
  }

  void _showBadges(BuildContext ctx) => showModalBottomSheet(
      context: ctx,
      builder: (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SheetHandle(),
              const SizedBox(height: 16),
              const Text('🏆 Suas Conquistas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final b in [
                  ['⭐', 'Iniciante', '0 XP'],
                  ['🥉', 'Bronze', '500 XP'],
                  ['🥈', 'Prata', '1000 XP'],
                  ['🥇', 'Ouro', '2000 XP'],
                  ['💎', 'Diamante', '4000 XP']
                ])
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: AppDecorations.card(r: 16),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(b[0], style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(b[1],
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                        Text(b[2],
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.textLight))
                      ])),
              ]),
            ]),
          ));

  void _showAbout(BuildContext ctx) => showAboutDialog(
        context: ctx,
        applicationName: AppInfo.name,
        applicationVersion: AppInfo.version,
        applicationIcon:
            SafeSvg(AppAssets.logoMark, width: 48, height: 48),
        children: [
          const SizedBox(height: 12),
          const Text(AppInfo.slogan,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMedium, height: 1.5)),
          const SizedBox(height: 12),
          const Text(
              'Um marketplace completo de serviços, saúde, entregas e mercado, tudo em um só app.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        ],
      );

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;
    if (context.mounted)
      snack(context, 'Enviando foto...', bg: AppColors.primary);
    final url = await FS.uploadUserPhoto(await picked.readAsBytes(), picked.name);
    if (context.mounted) {
      snack(
          context,
          url != null
              ? '✅ Foto atualizada!'
              : 'Falha ao enviar foto. Tente novamente.',
          bg: url != null ? AppColors.secondary : AppColors.error);
    }
  }

  void _changePassword(BuildContext context, UserModel? user) {
    if (user == null || user.email.isEmpty) {
      snack(context, 'E-mail não disponível para redefinição.');
      return;
    }
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Alterar senha'),
              content: Text(
                  'Enviaremos um link de redefinição de senha para ${user.email}. Deseja continuar?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await AuthService.resetPassword(user.email);
                      if (context.mounted)
                        snack(context, '✅ Link enviado para seu e-mail!',
                            bg: AppColors.secondary);
                    },
                    child: const Text('Enviar')),
              ],
            ));
  }

  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Escuro',
        ThemeMode.system => 'Automático (sistema)',
      };

}

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CarajasAppBar(title: 'Tema'),
        body: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.instance.mode,
          builder: (context, current, _) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _themeOption(context, current, ThemeMode.light,
                  Icons.light_mode_outlined, 'Claro'),
              _themeOption(context, current, ThemeMode.dark,
                  Icons.dark_mode_outlined, 'Escuro'),
              _themeOption(context, current, ThemeMode.system,
                  Icons.brightness_auto_outlined, 'Automático (sistema)'),
            ],
          ),
        ),
      );

  Widget _themeOption(BuildContext context, ThemeMode current, ThemeMode m,
      IconData icon, String label) {
    final selected = current == m;
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
          : null,
      onTap: () => ThemeController.instance.set(m),
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final _demo = [
    NotifModel(
        id: '1',
        userId: 'u',
        title: '🔧 Profissional confirmado!',
        body: 'Carlos Silva aceitou seu pedido de serviço.',
        type: 'order',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5))),
    NotifModel(
        id: '2',
        userId: 'u',
        title: '💳 Pagamento confirmado',
        body: 'PIX de R\$ 120,00 recebido com sucesso.',
        type: 'payment',
        read: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    NotifModel(
        id: '3',
        userId: 'u',
        title: '💬 Nova mensagem',
        body: 'Carlos: "Estarei aí em 30 minutos!"',
        type: 'chat',
        read: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    NotifModel(
        id: '4',
        userId: 'u',
        title: '⭐ Avalie seu serviço',
        body: 'Como foi o serviço de Ana Souza?',
        type: 'review',
        read: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Notificações'),
      body: uid == null
          ? EmptyState(
              emoji: '🔔',
              title: 'Faça login',
              subtitle: 'Entre na conta para ver suas notificações.',
              actionLabel: 'Entrar',
              onAction: () => Navigator.pushNamed(context, Routes.login),
            )
          : StreamBuilder<List<NotifModel>>(
        stream: FS.notifStream(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const EmptyState(
                emoji: '⚠️',
                title: 'Falha ao carregar',
                subtitle: 'Verifique a conexão e tente novamente.');
          }
          final notifs = DemoData.orEmpty(snap.data, _demo);
          if (notifs.isEmpty)
            return const EmptyState(
                emoji: '🔔',
                title: 'Sem notificações',
                subtitle: 'Você está em dia!');
          return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = notifs[i];
                return GestureDetector(
                    onTap: () {
                      if (!n.read && uid != null) FS.markNotifRead(n.id);
                    },
                    child: Container(
                      decoration: AppDecorations.card(
                          r: 14,
                          color: n.read
                              ? null
                              : AppColors.primary.withValues(alpha: 0.05)),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: _nColor(n.type).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.center,
                                child: Text(n.icon,
                                    style: const TextStyle(fontSize: 22))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(children: [
                                    Expanded(
                                        child: Text(n.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: AppColors.textDark))),
                                    if (!n.read)
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle))
                                  ]),
                                  const SizedBox(height: 3),
                                  Text(n.body,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMedium,
                                          height: 1.4)),
                                  const SizedBox(height: 4),
                                  Text(fmtDate(n.createdAt),
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textLight)),
                                ])),
                          ]),
                    ));
              });
        },
      ),
    );
  }

  Color _nColor(String type) {
    switch (type) {
      case 'payment':
        return AppColors.secondary;
      case 'chat':
        return AppColors.primary;
      case 'review':
        return AppColors.warning;
      case 'promo':
        return AppColors.purple;
      default:
        return AppColors.primary;
    }
  }
}

class ReviewScreen extends StatefulWidget {
  final String orderId;
  final String? providerId, providerName;
  const ReviewScreen(
      {super.key, required this.orderId, this.providerId, this.providerName});
  @override
  State<ReviewScreen> createState() => _ReviewState();
}

class _ReviewState extends State<ReviewScreen> {
  int _stars = 5;
  final _ctrl = TextEditingController();
  final _tags = <String>{};
  bool _loading = false;
  static const _tagOptions = [
    'Pontual',
    'Profissional',
    'Ótimo serviço',
    'Comunicativo',
    'Cuidadoso',
    'Organizado',
    'Eficiente',
    'Recomendo!'
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CarajasAppBar(title: 'Avaliar serviço'),
        body: LoadingOverlay(
            loading: _loading,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const Text('Como foi o serviço?',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark),
                      textAlign: TextAlign.center),
                  if (widget.providerName != null) ...[
                    const SizedBox(height: 8),
                    Text('Profissional: ${widget.providerName}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 14))
                  ],
                  const SizedBox(height: 24),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          5,
                          (i) => GestureDetector(
                              onTap: () => setState(() => _stars = i + 1),
                              child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                      i < _stars
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                      size: 44,
                                      color: i < _stars
                                          ? AppColors.warning
                                          : AppColors.border))))),
                  const SizedBox(height: 8),
                  Text(_starsLabel(_stars),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  const SizedBox(height: 20),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('O que você mais gostou?',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14))),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tagOptions.map((t) {
                        final sel = _tags.contains(t);
                        return GestureDetector(
                            onTap: () => setState(
                                () => sel ? _tags.remove(t) : _tags.add(t)),
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.primary
                                            : AppColors.border)),
                                child: Text(t,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.textDark))));
                      }).toList()),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: _ctrl,
                      maxLines: 4,
                      maxLength: 300,
                      decoration: const InputDecoration(
                          hintText: 'Conte sobre sua experiência...',
                          alignLabelWithHint: true)),
                  const SizedBox(height: 24),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: const Text('Enviar avaliação ⭐',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16)))),
                ]))),
      );

  Future<void> _submit() async {
    setState(() => _loading = true);
    final user = await FS.getUser();
    final review = ReviewModel(
        id: '',
        orderId: widget.orderId,
        clientId: AuthService.uid ?? '',
        clientName: user?.name ?? 'Anônimo',
        clientPhoto: user?.photoUrl,
        providerId: widget.providerId,
        stars: _stars,
        comment: _ctrl.text,
        tags: _tags.toList(),
        createdAt: DateTime.now());
    await FS.saveReview(review);
    if (mounted) {
      Navigator.pop(context);
      snack(context, '✅ Avaliação enviada! Obrigado!', bg: AppColors.secondary);
    }
  }

  String _starsLabel(int s) {
    switch (s) {
      case 1:
        return '😞 Muito ruim';
      case 2:
        return '😐 Ruim';
      case 3:
        return '😊 Regular';
      case 4:
        return '😄 Bom';
      default:
        return '🤩 Excelente!';
    }
  }
}

// AdminScreen foi movida para features/admin/admin_screen.dart (painel completo)
