import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/orders/service_request.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';

/// Campos extras só para categorias de limpeza (não misturar com saúde/beleza).
bool categoryNeedsPropertyFields(String categoryId) {
  const cleaning = {
    'diarista',
    'faxineira',
    'limpeza',
    'limpeza_residencial',
    'limpeza_comercial',
  };
  final id = categoryId.trim().toLowerCase();
  if (cleaning.contains(id)) return true;
  final name = (Categories.byId(categoryId)?.name ?? '').toLowerCase();
  return name.contains('limpeza') || name.contains('diarista') || name.contains('faxina');
}

/// Fluxo em 3 passos: Detalhes → Revisão → Envio (pedido só no último passo).
class QuoteRequestFlowScreen extends StatefulWidget {
  final String providerId, providerName, category;
  final String? initialDescription;

  /// Preferência de data/período vinda de outra tela (ex.: Saúde).
  /// Continua sujeita à confirmação do profissional.
  final DateTime? initialPreferredDate;
  final String? initialPeriod;
  final bool remoteOnly;
  final Color providerColor;

  const QuoteRequestFlowScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.category,
    this.initialDescription,
    this.initialPreferredDate,
    this.initialPeriod,
    this.remoteOnly = false,
    this.providerColor = AppColors.primary,
  });

  @override
  State<QuoteRequestFlowScreen> createState() =>
      _QuoteRequestFlowScreenState();
}

class _QuoteRequestFlowScreenState extends State<QuoteRequestFlowScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _complement = TextEditingController();
  final _guard = SubmitGuard();

  int _step = 1;
  bool _loading = false;
  bool _confirmed = false;
  bool _urgent = false;
  String? _senderName;
  String? _propertyType;
  String? _area;
  String? _rooms;
  String? _period;
  DateTime? _preferredDate;
  final List<XFile> _photos = [];

  bool get _needsProperty => categoryNeedsPropertyFields(widget.category);
  bool get _demoBlocked =>
      HomologCatalog.enabled && HomologCatalog.isDemoProvider(widget.providerId);
  String get _categoryLabel =>
      Categories.byId(widget.category)?.name ??
      (widget.category.isEmpty ? 'Serviço' : widget.category);

  @override
  void initState() {
    super.initState();
    _preferredDate = widget.initialPreferredDate;
    const periods = {'Manhã', 'Tarde', 'Noite', 'Flexível'};
    if (periods.contains(widget.initialPeriod)) _period = widget.initialPeriod;
    final draft = widget.initialDescription?.trim() ?? '';
    if (draft.isNotEmpty) {
      _description.text = draft;
      _title.text = draft.length > 48 ? '${draft.substring(0, 48)}…' : draft;
    } else {
      _title.text = _categoryLabel;
    }
    final uid = AuthService.uid;
    if (uid == null) return;
    FS.userStream(uid).first.then((u) {
      if (!mounted) return;
      final name = u?.name.trim() ?? '';
      if (name.isNotEmpty) _senderName = name;
      final addr = u?.address?.trim();
      if (addr != null && addr.isNotEmpty && _address.text.isEmpty) {
        _address.text = addr;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _complement.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final files = await ImagePicker().pickMultiImage(imageQuality: 75);
      if (files.isEmpty || !mounted) return;
      setState(() {
        _photos
          ..clear()
          ..addAll(files.take(5));
      });
    } catch (_) {
      if (mounted) {
        snack(context, 'Não foi possível anexar as fotos agora.',
            bg: AppColors.error);
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) setState(() => _preferredDate = picked);
  }

  bool _validateDetails() {
    if (!_form.currentState!.validate()) return false;
    if (_needsProperty) {
      if (_propertyType == null || _area == null || _rooms == null) {
        snack(context, 'Preencha tipo de imóvel, área e quartos.',
            bg: AppColors.warning);
        return false;
      }
    }
    return true;
  }

  void _goReview() {
    if (!_validateDetails()) return;
    setState(() {
      _step = 2;
      _confirmed = false;
    });
  }

  String get _composedDescription {
    final parts = <String>[_description.text.trim()];
    if (_needsProperty) {
      parts.add(
          'Imóvel: ${_propertyType ?? '—'} · Área: ${_area ?? '—'} · ${_rooms ?? '—'}');
    }
    if (_preferredDate != null) {
      final d =
          '${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.year}';
      parts.add(
          'Preferência: $d${_period != null ? ' · $_period' : ''} (sujeito à confirmação)');
    }
    if (_complement.text.trim().isNotEmpty) {
      parts.add('Complemento: ${_complement.text.trim()}');
    }
    if (_photos.isNotEmpty) {
      parts.add('Fotos anexadas na solicitação: ${_photos.length}');
    }
    return parts.join('\n');
  }

  Future<void> _submit() async {
    if (_guard.busy || _loading) return;
    if (!_confirmed) {
      snack(context, 'Confirme que revisou as informações antes de enviar.');
      return;
    }
    if (!await ensureSignedIn(context,
        message: 'Faça login para solicitar um serviço.')) {
      return;
    }
    if (!mounted) return;
    final block = ServiceRequest.blockReason(
      uid: AuthService.uid,
      providerId: widget.providerId,
      demoProvider: _demoBlocked,
    );
    if (block != null) {
      snack(context, block, bg: AppColors.warning);
      return;
    }
    setState(() {
      _loading = true;
      _step = 3;
    });
    final title = _title.text.trim();
    final description = _composedDescription;
    final result = await _guard.run(() async {
      final orderId = await FS.createOrder(ServiceRequest.payload(
        providerId: widget.providerId,
        category: widget.category,
        title: title,
        description: description,
        address: _address.text,
        urgent: _urgent,
        remoteOnly: widget.remoteOnly,
      ));
      String? roomId;
      try {
        roomId = await FS.getOrCreateRoom(widget.providerId);
        await FS.sendMessage(
            roomId: roomId,
            senderName: _senderName ?? 'Cliente',
            text: ServiceRequest.chatIntro(title, description));
      } catch (_) {
        roomId = null;
      }
      return (orderId: orderId, roomId: roomId);
    }).catchError((Object _) => null);

    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      setState(() => _step = 2);
      snack(context,
          'Não foi possível enviar a solicitação. Verifique a conexão e tente novamente.',
          bg: AppColors.error);
      return;
    }
    final roomId = result.roomId;
    if (roomId == null) {
      snack(context,
          'Solicitação registrada. Não foi possível abrir a conversa agora; acompanhe em Pedidos.',
          bg: AppColors.warning);
      Navigator.pushReplacementNamed(context, Routes.myOrders);
      return;
    }
    snack(context, 'Solicitação enviada! Acompanhe pela conversa ou em Pedidos.',
        bg: AppColors.secondary);
    Navigator.pushReplacementNamed(context, Routes.chat, arguments: {
      'roomId': roomId,
      'id': widget.providerId,
      'name': widget.providerName,
      'orderId': result.orderId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Brand.background,
      body: LoadingOverlay(
        loading: _loading,
        child: Column(children: [
          Expanded(
            child: CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: BrandContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      BrandBreadcrumb(items: [
                        ('Início', () => AppNav.safeBack(context)),
                        ('Perfil profissional',
                            () => AppNav.safeBack(context)),
                        (
                          _step == 1 ? 'Solicitar serviço' : 'Revisão',
                          null
                        ),
                      ]),
                      const SizedBox(height: 12),
                      BrandPageHero(
                        title: _step == 1
                            ? 'Solicitar serviço'
                            : _step == 2
                                ? 'Revisar solicitação'
                                : 'Enviando…',
                        subtitle: _step == 1
                            ? 'Descreva o que você precisa para receber o orçamento.'
                            : _step == 2
                                ? 'Confira os detalhes antes de concluir.'
                                : 'Aguarde a confirmação do envio.',
                        trailing: Icon(
                          _step == 1
                              ? Icons.cleaning_services_rounded
                              : Icons.fact_check_rounded,
                          size: 56,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(height: 12),
                      BrandDemoNotice(
                        message: _demoBlocked
                            ? 'Modo demonstração • nenhum pedido real será enviado para este perfil.'
                            : 'Ambiente de homologação • pedidos reais só com profissionais cadastrados.',
                      ),
                      const SizedBox(height: 16),
                      BrandStepper(
                        step: _step.clamp(1, 3),
                        labels: const ['Detalhes', 'Revisão', 'Envio'],
                      ),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                flex: 3,
                                child: _step == 1
                                    ? _detailsForm()
                                    : _reviewBody()),
                            const SizedBox(width: 20),
                            SizedBox(width: 320, child: _sidebar()),
                          ],
                        )
                      else ...[
                        _sidebar(),
                        const SizedBox(height: 16),
                        _step == 1 ? _detailsForm() : _reviewBody(),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailsForm() {
    return Form(
      key: _form,
      child: Column(children: [
        BrandSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detalhes do serviço',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: widget.category.isEmpty ? null : widget.category,
                decoration: const InputDecoration(labelText: 'Serviço'),
                items: [
                  DropdownMenuItem(
                      value: widget.category, child: Text(_categoryLabel)),
                ],
                onChanged: (_) {},
              ),
              if (_needsProperty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _propertyType,
                  decoration: const InputDecoration(labelText: 'Tipo de imóvel'),
                  items: const [
                    DropdownMenuItem(value: 'Casa', child: Text('Casa')),
                    DropdownMenuItem(
                        value: 'Apartamento', child: Text('Apartamento')),
                    DropdownMenuItem(
                        value: 'Comercial', child: Text('Comercial')),
                  ],
                  onChanged: (v) => setState(() => _propertyType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _area,
                  decoration:
                      const InputDecoration(labelText: 'Área aproximada'),
                  items: const [
                    DropdownMenuItem(
                        value: 'Até 50 m²', child: Text('Até 50 m²')),
                    DropdownMenuItem(
                        value: 'Até 100 m²', child: Text('Até 100 m²')),
                    DropdownMenuItem(
                        value: 'Até 200 m²', child: Text('Até 200 m²')),
                    DropdownMenuItem(
                        value: 'Acima de 200 m²', child: Text('Acima de 200 m²')),
                  ],
                  onChanged: (v) => setState(() => _area = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _rooms,
                  decoration: const InputDecoration(labelText: 'Quartos'),
                  items: const [
                    DropdownMenuItem(
                        value: '1 quarto', child: Text('1 quarto')),
                    DropdownMenuItem(
                        value: '2 quartos', child: Text('2 quartos')),
                    DropdownMenuItem(
                        value: '3 quartos', child: Text('3 quartos')),
                    DropdownMenuItem(
                        value: '4 ou mais', child: Text('4 ou mais')),
                  ],
                  onChanged: (v) => setState(() => _rooms = v),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título *'),
                validator: ServiceRequest.titleError,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descreva o que você precisa *',
                    alignLabelWithHint: true),
                validator: ServiceRequest.descriptionError,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickPhotos,
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(_photos.isEmpty
                    ? 'Adicionar fotos (opcional)'
                    : '${_photos.length} foto(s) selecionada(s)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BrandSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Local do atendimento',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 14),
              TextFormField(
                controller: _address,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: widget.remoteOnly
                      ? 'Endereço (opcional)'
                      : 'Endereço do atendimento *',
                ),
                validator: (v) => ServiceRequest.addressError(v,
                    remoteOnly: widget.remoteOnly),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _complement,
                decoration: const InputDecoration(
                    labelText: 'Complemento (opcional)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BrandSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quando você precisa?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                  'Preferência de data — não confirma agendamento.',
                  style: TextStyle(
                      fontSize: 12.5, color: Brand.inkMuted(context))),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(_preferredDate == null
                    ? 'Escolher data de preferência'
                    : '${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.year}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _period,
                decoration: const InputDecoration(labelText: 'Período'),
                items: const [
                  DropdownMenuItem(value: 'Manhã', child: Text('Manhã')),
                  DropdownMenuItem(value: 'Tarde', child: Text('Tarde')),
                  DropdownMenuItem(value: 'Noite', child: Text('Noite')),
                  DropdownMenuItem(
                      value: 'Flexível', child: Text('Flexível')),
                ],
                onChanged: (v) => setState(() => _period = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Serviço urgente',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                value: _urgent,
                onChanged: (v) => setState(() => _urgent = v),
                activeThumbColor: AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: BrandPrimaryButton(
              label: 'Voltar ao perfil',
              outlined: true,
              onPressed: () => AppNav.safeBack(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: BrandPrimaryButton(
              label: 'Revisar solicitação →',
              onPressed: _goReview,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _reviewBody() {
    String fmtDate() {
      if (_preferredDate == null) return 'Não informada';
      return '${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.year}';
    }

    Widget section(String title, List<Widget> children, VoidCallback onEdit) =>
        BrandSoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16))),
                TextButton.icon(
                  onPressed: () => setState(() => _step = 1),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                ),
              ]),
              ...children,
            ],
          ),
        );

    return Column(children: [
      section('Detalhes do serviço', [
        _kv('Serviço', _categoryLabel),
        if (_needsProperty) ...[
          _kv('Tipo de imóvel', _propertyType ?? '—'),
          _kv('Área aproximada', _area ?? '—'),
          _kv('Quartos', _rooms ?? '—'),
        ],
        _kv('Título', _title.text.trim()),
        _kv('Descrição', _description.text.trim()),
        _kv('Fotos',
            _photos.isEmpty ? 'Nenhuma foto anexada' : '${_photos.length} foto(s)'),
      ], () {}),
      const SizedBox(height: 14),
      section('Local e preferência', [
        _kv('Endereço',
            widget.remoteOnly && _address.text.trim().isEmpty
                ? 'Atendimento a distância'
                : _address.text.trim()),
        if (_complement.text.trim().isNotEmpty)
          _kv('Complemento', _complement.text.trim()),
        _kv('Data de preferência', fmtDate()),
        _kv('Período', _period ?? 'Não informado'),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
              'A data e o horário dependem da confirmação do profissional.',
              style: TextStyle(fontSize: 12, color: Brand.inkMuted(context))),
        ),
      ], () {}),
      const SizedBox(height: 14),
      BrandSoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Antes de continuar',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            _tip('Isto é um pedido de orçamento, não um contrato fechado.'),
            _tip('Nenhuma cobrança é feita neste momento.'),
            _tip('O profissional responde com valor e disponibilidade.'),
          ],
        ),
      ),
      const SizedBox(height: 20),
      BrandSoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              title: const Text('Confirmo que revisei as informações',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            BrandPrimaryButton(
              label: _demoBlocked
                  ? 'Envio indisponível na demonstração'
                  : 'Enviar solicitação',
              locked: _demoBlocked,
              onPressed: _demoBlocked || !_confirmed ? null : _submit,
            ),
            if (_demoBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    'Pedidos reais serão liberados para profissionais cadastrados.',
                    style: TextStyle(
                        fontSize: 12, color: Brand.inkMuted(context))),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => setState(() => _step = 1),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar e editar'),
        ),
      ),
    ]);
  }

  Widget _sidebar() {
    return Column(children: [
      BrandSoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profissional selecionado',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              AppAvatar(
                  name: widget.providerName,
                  size: 48,
                  bg: widget.providerColor,
                  r: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.providerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(_categoryLabel,
                        style: TextStyle(
                            fontSize: 12, color: Brand.inkMuted(context))),
                    if (_demoBlocked)
                      const Text('Perfil demonstrativo',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Brand.goldDeep)),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 12),
      BrandSoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            _kv('Serviço', _categoryLabel),
            _kv('Atendimento',
                widget.remoteOnly ? 'A distância' : 'Presencial / domiciliar'),
            _kv('Preço', 'Sob orçamento'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Brand.goldLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                  'O valor será combinado após a avaliação do serviço.',
                  style: TextStyle(fontSize: 12, height: 1.3)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      BrandSoftCard(
        color: Brand.greenLight,
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined, color: Brand.green, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                  'Seus dados protegidos\nO endereço completo é compartilhado apenas com o profissional na contratação.',
                  style: TextStyle(fontSize: 12.5, height: 1.35)),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(k,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Brand.inkMuted(context))),
            const SizedBox(height: 2),
            Text(v,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _tip(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Brand.green),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
