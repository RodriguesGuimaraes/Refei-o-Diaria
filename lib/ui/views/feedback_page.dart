import 'package:flutter/material.dart';

import '../../models/refeicao.dart';
import '../viewmodels/home_viewmodel.dart';
import 'detalhes_refeicao_page.dart';
import 'historico_page.dart';

const _fundo = Color(0xFFFAFAF8);
const _titulo = Color(0xFF34474F);
const _secundario = Color(0xFF667A82);
const _verde = Color(0xFF2A7A5C);
const _vermelho = Color(0xFFC62828);

enum ModoFeedback {
  /// Refeições de hoje (aberto pela notificação da noite).
  hoje,

  /// Todas as refeições sem resposta (aberto pelo contador da tela inicial).
  pendentes,
}

String descreverSentimento(Refeicao refeicao) => switch (refeicao.passouMal) {
  false => 'Passei bem',
  true =>
    refeicao.observacao == null
        ? 'Passei mal'
        : 'Passei mal: ${refeicao.observacao}',
  null => 'Sem resposta. Toque para responder.',
};

String descreverPendentes(int total) => total == 1
    ? '1 refeição aguardando sua resposta'
    : '$total refeições aguardando sua resposta';

/// Pergunta o que a pessoa sentiu. Retorna `null` se cancelar.
Future<String?> pedirObservacao(BuildContext context, {String? inicial}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _ObservacaoDialog(inicial: inicial),
    );

Future<void> _avisarFalha(BuildContext context, bool ok) async {
  if (ok || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Não foi possível salvar a resposta. Tente novamente.'),
    ),
  );
}

Future<void> responderPasseiMal(
  BuildContext context,
  HomeViewModel viewModel,
  Refeicao refeicao,
) async {
  final observacao = await pedirObservacao(
    context,
    inicial: refeicao.observacao,
  );
  if (observacao == null || !context.mounted) return;
  final ok = await viewModel.responder(
    refeicao,
    passouMal: true,
    observacao: observacao,
  );
  if (context.mounted) await _avisarFalha(context, ok);
}

Future<void> responderPasseiBem(
  BuildContext context,
  HomeViewModel viewModel,
  Refeicao refeicao,
) async {
  final ok = await viewModel.responder(refeicao, passouMal: false);
  if (context.mounted) await _avisarFalha(context, ok);
}

/// Diálogo usado no detalhe do registro para alterar a resposta.
Future<void> editarSentimento(
  BuildContext context,
  HomeViewModel viewModel,
  Refeicao refeicao,
) async {
  final escolha = await showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Como você se sentiu depois desta refeição?'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'bem'),
          child: const ListTile(
            leading: Icon(Icons.check_circle, color: _verde),
            title: Text('Passei bem'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, 'mal'),
          child: const ListTile(
            leading: Icon(Icons.warning_rounded, color: _vermelho),
            title: Text('Passei mal'),
          ),
        ),
        if (!refeicao.pendente)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogContext, 'limpar'),
            child: const ListTile(
              leading: Icon(Icons.hourglass_bottom_rounded),
              title: Text('Ainda não sei'),
            ),
          ),
      ],
    ),
  );
  if (escolha == null || !context.mounted) return;
  switch (escolha) {
    case 'bem':
      await responderPasseiBem(context, viewModel, refeicao);
    case 'mal':
      await responderPasseiMal(context, viewModel, refeicao);
    default:
      final ok = await viewModel.responder(refeicao, passouMal: null);
      if (context.mounted) await _avisarFalha(context, ok);
  }
}

void abrirFeedback(
  BuildContext context,
  HomeViewModel viewModel, {
  ModoFeedback modo = ModoFeedback.hoje,
  WidgetBuilder? cameraBuilder,
  bool substituir = false,
}) {
  final rota = MaterialPageRoute<void>(
    builder: (_) => FeedbackPage(
      viewModel: viewModel,
      modo: modo,
      cameraBuilder: cameraBuilder,
    ),
  );
  final navegador = Navigator.of(context);
  substituir ? navegador.pushReplacement(rota) : navegador.push(rota);
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({
    super.key,
    required this.viewModel,
    this.modo = ModoFeedback.hoje,
    this.cameraBuilder,
  });

  final HomeViewModel viewModel;
  final ModoFeedback modo;
  final WidgetBuilder? cameraBuilder;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  /// As refeições pendentes continuam visíveis depois de respondidas.
  late final Set<int?> _idsPendentes = {
    for (final refeicao in widget.viewModel.pendentes) refeicao.id,
  };

  HomeViewModel get _vm => widget.viewModel;

  List<Refeicao> _lista() => widget.modo == ModoFeedback.hoje
      ? _vm.refeicoesDoDia(DateTime.now())
      : _vm.refeicoes.where((r) => _idsPendentes.contains(r.id)).toList();

  Future<void> _todasBem(List<Refeicao> lista) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _vm.passeiBemEmTodas(lista);
    if (!mounted) return;
    if (!ok) {
      await _avisarFalha(context, ok);
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Obrigado! Respostas salvas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final lista = _lista();
        final pendentesNaLista = lista.where((r) => r.pendente).length;
        final outrosPendentes = widget.modo == ModoFeedback.hoje
            ? _vm.totalPendentes - pendentesNaLista
            : 0;
        final ocupado = _vm.respondendo;
        return Scaffold(
          backgroundColor: _fundo,
          appBar: AppBar(
            backgroundColor: _fundo,
            centerTitle: true,
            title: Text(
              widget.modo == ModoFeedback.hoje
                  ? 'Como foi seu dia?'
                  : 'Como você se sentiu?',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _titulo,
              ),
            ),
            bottom: ocupado
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          bottomNavigationBar: pendentesNaLista == 0
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                    onPressed: ocupado ? null : () => _todasBem(lista),
                    style: FilledButton.styleFrom(
                      backgroundColor: _verde,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.sentiment_satisfied_alt),
                    label: Text(
                      widget.modo == ModoFeedback.hoje
                          ? 'Passei bem o dia todo'
                          : 'Passei bem em todas',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
          body: SafeArea(
            child: lista.isEmpty
                ? _SemRefeicoes(
                    outrosPendentes: _vm.totalPendentes,
                    onPendentes: () => abrirFeedback(
                      context,
                      _vm,
                      modo: ModoFeedback.pendentes,
                      cameraBuilder: widget.cameraBuilder,
                      substituir: true,
                    ),
                    onRegistrar: () =>
                        iniciarRegistro(context, _vm, widget.cameraBuilder),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      Text(
                        pendentesNaLista == 0
                            ? 'Tudo respondido. Obrigado!'
                            : widget.modo == ModoFeedback.hoje
                            ? 'Toque em como você se sentiu depois de cada '
                                  'refeição de hoje.'
                            : 'Estas refeições ainda estão sem resposta.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: _secundario,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._itens(lista, ocupado),
                      if (outrosPendentes > 0) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => abrirFeedback(
                            context,
                            _vm,
                            modo: ModoFeedback.pendentes,
                            cameraBuilder: widget.cameraBuilder,
                          ),
                          icon: const Icon(Icons.hourglass_bottom_rounded),
                          label: Text(
                            outrosPendentes == 1
                                ? '1 refeição de outro dia sem resposta'
                                : '$outrosPendentes refeições de outros dias '
                                      'sem resposta',
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }

  List<Widget> _itens(List<Refeicao> lista, bool ocupado) {
    final itens = <Widget>[];
    DateTime? diaAnterior;
    for (final refeicao in lista) {
      final dia = DateTime(
        refeicao.data.year,
        refeicao.data.month,
        refeicao.data.day,
      );
      if (widget.modo == ModoFeedback.pendentes && dia != diaAnterior) {
        itens.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              _rotuloDia(dia),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: _titulo,
              ),
            ),
          ),
        );
        diaAnterior = dia;
      }
      itens.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _CartaoFeedback(
            refeicao: refeicao,
            onBem: ocupado
                ? null
                : () => responderPasseiBem(context, _vm, refeicao),
            onMal: ocupado
                ? null
                : () => responderPasseiMal(context, _vm, refeicao),
          ),
        ),
      );
    }
    return itens;
  }

  String _rotuloDia(DateTime dia) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final diferenca = hoje.difference(dia).inDays;
    if (diferenca == 0) return 'Hoje';
    if (diferenca == 1) return 'Ontem';
    return formatarDataHora(dia).split(' • ').first;
  }
}

class _CartaoFeedback extends StatelessWidget {
  const _CartaoFeedback({
    required this.refeicao,
    required this.onBem,
    required this.onMal,
  });

  final Refeicao refeicao;
  final VoidCallback? onBem;
  final VoidCallback? onMal;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                FotoRefeicao(caminho: refeicao.caminhoImagem),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refeicao.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _titulo,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatarHora(refeicao.data),
                        style: const TextStyle(color: _secundario),
                      ),
                    ],
                  ),
                ),
                IconeFeedback(refeicao: refeicao, tamanho: 26),
              ],
            ),
            if (refeicao.observacao != null) ...[
              const SizedBox(height: 8),
              Text(
                refeicao.observacao!,
                style: const TextStyle(color: _vermelho),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _BotaoSentimento(
                    texto: 'Passei bem',
                    icone: Icons.check_circle,
                    cor: _verde,
                    selecionado: refeicao.passouMal == false,
                    onPressed: onBem,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BotaoSentimento(
                    texto: 'Passei mal',
                    icone: Icons.warning_rounded,
                    cor: _vermelho,
                    selecionado: refeicao.passouMal == true,
                    onPressed: onMal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoSentimento extends StatelessWidget {
  const _BotaoSentimento({
    required this.texto,
    required this.icone,
    required this.cor,
    required this.selecionado,
    required this.onPressed,
  });

  final String texto;
  final IconData icone;
  final Color cor;
  final bool selecionado;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    const tamanho = Size.fromHeight(52);
    const estilo = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    if (selecionado) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cor,
          minimumSize: tamanho,
          shape: forma,
        ),
        icon: Icon(icone),
        label: Text(texto, style: estilo),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: cor,
        side: BorderSide(color: cor),
        minimumSize: tamanho,
        shape: forma,
      ),
      icon: Icon(icone),
      label: Text(texto, style: estilo),
    );
  }
}

class _SemRefeicoes extends StatelessWidget {
  const _SemRefeicoes({
    required this.outrosPendentes,
    required this.onPendentes,
    required this.onRegistrar,
  });

  final int outrosPendentes;
  final VoidCallback onPendentes;
  final VoidCallback onRegistrar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_meals_outlined, size: 56, color: _secundario),
            const SizedBox(height: 16),
            const Text(
              'Nenhuma refeição registrada hoje.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _titulo,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRegistrar,
              style: FilledButton.styleFrom(
                backgroundColor: _verde,
                minimumSize: const Size(240, 52),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Registrar Refeição'),
            ),
            if (outrosPendentes > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPendentes,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(240, 52),
                ),
                icon: const Icon(Icons.hourglass_bottom_rounded),
                label: Text('Responder anteriores ($outrosPendentes)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ObservacaoDialog extends StatefulWidget {
  const _ObservacaoDialog({this.inicial});

  final String? inicial;

  @override
  State<_ObservacaoDialog> createState() => _ObservacaoDialogState();
}

class _ObservacaoDialogState extends State<_ObservacaoDialog> {
  late final _controller = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('O que você sentiu?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        maxLines: 3,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ex.: azia, enjoo, dor de barriga',
          helperText: 'Opcional',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Pular'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _vermelho),
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
