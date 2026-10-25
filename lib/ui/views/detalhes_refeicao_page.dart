import 'dart:io';

import 'package:flutter/material.dart';

import '../viewmodels/home_viewmodel.dart';
import 'camera_page.dart';
import 'mais_page.dart';

const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

String _formatarData(DateTime d) {
  final hoje = DateTime.now();
  final ehHoje =
      d.year == hoje.year && d.month == hoje.month && d.day == hoje.day;
  final texto = '${d.day} de ${_meses[d.month - 1]} de ${d.year}';
  return ehHoje ? 'Hoje, $texto' : texto;
}

/// Fluxo de registro: abre a câmera e, se houver foto, a tela de detalhes.
Future<void> iniciarRegistro(
  BuildContext context,
  HomeViewModel viewModel,
  WidgetBuilder? cameraBuilder,
) async {
  final navigator = Navigator.of(context);
  final caminho = await navigator.push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: cameraBuilder ?? (_) => const CameraPage(),
    ),
  );
  if (caminho == null) return;
  viewModel.definirFoto(caminho);
  await navigator.push<void>(
    MaterialPageRoute(
      builder: (_) => DetalhesRefeicaoPage(
        viewModel: viewModel,
        cameraBuilder: cameraBuilder,
      ),
    ),
  );
  viewModel.limparRascunho();
}

class DetalhesRefeicaoPage extends StatefulWidget {
  const DetalhesRefeicaoPage({
    super.key,
    required this.viewModel,
    this.cameraBuilder,
  });

  final HomeViewModel viewModel;
  final WidgetBuilder? cameraBuilder;

  @override
  State<DetalhesRefeicaoPage> createState() => _DetalhesRefeicaoPageState();
}

class _DetalhesRefeicaoPageState extends State<DetalhesRefeicaoPage> {
  static const _verde = Color(0xFF2A7A5C);
  static const _texto = Color(0xFF34474F);
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricao;

  HomeViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _descricao = TextEditingController(text: _vm.descricao);
  }

  @override
  void dispose() {
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _trocarFoto() async {
    final caminho = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: widget.cameraBuilder ?? (_) => const CameraPage(),
      ),
    );
    if (caminho != null) _vm.definirFoto(caminho);
  }

  Future<void> _escolherData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _vm.data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (data != null) {
      final atual = _vm.data;
      _vm.alterarData(
        DateTime(data.year, data.month, data.day, atual.hour, atual.minute),
      );
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    final salvo = await _vm.salvar();
    if (salvo && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final ocupado = _vm.salvando || _vm.selecionandoFoto;
        return PopScope(
          canPop: !ocupado,
          child: Scaffold(
            backgroundColor: const Color(0xFFFAFAF8),
            appBar: AppBar(
              backgroundColor: const Color(0xFFFAFAF8),
              centerTitle: true,
              title: const Text(
                'Registrar refeição',
                style: TextStyle(fontWeight: FontWeight.w700, color: _texto),
              ),
              actions: [MenuMais(viewModel: _vm)],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _foto(ocupado)),
                            const SizedBox(height: 28),
                            const Text(
                              'Descrição da refeição',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _texto,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _descricao,
                              enabled: !ocupado,
                              minLines: 4,
                              maxLines: 6,
                              maxLength: 200,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: _vm.alterarDescricao,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Informe a descrição da refeição.'
                                  : null,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText:
                                    'Ex.: Frango grelhado, arroz e salada',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabled: !ocupado,
                                onTap: _escolherData,
                                leading: const Icon(
                                  Icons.calendar_today_outlined,
                                ),
                                title: const Text(
                                  'Data',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(_formatarData(_vm.data)),
                              ),
                            ),
                            if (_vm.erroFormulario != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  _vm.erroFormulario!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _verde,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: ocupado ? null : _salvar,
                        icon: const Icon(Icons.check),
                        label: Text(
                          _vm.salvando ? 'Salvando...' : 'Salvar Refeição',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _foto(bool ocupado) {
    final caminho = _vm.caminhoImagem;
    return Semantics(
      button: true,
      label: 'Alterar foto da refeição',
      child: GestureDetector(
        onTap: ocupado ? null : _trocarFoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (caminho == null)
                  const ColoredBox(
                    color: Color(0xFFE6ECEA),
                    child: Icon(Icons.restaurant_outlined, size: 48),
                  )
                else
                  Image.file(
                    File(caminho),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Color(0xFFE6ECEA),
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                const Positioned(
                  right: 8,
                  bottom: 8,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
