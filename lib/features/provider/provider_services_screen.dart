import 'package:flutter/material.dart';

import '../../core/catalog/catalog_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Edição das especialidades do prestador a partir do catálogo
/// administrável. Especialidades antigas/desativadas já declaradas são
/// mantidas até o próprio prestador removê-las; nada é acrescentado
/// automaticamente.
class ProviderServicesScreen extends StatefulWidget {
  const ProviderServicesScreen({super.key});
  @override
  State<ProviderServicesScreen> createState() => _ProviderServicesState();
}

class _ProviderServicesState extends State<ProviderServicesScreen> {
  Set<String>? _selected;
  String? _providerId;
  bool _saving = false;
  // Criado uma vez: cada marcação faz setState e recriava a assinatura.
  late final Stream<ProviderModel?> _provider = FS.myProviderStream();

  Future<void> _save() async {
    final sel = _selected;
    if (sel == null || _providerId == null) return;
    if (sel.isEmpty) {
      snack(context, 'Selecione ao menos uma especialidade', bg: AppColors.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await FS.updateProviderCategories(_providerId!, sel.toList());
      if (!mounted) return;
      snack(context, '✅ Especialidades atualizadas', bg: AppColors.secondary);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        snack(context, 'Não foi possível salvar (verifique a conexão): $e',
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Minhas especialidades')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
                onPressed: _saving || _selected == null ? null : _save,
                child: Text(_saving ? 'Salvando...' : 'Salvar')),
          ),
        ),
        body: StreamBuilder<ProviderModel?>(
          stream: _provider,
          builder: (_, snap) {
            if (snap.hasError) return QueryErrorView(error: snap.error);
            if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final prov = snap.data;
            if (prov == null) {
              return const EmptyState(
                  emoji: '👷',
                  title: 'Perfil de prestador não encontrado',
                  subtitle: 'Cadastre-se como profissional para escolher especialidades.');
            }
            _providerId ??= prov.id;
            _selected ??= prov.categories.toSet();
            return CatalogBuilder(
              builder: (_, catalog) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                      'Marque a área em geral e/ou os serviços específicos que você realiza. '
                      'Você só aparece nas buscas do que marcar aqui.',
                      style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                  const SizedBox(height: 12),
                  CatalogMultiSelect(
                    catalog: catalog,
                    selected: _selected!,
                    onChanged: (v) => setState(() => _selected = v),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
