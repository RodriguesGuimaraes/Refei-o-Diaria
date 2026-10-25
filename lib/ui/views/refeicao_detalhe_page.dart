import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/refeicao.dart';
import '../viewmodels/home_viewmodel.dart';
import 'camera_page.dart';
import 'feedback_page.dart';
import 'historico_page.dart';
import 'mais_page.dart';

const _fundo = Color(0xFFFAFAF8);
const _titulo = Color(0xFF34474F);
const _secundario = Color(0xFF667A82);

String descreverPorcao(int n) => n == 1 ? '1 refeição' : '$n refeições';

class RefeicaoDetalhePage extends StatelessWidget {
  const RefeicaoDetalhePage({
    super.key,
    required this.viewModel,
    required this.refeicao,
    this.cameraBuilder,
  });

  final HomeViewModel viewModel;
  final Refeicao refeicao;
  final WidgetBuilder? cameraBuilder;

  Refeicao get _atual => viewModel.refeicoes.firstWhere(
    (r) => r.id == refeicao.id,
    orElse: () => refeicao,
  );

  Future<void> _salvar(BuildContext context, Refeicao nova) async {
    final ok = await viewModel.atualizar(nova);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível salvar a alteração. Tente novamente.',
          ),
        ),
      );
    }
  }

  Future<void> _editarFoto(BuildContext context) async {
    final caminho = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: cameraBuilder ?? (_) => const CameraPage(),
      ),
    );
    if (caminho != null && context.mounted) {
      await _salvar(context, _atual.copyWith(caminhoImagem: caminho));
    }
  }

  Future<void> _editarDescricao(BuildContext context) async {
    final atual = _atual;
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DescricaoDialog(inicial: atual.descricao),
    );
    if (texto != null && texto != atual.descricao && context.mounted) {
      await _salvar(context, atual.copyWith(descricao: texto));
    }
  }

  Future<void> _editarData(BuildContext context) async {
    final atual = _atual;
    final dia = await showDatePicker(
      context: context,
      initialDate: atual.data,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (dia == null || !context.mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(atual.data),
    );
    if (!context.mounted) return;
    final escolhida = hora ?? TimeOfDay.fromDateTime(atual.data);
    final nova = DateTime(
      dia.year,
      dia.month,
      dia.day,
      escolhida.hour,
      escolhida.minute,
    );
    if (nova != atual.data) {
      await _salvar(context, atual.copyWith(data: nova));
    }
  }

  Future<void> _editarPorcao(BuildContext context) async {
    final atual = _atual;
    final valor = await showDialog<int>(
      context: context,
      builder: (_) => _PorcaoDialog(inicial: atual.porcao),
    );
    if (valor != null && valor != atual.porcao && context.mounted) {
      await _salvar(context, atual.copyWith(porcao: valor));
    }
  }

  Future<void> _excluir(BuildContext context) async {
    final id = refeicao.id;
    if (id == null) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text(
          'Esta refeição e a foto dela serão apagadas. Essa ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await viewModel.excluir(id);
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Registro excluído.')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível excluir o registro. Tente novamente.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final r = _atual;
        final ocupado = viewModel.atualizando;
        return Scaffold(
          backgroundColor: _fundo,
          appBar: AppBar(
            backgroundColor: _fundo,
            actions: [
              MenuMais(
                viewModel: viewModel,
                onExcluir: ocupado ? null : () => _excluir(context),
              ),
            ],
            bottom: ocupado
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _FotoGrande(
                  caminho: r.caminhoImagem,
                  onTap: ocupado ? null : () => _editarFoto(context),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: ocupado ? null : () => _editarDescricao(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Text(
                    r.descricao,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _titulo,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: ocupado ? null : () => _editarData(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: _secundario,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            formatarDataHora(r.data),
                            style: const TextStyle(
                              fontSize: 13,
                              color: _secundario,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Informacao(
                  icone: Icons.edit_note_outlined,
                  rotulo: 'Descrição',
                  valor: r.descricao,
                  onTap: ocupado ? null : () => _editarDescricao(context),
                ),
                const Divider(height: 1),
                _Informacao(
                  icone: Icons.inventory_2_outlined,
                  rotulo: 'Porção',
                  valor: descreverPorcao(r.porcao),
                  onTap: ocupado ? null : () => _editarPorcao(context),
                ),
                const Divider(height: 1),
                _Informacao(
                  icone: Icons.favorite_border,
                  rotulo: 'Como se sentiu',
                  valor: descreverSentimento(r),
                  trailing: IconeFeedback(refeicao: r),
                  onTap: ocupado || viewModel.respondendo
                      ? null
                      : () => editarSentimento(context, viewModel, r),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FotoGrande extends StatelessWidget {
  const _FotoGrande({required this.caminho, required this.onTap});

  final String? caminho;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFE6ECEA),
      child: Center(child: Icon(Icons.restaurant_outlined, size: 48)),
    );
    return Semantics(
      button: true,
      label: 'Alterar foto da refeição',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (caminho == null)
                  fallback
                else
                  Image.file(
                    File(caminho!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
                  ),
                const Positioned(
                  right: 10,
                  bottom: 10,
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

class _Informacao extends StatelessWidget {
  const _Informacao({
    required this.icone,
    required this.rotulo,
    required this.valor,
    required this.onTap,
    this.trailing,
  });

  final IconData icone;
  final String rotulo;
  final String valor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      leading: Icon(icone, color: _secundario),
      title: Text(
        rotulo,
        style: const TextStyle(fontSize: 14, color: _secundario),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          valor,
          style: const TextStyle(fontSize: 13, color: _titulo),
        ),
      ),
    );
  }
}

class _DescricaoDialog extends StatefulWidget {
  const _DescricaoDialog({required this.inicial});

  final String inicial;

  @override
  State<_DescricaoDialog> createState() => _DescricaoDialogState();
}

class _DescricaoDialogState extends State<_DescricaoDialog> {
  late final _controller = TextEditingController(text: widget.inicial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Descrição'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Informe a descrição da refeição.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Salvar')),
      ],
    );
  }
}

class _PorcaoDialog extends StatefulWidget {
  const _PorcaoDialog({required this.inicial});

  final int inicial;

  @override
  State<_PorcaoDialog> createState() => _PorcaoDialogState();
}

class _PorcaoDialogState extends State<_PorcaoDialog> {
  late int _valor = widget.inicial;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Porção'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Diminuir',
            onPressed: _valor > 1 ? () => setState(() => _valor--) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                descreverPorcao(_valor),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Aumentar',
            onPressed: _valor < 20 ? () => setState(() => _valor++) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _valor),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
