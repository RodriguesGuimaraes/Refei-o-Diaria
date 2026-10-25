import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/refeicao.dart';
import '../viewmodels/home_viewmodel.dart';
import 'calendario_page.dart';
import 'detalhes_refeicao_page.dart';
import 'refeicao_detalhe_page.dart';

const _fundo = Color(0xFFFAFAF8);
const _titulo = Color(0xFF34474F);
const _secundario = Color(0xFF667A82);

const _mesesAbreviados = [
  'jan.',
  'fev.',
  'mar.',
  'abr.',
  'mai.',
  'jun.',
  'jul.',
  'ago.',
  'set.',
  'out.',
  'nov.',
  'dez.',
];

String _dois(int n) => n.toString().padLeft(2, '0');

String formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

String formatarDataHora(DateTime d) =>
    '${d.day} de ${_mesesAbreviados[d.month - 1]} de ${d.year} • ${formatarHora(d)}';

void abrirDetalhe(
  BuildContext context,
  HomeViewModel viewModel,
  Refeicao refeicao,
  WidgetBuilder? cameraBuilder,
) {
  Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => RefeicaoDetalhePage(
        viewModel: viewModel,
        refeicao: refeicao,
        cameraBuilder: cameraBuilder,
      ),
    ),
  );
}

class HistoricoPage extends StatelessWidget {
  const HistoricoPage({super.key, required this.viewModel, this.cameraBuilder});

  final HomeViewModel viewModel;
  final WidgetBuilder? cameraBuilder;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final itens = viewModel.refeicoes;
        final vazio =
            itens.isEmpty &&
            !viewModel.carregando &&
            viewModel.erroCarregamento == null;
        return Scaffold(
          backgroundColor: _fundo,
          appBar: AppBar(
            backgroundColor: _fundo,
            centerTitle: true,
            title: const Text(
              'Histórico',
              style: TextStyle(fontWeight: FontWeight.w700, color: _titulo),
            ),
            actions: [
              if (!vazio)
                IconButton(
                  tooltip: 'Histórico por calendário',
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => CalendarioPage(
                        viewModel: viewModel,
                        cameraBuilder: cameraBuilder,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (viewModel.carregando) const LinearProgressIndicator(),
                if (viewModel.erroCarregamento != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(viewModel.erroCarregamento!),
                        TextButton.icon(
                          onPressed: viewModel.carregando
                              ? null
                              : viewModel.carregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                if (!vazio)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Todas as refeições',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _titulo,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: itens.isEmpty
                      ? _HistoricoVazio(
                          onRegistrar: viewModel.salvando
                              ? null
                              : () => iniciarRegistro(
                                  context,
                                  viewModel,
                                  cameraBuilder,
                                ),
                        )
                      : RefreshIndicator(
                          onRefresh: viewModel.carregar,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: itens.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => RefeicaoTile(
                              refeicao: itens[i],
                              mostrarData: true,
                              onTap: () => abrirDetalhe(
                                context,
                                viewModel,
                                itens[i],
                                cameraBuilder,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoricoVazio extends StatelessWidget {
  const _HistoricoVazio({required this.onRegistrar});

  final VoidCallback? onRegistrar;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/Prato e talheres.png',
                        width: 150,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Ainda não há registros',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _titulo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Comece agora a registrar o que você comeu\npara ver seu histórico aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _secundario,
                      ),
                    ),
                    const SizedBox(height: 40),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2A7A5C),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: onRegistrar,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Registrar Refeição'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RefeicaoTile extends StatelessWidget {
  const RefeicaoTile({
    super.key,
    required this.refeicao,
    required this.mostrarData,
    this.onTap,
  });

  final Refeicao refeicao;
  final bool mostrarData;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: FotoRefeicao(caminho: refeicao.caminhoImagem),
        title: Text(
          refeicao.descricao,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _titulo),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            mostrarData
                ? formatarDataHora(refeicao.data)
                : formatarHora(refeicao.data),
            style: const TextStyle(fontSize: 12, color: _secundario),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconeFeedback(refeicao: refeicao),
            const Icon(Icons.chevron_right, color: _secundario),
          ],
        ),
      ),
    );
  }
}

/// ✓ verde (passou bem), ⚠ vermelho (passou mal) ou ⏳ (sem resposta).
class IconeFeedback extends StatelessWidget {
  const IconeFeedback({super.key, required this.refeicao, this.tamanho = 22});

  final Refeicao refeicao;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final (icone, cor, texto) = switch (refeicao.passouMal) {
      false => (Icons.check_circle, const Color(0xFF2A7A5C), 'Passou bem'),
      true => (Icons.warning_rounded, const Color(0xFFC62828), 'Passou mal'),
      null => (
        Icons.hourglass_bottom_rounded,
        const Color(0xFFB7791F),
        'Aguardando resposta',
      ),
    };
    return Tooltip(
      message: texto,
      child: Icon(icone, color: cor, size: tamanho, semanticLabel: texto),
    );
  }
}

class FotoRefeicao extends StatelessWidget {
  const FotoRefeicao({super.key, this.caminho});

  final String? caminho;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: Color(0xFFE6ECEA),
      child: Center(child: Icon(Icons.restaurant_outlined)),
    );
    return SizedBox(
      width: 64,
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: caminho == null
            ? fallback
            : Image.file(
                File(caminho!),
                fit: BoxFit.cover,
                semanticLabel: 'Foto da refeição',
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
