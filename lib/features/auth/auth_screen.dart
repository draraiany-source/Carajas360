import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/span_ds.dart';
import '../../core/constants/app_constants.dart';
import '../checkout/cart_service.dart';
import '../checkout/checkout_screen.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/auth_validators.dart';
import '../../core/utils/platform_info.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../support/support_screens.dart';
import '../../core/catalog/catalog_widgets.dart';

class SplashScreen extends StatefulWidget {
  final bool firebaseReady;
  const SplashScreen({super.key, this.firebaseReady = false});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    if (!widget.firebaseReady) {
      Navigator.pushReplacementNamed(context, Routes.onboarding);
      return;
    }
    Navigator.pushReplacementNamed(
        context, AuthService.isAuth ? Routes.main : Routes.onboarding);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.splash),
          child: Stack(children: [
            Positioned.fill(
                child: SvgPicture.asset(AppAssets.bgSplash, fit: BoxFit.cover)),
            SafeArea(
                child: FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                        scale: _scale,
                        child: Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            SvgPicture.asset(AppAssets.logoMarkWhite,
                                width: 104, height: 104),
                            const SizedBox(height: 22),
                            Text(AppInfo.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(AppInfo.slogan,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                        fontSize: 14,
                                        height: 1.55))),
                            const SizedBox(height: 40),
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                // Só módulos já disponíveis (sem "em breve").
                                children: [
                                  'Serviços',
                                  'Resolve',
                                  'Saúde',
                                ]
                                    .map((t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: Colors.white
                                                    .withValues(alpha: 0.18))),
                                        child: Text(t,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600))))
                                    .toList()),
                            const SizedBox(height: 56),
                            const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                    color: Colors.white54, strokeWidth: 2)),
                            const SizedBox(height: 20),
                            if (!widget.firebaseReady)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: const Text(
                                      '⚠️ Serviço indisponível',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11))),
                          ]),
                        )))),
          ]),
        ),
      );
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardState();
}

class _OnboardState extends State<OnboardingScreen> {
  final _page = PageController();
  int _cur = 0;

  static const _slides = [
    {
      'img': 0,
      'title': 'Dezenas de serviços na região',
      'desc':
          'Encontre eletricistas, encanadores, diaristas e outros profissionais da região.',
      'color': AppColors.primary
    },
    {
      'img': 1,
      'title': 'Solicite com facilidade',
      'desc':
          'Descreva o que precisa e receba orçamentos de profissionais qualificados.',
      'color': AppColors.health
    },
    {
      'img': 2,
      'title': 'Acompanhe seu pedido',
      'desc': 'Veja o status do pedido e converse com o profissional pelo chat.',
      'color': AppColors.delivery
    },
    {
      'img': 3,
      'title': 'Pagamento protegido',
      'desc':
          'PIX, cartão e carteira digital. Dinheiro liberado só após o serviço concluído.',
      'color': AppColors.secondary
    },
    {
      'img': 4,
      'title': 'Avalie o atendimento',
      'desc': 'Dê sua nota e ajude a manter a qualidade da comunidade.',
      'color': AppColors.purple
    },
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          PageView.builder(
            controller: _page,
            onPageChanged: (i) => setState(() => _cur = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) {
              final s = _slides[i];
              return Container(
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                  (s['color'] as Color),
                  (s['color'] as Color).withOpacity(0.7)
                ], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 40),
                              SvgPicture.asset(
                                  AppAssets.onboarding[s['img'] as int],
                                  height: 240,
                                  fit: BoxFit.contain),
                              const SizedBox(height: 40),
                              Text(s['title'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2)),
                              const SizedBox(height: 16),
                              Text(s['desc'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 15,
                                      height: 1.6)),
                            ]))),
              );
            },
          ),
          Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _cur == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color:
                                    _cur == i ? Colors.white : Colors.white38,
                                borderRadius: BorderRadius.circular(4))))),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _cur < _slides.length - 1
                          ? _page.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut)
                          : Navigator.pushReplacementNamed(
                              context, Routes.login),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      child: Text(
                          _cur < _slides.length - 1
                              ? 'Próximo →'
                              : 'Começar agora!',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                    )),
                if (_cur < _slides.length - 1)
                  TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, Routes.login),
                      child: Text('Pular',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.7)))),
                // Catálogo público: visitante navega sem conta; ações
                // protegidas pedem login (loginAndResume).
                TextButton(
                    key: const Key('explore-guest'),
                    onPressed: () {
                      // Visitante: descarta retomada pendente antiga.
                      AuthResume.clear();
                      Navigator.pushNamedAndRemoveUntil(
                          context, Routes.main, (_) => false);
                    },
                    child: const Text('Explorar sem entrar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700))),
              ])),
        ]),
      );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false, _otpSent = false, _passVis = false;
  String _verId = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _err(String m) {
    // Pode ser chamado após awaits: tela já fechada.
    if (!mounted) return;
    setState(() => _loading = false);
    snack(context, m, bg: AppColors.error);
  }

  Future<void> _sendOtp() async {
    final p = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (p.length < 10) {
      _err('Digite um número válido');
      return;
    }
    setState(() => _loading = true);
    await AuthService.verifyPhone(
        phone: p,
        onSent: (id, _) {
          if (!mounted) return;
          setState(() {
            _verId = id;
            _otpSent = true;
            _loading = false;
          });
        },
        onAutoVerified: (cred) {
          if (!mounted || cred.user == null) return;
          setState(() => _loading = true);
          _afterLogin(cred.user!.uid,
                  cred.additionalUserInfo?.isNewUser ?? false)
              .catchError((_) => _err('Não foi possível entrar.'));
        },
        onError: (m) {
          if (mounted) _err(m);
        });
  }

  Future<void> _confirmOtp() async {
    if (_otpCtrl.text.length < 6) {
      _err('Digite o código de 6 dígitos');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await AuthService.confirmOtp(_verId, _otpCtrl.text);
      if (cred != null) {
        await _afterLogin(
            cred.user!.uid, cred.additionalUserInfo?.isNewUser ?? false);
      } else {
        _err('Código inválido');
      }
    } on AuthFailure catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Código inválido');
    }
  }

  Future<void> _signInEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _err('Preencha todos os campos');
      return;
    }
    if (!_isValidEmail(email)) {
      _err('Digite um e-mail válido');
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInEmail(email, pass);
      await _afterLogin(cred.user!.uid, false);
    } on AuthFailure catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Não foi possível entrar. Tente novamente.');
    }
  }

  bool _isValidEmail(String email) => AuthValidators.isValidEmail(email);

  Future<void> _signInGoogle() async {
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInGoogle();
      if (cred != null) {
        await _afterLogin(
            cred.user!.uid, cred.additionalUserInfo?.isNewUser ?? false);
      } else {
        if (mounted) setState(() => _loading = false);
        // Cancelamento pelo usuário — sem snackbar.
      }
    } on AuthFailure catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Não foi possível entrar com Google.');
    }
  }

  Future<void> _signInApple() async {
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInApple();
      if (cred != null) {
        await _afterLogin(
            cred.user!.uid, cred.additionalUserInfo?.isNewUser ?? false);
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } on AuthFailure catch (e) {
      _err(e.message);
    } catch (_) {
      _err('Não foi possível entrar com Apple.');
    }
  }

  Future<void> _afterLogin(String uid, bool isNew) async {
    if (isNew) {
      final u = AuthService.current;
      await FS.saveUser(UserModel(
          id: uid,
          name: u?.displayName ?? '',
          email: u?.email ?? '',
          phone: _phoneCtrl.text,
          photoUrl: u?.photoURL,
          type: UserType.client,
          createdAt: DateTime.now()));
      if (mounted) Navigator.pushReplacementNamed(context, Routes.register);
    } else {
      await PushSvc.saveToken(uid);
      // Volta à ação iniciada antes do login (ex.: finalizar a compra).
      final pendingStore = await CartService.takePendingCheckout();
      final pendingRoute = pendingStore == null ? await AuthResume.take() : null;
      if (!mounted) return;
      final nav = Navigator.of(context);
      // Pilha limpa (evita início duplicado) e retomada da ação.
      nav.pushNamedAndRemoveUntil(Routes.main, (_) => false);
      if (pendingStore != null) {
        nav.push(MaterialPageRoute(
            builder: (_) => CheckoutScreen(storeId: pendingStore)));
      } else if (pendingRoute != null && pendingRoute.route != Routes.main) {
        nav.pushNamed(pendingRoute.route, arguments: pendingRoute.args);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.authHero),
          child: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                  child: Column(children: [
                    const SizedBox(height: 28),
                    SvgPicture.asset(AppAssets.logoMarkWhite,
                        width: 80, height: 80),
                    const SizedBox(height: 14),
                    Text(AppInfo.name,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(AppInfo.slogan,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.45)),
                    const SizedBox(height: 32),
                    Container(
                      decoration: AppDecorations.softPanel(r: 28),
                      padding: const EdgeInsets.all(22),
                      child: Column(children: [
                        Container(
                            decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.all(4),
                            child: TabBar(
                                controller: _tab,
                                indicator: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.navy
                                              .withValues(alpha: 0.08),
                                          blurRadius: 10)
                                    ]),
                                labelColor: AppColors.primary,
                                unselectedLabelColor: AppColors.textLight,
                                labelStyle: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14),
                                dividerColor: Colors.transparent,
                                tabs: const [
                                  Tab(text: 'Celular'),
                                  Tab(text: 'E-mail')
                                ])),
                        const SizedBox(height: 22),
                        // Altura acompanha o tamanho de fonte do sistema;
                        // rolagem interna evita estouro com fonte grande.
                        SizedBox(
                            height: (_otpSent ? 280.0 : 230.0) *
                                MediaQuery.textScalerOf(context)
                                    .scale(1)
                                    .clamp(1.0, 1.6),
                            child: TabBarView(controller: _tab, children: [
                              SingleChildScrollView(
                                  child: Column(children: [
                                if (!_otpSent) ...[
                                  const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('Número de celular',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textDark))),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11)
                                      ],
                                      decoration: const InputDecoration(
                                          hintText: '(DDD) 9XXXX-XXXX',
                                          prefixText: '+55  ')),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                          onPressed: _loading ? null : _sendOtp,
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2))
                                              : const Text(
                                                  'Enviar código SMS'))),
                                ] else ...[
                                  Text(
                                      'Código enviado para +55${_phoneCtrl.text}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textLight),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                      controller: _otpCtrl,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(6)
                                      ],
                                      style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 14),
                                      decoration: const InputDecoration(
                                          hintText: '000000')),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                          onPressed:
                                              _loading ? null : _confirmOtp,
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.secondary),
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2))
                                              : const Text(
                                                  '✓ Confirmar e entrar'))),
                                  TextButton(
                                      onPressed: () => setState(() {
                                            _otpSent = false;
                                            _otpCtrl.clear();
                                          }),
                                      child: const Text('Trocar número')),
                                ],
                              ])),
                              SingleChildScrollView(
                                  child: Column(children: [
                                TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                        hintText: 'seu@email.com',
                                        prefixIcon:
                                            Icon(Icons.email_outlined))),
                                const SizedBox(height: 10),
                                TextFormField(
                                    controller: _passCtrl,
                                    obscureText: !_passVis,
                                    decoration: InputDecoration(
                                        hintText: 'Senha',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                            icon: Icon(_passVis
                                                ? Icons.visibility_off
                                                : Icons.visibility),
                                            onPressed: () => setState(
                                                () => _passVis = !_passVis)))),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                        onPressed: () async {
                                          final email = _emailCtrl.text.trim();
                                          if (email.isEmpty) {
                                            _err('Digite seu e-mail');
                                            return;
                                          }
                                          if (!_isValidEmail(email)) {
                                            _err('Digite um e-mail válido');
                                            return;
                                          }
                                          try {
                                            await AuthService.resetPassword(
                                                email);
                                            if (context.mounted) {
                                              snack(context,
                                                  'E-mail de recuperação enviado!',
                                                  bg: AppColors.secondary);
                                            }
                                          } on AuthFailure catch (e) {
                                            _err(e.message);
                                          } catch (_) {
                                            _err(
                                                'Não foi possível enviar o e-mail.');
                                          }
                                        },
                                        child: const Text('Esqueci a senha',
                                            style: TextStyle(fontSize: 12)))),
                                SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                        onPressed:
                                            _loading ? null : _signInEmail,
                                        child: _loading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2))
                                            : const Text('Entrar'))),
                                const SizedBox(height: 8),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text('Não tem conta? ',
                                          style: TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 13)),
                                      GestureDetector(
                                          onTap: () => Navigator.pushNamed(
                                              context, Routes.register),
                                          child: const Text('Cadastre-se',
                                              style: TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)))
                                    ]),
                              ])),
                            ])),
                        const SizedBox(height: 16),
                        Row(children: [
                          const Expanded(child: Divider()),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('ou',
                                  style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 12))),
                          const Expanded(child: Divider())
                        ]),
                        const SizedBox(height: 16),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _loading ? null : _signInGoogle,
                              icon: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(6)),
                                child: const Text('G',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13)),
                              ),
                              label: const Text('Continuar com Google',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(
                                      color: AppColors.border)),
                            )),
                        if (PlatformInfo.isIOS) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : _signInApple,
                                icon: const Icon(Icons.apple,
                                    color: Colors.black, size: 20),
                                label: const Text('Continuar com Apple',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: const BorderSide(
                                        color: AppColors.border)),
                              )),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                        key: const Key('login-explore-guest'),
                        onPressed: () {
                          // Desistiu do login: não retoma a ação depois.
                          AuthResume.clear();
                          // Aberto por uma ação protegida: volta para onde estava.
                          final nav = Navigator.of(context);
                          if (nav.canPop()) {
                            nav.pop();
                          } else {
                            nav.pushNamedAndRemoveUntil(Routes.main, (_) => false);
                          }
                        },
                        child: const Text('Explorar sem entrar',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                    const SizedBox(height: 8),
                    // Termos e privacidade abrem a tela legal (como no cadastro).
                    Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Ao continuar você concorda com os ',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                          _legalLink('Termos de Uso', isPrivacy: false),
                          Text(' e a ',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                          _legalLink('Política de Privacidade',
                              isPrivacy: true),
                          Text('.',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11)),
                        ]),
                    const SizedBox(height: 20),
                  ]))),
        ),
      );

  Widget _legalLink(String label, {required bool isPrivacy}) => InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => LegalScreen(isPrivacy: isPrivacy))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white)),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegState();
}

class _RegState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _passConfirm = TextEditingController();
  final _cpf = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  UserType _type = UserType.client;
  bool _loading = false, _terms = false, _passVis = false, _pass2Vis = false;
  final _selectedCats = <String>{};

  late final AnimationController _enterCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  /// Cadastro por e-mail precisa criar Auth quando ainda não há sessão.
  bool get _needsPassword => AuthService.uid == null;

  @override
  void initState() {
    super.initState();
    final u = AuthService.current;
    if (u?.displayName != null) _name.text = u!.displayName!;
    if (u?.email != null) _email.text = u!.email!;
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));
    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _passConfirm.dispose();
    _cpf.dispose();
    _phone.dispose();
    _city.dispose();
    _state.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_terms) {
      snack(context, 'Aceite os termos para continuar');
      return;
    }
    if (_type == UserType.provider && _selectedCats.isEmpty) {
      snack(context, 'Selecione ao menos uma categoria de atuação');
      return;
    }
    setState(() => _loading = true);

    try {
      // 1) Cria usuário no Firebase Auth (se ainda não autenticado).
      if (_needsPassword) {
        await AuthService.signUpEmail(
          email: _email.text.trim(),
          password: _pass.text,
          displayName: _name.text.trim(),
        );
      }

      final uid = AuthService.uid;
      if (uid == null) {
        throw const AuthFailure(
            'Não foi possível autenticar. Tente novamente.');
      }

      // 2) Grava perfil no Firestore.
      final position = await _resolveLocation();
      final u = UserModel(
          id: uid,
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.replaceAll(RegExp(r'\D'), ''),
          cpf: _cpf.text.replaceAll(RegExp(r'\D'), ''),
          city: _city.text.trim(),
          state: _state.text.trim().toUpperCase(),
          lat: position?.latitude,
          lng: position?.longitude,
          type: _type,
          xp: 0,
          termsAccepted: true,
          createdAt: DateTime.now());
      await FS.saveUser(u);
      // Login social/telefone já criou o perfil como cliente e saveUser
      // não altera 'type' em perfil existente: troca pela callable.
      if (_type != UserType.client &&
          !await FS.switchProfileType(_type.name)) {
        throw const AuthFailure(
            'Não foi possível definir o tipo de conta. Tente novamente.');
      }

      if (_type == UserType.provider) {
        await FS.createProviderProfile(
            userId: uid,
            name: _name.text.trim(),
            categories: _selectedCats.toList(),
            city: _city.text.trim());
      }

      // Pós-cadastro: não pode invalidar Auth + perfil já criados.
      try {
        await FS.addXp(50);
        await FS.pushNotif(
            uid,
            'Bem-vindo ao Carajás 360!',
            _type == UserType.provider
                ? 'Sua conta foi criada. Seu cadastro de prestador está em análise.'
                : 'Sua conta foi criada. Explore os serviços.',
            'general');
        await PushSvc.saveToken(uid);
      } catch (e) {
        debugPrint('Pos-cadastro (xp/notif/token): $e');
      }

      if (!mounted) return;
      snack(context, 'Conta criada com sucesso!', bg: AppColors.secondary);
      if (_type == UserType.provider) {
        Navigator.pushReplacementNamed(context, Routes.providerOnboarding);
      } else {
        Navigator.pushReplacementNamed(context, Routes.main);
      }
    } on AuthFailure catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        snack(context, e.message, bg: AppColors.error);
      }
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      if (mounted) {
        setState(() => _loading = false);
        snack(context, 'Não foi possível criar a conta. Tente novamente.',
            bg: AppColors.error);
      }
    }
  }

  // Localização real do cliente (Vol.3: Cadastro de Clientes —
  // geolocalização), usada para buscar profissionais por proximidade.
  // Retorna null silenciosamente se a permissão for negada — nunca
  // deve bloquear o cadastro.
  Future<Position?> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return null;
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  /// Voltar: desfaz a pilha quando possível. Após login social/SMS o
  /// cadastro abre sozinho (perfil de cliente já criado): segue ao início.
  void _goBack() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else if (AuthService.isAuth) {
      nav.pushNamedAndRemoveUntil(Routes.main, (_) => false);
    } else {
      nav.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    }
  }

  int get _passwordStrength {
    final p = _pass.text;
    var s = 0;
    if (p.length >= 6) s++;
    if (p.length >= 10) s++;
    if (RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    return s.clamp(0, 4);
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: SpanDs.poppins(size: 13, color: SpanDs.textSecondary),
        floatingLabelStyle:
            SpanDs.poppins(size: 13, weight: FontWeight.w600, color: SpanDs.primary),
        hintStyle: SpanDs.poppins(size: 14, color: SpanDs.textTertiary),
        prefixIcon: Icon(icon, color: SpanDs.textSecondary, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: SpanDs.surfaceVariant.withValues(alpha: 0.85),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpanDs.radiusMd),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpanDs.radiusMd),
            borderSide: const BorderSide(color: SpanDs.border, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpanDs.radiusMd),
            borderSide: const BorderSide(color: SpanDs.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpanDs.radiusMd),
            borderSide: const BorderSide(color: SpanDs.accent, width: 1.4)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SpanDs.radiusMd),
            borderSide: const BorderSide(color: SpanDs.accent, width: 1.8)),
        errorStyle: SpanDs.poppins(size: 11, color: SpanDs.accent),
      );

  Widget _premiumField(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? kt,
    List<TextInputFormatter>? fmt,
    String? Function(String?)? val,
    bool caps = false,
    bool readOnly = false,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          readOnly: readOnly,
          obscureText: obscure,
          keyboardType: kt,
          inputFormatters: fmt,
          onChanged: onChanged,
          textCapitalization:
              caps ? TextCapitalization.words : TextCapitalization.none,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: SpanDs.poppins(size: 15, weight: FontWeight.w500),
          cursorColor: SpanDs.primary,
          validator:
              val ?? (v) => v!.trim().isEmpty ? 'Campo obrigatório' : null,
          decoration: _inputDeco(label: label, icon: icon, suffix: suffix),
        ),
      );

  Widget _typeCard(UserType t, IconData icon, String title, String subtitle) {
    final sel = _type == t;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = t),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          decoration: BoxDecoration(
            gradient: sel ? SpanDs.premiumGradient : null,
            color: sel ? null : SpanDs.surfaceVariant,
            borderRadius: BorderRadius.circular(SpanDs.radiusLg),
            border: Border.all(
                color: sel ? SpanDs.primary : SpanDs.border, width: sel ? 0 : 1),
            boxShadow: sel ? SpanDs.glow : null,
          ),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: sel
                    ? SpanDs.white.withValues(alpha: 0.18)
                    : SpanDs.background.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 22,
                  color: sel ? SpanDs.white : SpanDs.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: SpanDs.poppins(
                    size: 12,
                    weight: FontWeight.w700,
                    color: sel ? SpanDs.white : SpanDs.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SpanDs.poppins(
                    size: 9,
                    height: 1.25,
                    color: sel
                        ? SpanDs.white.withValues(alpha: 0.78)
                        : SpanDs.textTertiary)),
          ]),
        ),
      ),
    );
  }

  Widget _passwordMeter() {
    final s = _passwordStrength;
    final labels = ['', 'Fraca', 'Ok', 'Boa', 'Forte'];
    final colors = [
      SpanDs.border,
      SpanDs.accent,
      SpanDs.gold,
      SpanDs.secondary,
      SpanDs.success,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 4,
                margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                decoration: BoxDecoration(
                  color: i < s ? colors[s] : SpanDs.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
        ]),
        if (s > 0) ...[
          const SizedBox(height: 6),
          Text(labels[s],
              style: SpanDs.poppins(
                  size: 11, weight: FontWeight.w600, color: colors[s])),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Voltar do sistema segue a mesma regra do botão (nunca prende o usuário).
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Theme(
      data: Theme.of(context).copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: SpanDs.background,
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? SpanDs.secondary
                  : Colors.transparent),
          checkColor: WidgetStateProperty.all(SpanDs.white),
          side: const BorderSide(color: SpanDs.border, width: 1.6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
      ),
      child: Scaffold(
        backgroundColor: SpanDs.background,
        body: LoadingOverlay(
          loading: _loading,
          child: Stack(children: [
            // Fundo editorial SpanEnglish
            const DecoratedBox(
              decoration: BoxDecoration(gradient: SpanDs.heroGradient),
              child: SizedBox.expand(),
            ),
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    SpanDs.secondary.withValues(alpha: 0.35),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            Positioned(
              bottom: 120,
              left: -70,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    SpanDs.primaryDark.withValues(alpha: 0.45),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Form(
                    key: _form,
                    child: CustomScrollView(slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(children: [
                            _GlassIconButton(
                              icon: Icons.arrow_back_ios_new_rounded,
                              tooltip: 'Voltar',
                              onTap: _goBack,
                            ),
                          ]),
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildHero()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                          child: SpanGlassPanel(
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Tipo de conta',
                                    style: SpanDs.poppins(
                                        size: 15, weight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                    'Escolha como você vai usar o Carajás 360',
                                    style: SpanDs.poppins(
                                        size: 12, color: SpanDs.textSecondary)),
                                const SizedBox(height: 14),
                                Row(children: [
                                  _typeCard(
                                      UserType.client,
                                      Icons.person_rounded,
                                      'Cliente',
                                      'Contratar serviços'),
                                  _typeCard(
                                      UserType.provider,
                                      Icons.handyman_rounded,
                                      'Prestador',
                                      'Oferecer serviços'),
                                  // Entregador oculto: módulo Entregas
                                  // ainda não está disponível.
                                ]),
                                const SizedBox(height: 22),
                                _premiumField(
                                    _name, 'Nome completo', Icons.person_outline,
                                    caps: true),
                                _premiumField(_email, 'E-mail',
                                    Icons.email_outlined,
                                    kt: TextInputType.emailAddress,
                                    readOnly: !_needsPassword &&
                                        (AuthService.current?.email ?? '').isNotEmpty,
                                    val: (v) => AuthValidators.emailError(v)),
                                if (_needsPassword) ...[
                                  _premiumField(_pass, 'Senha', Icons.lock_outline,
                                      obscure: !_passVis,
                                      onChanged: (_) => setState(() {}),
                                      val: (v) =>
                                          AuthValidators.passwordError(v),
                                      suffix: IconButton(
                                        icon: Icon(
                                            _passVis
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: SpanDs.textSecondary,
                                            size: 20),
                                        onPressed: () => setState(
                                            () => _passVis = !_passVis),
                                      )),
                                  _passwordMeter(),
                                  _premiumField(
                                      _passConfirm,
                                      'Confirmar senha',
                                      Icons.lock_outline,
                                      obscure: !_pass2Vis,
                                      val: (v) =>
                                          AuthValidators.confirmPasswordError(
                                              v, _pass.text),
                                      suffix: IconButton(
                                        icon: Icon(
                                            _pass2Vis
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: SpanDs.textSecondary,
                                            size: 20),
                                        onPressed: () => setState(
                                            () => _pass2Vis = !_pass2Vis),
                                      )),
                                ],
                                // CPF: obrigatório para prestador; cliente
                                // pode deixar em branco (pedido no pagamento).
                                _premiumField(
                                    _cpf,
                                    _type == UserType.client
                                        ? 'CPF (opcional)'
                                        : 'CPF',
                                    Icons.badge_outlined,
                                    kt: TextInputType.number,
                                    fmt: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11)
                                    ],
                                    val: (v) => _type == UserType.client &&
                                            (v ?? '').trim().isEmpty
                                        ? null
                                        : AuthValidators.cpfError(v)),
                                _premiumField(
                                    _phone, 'Telefone', Icons.phone_outlined,
                                    kt: TextInputType.phone,
                                    fmt: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(11)
                                    ],
                                    val: (v) => AuthValidators.phoneError(v)),
                                Row(children: [
                                  Expanded(
                                      child: _premiumField(_city, 'Cidade',
                                          Icons.location_city_outlined,
                                          caps: true)),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                      width: 92,
                                      child: _premiumField(
                                          _state, 'UF', Icons.map_outlined,
                                          fmt: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp('[a-zA-Z]')),
                                            LengthLimitingTextInputFormatter(2)
                                          ])),
                                ]),
                                if (_type == UserType.provider) ...[
                                  const SizedBox(height: 4),
                                  Text('Categorias de atuação',
                                      style: SpanDs.poppins(
                                          size: 14, weight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text('Selecione ao menos uma',
                                      style: SpanDs.poppins(
                                          size: 12,
                                          color: SpanDs.textSecondary)),
                                  const SizedBox(height: 12),
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 280),
                                    decoration: BoxDecoration(
                                        color: SpanDs.background
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(
                                            SpanDs.radiusLg),
                                        border: Border.all(
                                            color: SpanDs.border)),
                                    padding: const EdgeInsets.all(12),
                                    // Fonte única: catálogo administrável.
                                    child: SingleChildScrollView(
                                        child: CatalogBuilder(
                                            compact: true,
                                            builder: (_, catalog) =>
                                                CatalogMultiSelect(
                                                    catalog: catalog,
                                                    selected: _selectedCats,
                                                    onChanged: (v) => setState(
                                                        () => _selectedCats
                                                          ..clear()
                                                          ..addAll(v))))),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                const SizedBox(height: 6),
                                _buildTermsRow(),
                                const SizedBox(height: 22),
                                _buildCta(),
                                const SizedBox(height: 8),
                                Center(
                                  child: InkWell(
                                    onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => const LegalScreen(
                                                isPrivacy: true))),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 4),
                                      child: Text(
                                          'Veja como tratamos seus dados na Política de Privacidade.',
                                          textAlign: TextAlign.center,
                                          style: SpanDs.poppins(
                                              size: 11,
                                              color: SpanDs.textSecondary)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ));
  }

  Widget _buildHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: SpanDs.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                        color: SpanDs.gold.withValues(alpha: 0.35)),
                  ),
                  child: Text('GRÁTIS PARA COMEÇAR',
                      style: SpanDs.poppins(
                          size: 10,
                          weight: FontWeight.w800,
                          color: SpanDs.gold,
                          letterSpacing: 0.6)),
                ),
                const SizedBox(height: 14),
                Text('Crie sua conta',
                    style: SpanDs.poppins(
                        size: 30,
                        weight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.1)),
                const SizedBox(height: 8),
                Text(
                    'Encontre profissionais e serviços da região em um só lugar.',
                    style: SpanDs.poppins(
                        size: 13,
                        height: 1.45,
                        color: SpanDs.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.92, end: 1),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SpanDs.premiumGradient,
                boxShadow: SpanDs.glow,
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: Image.asset(
                  AppAssets.registerMascot,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => SvgPicture.asset(
                      AppAssets.ilBoasVindas,
                      fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Checkbox(
            value: _terms,
            onChanged: (v) => setState(() => _terms = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: SpanDs.poppins(size: 12, color: SpanDs.textSecondary, height: 1.45),
              children: [
                const TextSpan(text: 'Li e aceito os '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const LegalScreen(isPrivacy: false))),
                    child: Text('Termos de Uso',
                        style: SpanDs.poppins(
                            size: 12,
                            weight: FontWeight.w700,
                            color: SpanDs.primary)),
                  ),
                ),
                const TextSpan(text: ' e a '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const LegalScreen(isPrivacy: true))),
                    child: Text('Política de Privacidade',
                        style: SpanDs.poppins(
                            size: 12,
                            weight: FontWeight.w700,
                            color: SpanDs.primary)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCta() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58,
      decoration: BoxDecoration(
        gradient: SpanDs.ctaGradient,
        borderRadius: BorderRadius.circular(SpanDs.radiusMd),
        boxShadow: [
          BoxShadow(
              color: SpanDs.secondary.withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(SpanDs.radiusMd),
          onTap: _loading ? null : _save,
          child: Center(
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : Text('Criar conta grátis',
                    style: SpanDs.poppins(
                        size: 16,
                        weight: FontWeight.w800,
                        color: SpanDs.white,
                        letterSpacing: 0.2)),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _GlassIconButton(
      {required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
        message: tooltip,
        child: Semantics(
            button: true,
            label: tooltip,
            excludeSemantics: true,
            child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: SpanDs.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SpanDs.white.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, size: 18, color: SpanDs.textPrimary),
        ),
      ),
    )));
  }
}
