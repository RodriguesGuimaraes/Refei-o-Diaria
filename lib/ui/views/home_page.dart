import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/notification_service.dart';
import '../viewmodels/home_viewmodel.dart';
import 'detalhes_refeicao_page.dart';
import 'feedback_page.dart';
import 'historico_page.dart';
import 'mais_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.viewModel, this.cameraBuilder});

  final HomeViewModel viewModel;
  final WidgetBuilder? cameraBuilder;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<String>? _aberturas;

  HomeViewModel get viewModel => widget.viewModel;
  WidgetBuilder? get cameraBuilder => widget.cameraBuilder;

  @override
  void initState() {
    super.initState();
    _aberturas = viewModel.notificacoes.aberturas.listen(_abrirPorNotificacao);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final inicial = viewModel.notificacoes.consumirAberturaInicial();
      if (inicial != null) _abrirPorNotificacao(inicial);
    });
  }

  @override
  void dispose() {
    _aberturas?.cancel();
    super.dispose();
  }

  Future<void> _abrirPorNotificacao(String payload) async {
    if (!mounted) return;
    // Os dados podem ter mudado enquanto o app estava em segundo plano.
    await viewModel.carregar();
    if (!mounted) return;
    if (payload == aberturaFeedback) {
      abrirFeedback(context, viewModel, cameraBuilder: cameraBuilder);
    } else if (payload == aberturaRegistro &&
        !viewModel.salvando &&
        !viewModel.selecionandoFoto) {
      unawaited(iniciarRegistro(context, viewModel, cameraBuilder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hora = DateTime.now().hour;
    final saudacao = hora < 12
        ? 'Bom dia'
        : hora < 18
        ? 'Boa tarde'
        : 'Boa noite';
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      (constraints.maxHeight * .17).clamp(32, 112).toDouble(),
                      20,
                      48,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Image.asset(
                                'assets/Ícone de refeição — círculo verde.png',
                                width: 64,
                                height: 64,
                                excludeFromSemantics: true,
                              ),
                            ),
                            const SizedBox(height: 22),
                            const Text(
                              'Meu Almoço',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF34474F),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Registre o que você vai comer hoje\ne acompanhe seu histórico.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.65,
                                color: Color(0xFF667A82),
                              ),
                            ),
                            ListenableBuilder(
                              listenable: viewModel,
                              builder: (context, _) {
                                final total = viewModel.totalPendentes;
                                if (total == 0) {
                                  return const SizedBox(height: 40);
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 24,
                                  ),
                                  child: _CartaoPendentes(
                                    total: total,
                                    onTap: () => abrirFeedback(
                                      context,
                                      viewModel,
                                      modo: ModoFeedback.pendentes,
                                      cameraBuilder: cameraBuilder,
                                    ),
                                  ),
                                );
                              },
                            ),
                            ListenableBuilder(
                              listenable: viewModel,
                              builder: (context, _) => _AcaoInicial(
                                titulo: 'Registrar Refeição',
                                descricao:
                                    'Tire uma foto e descreva a refeição',
                                icone: Icons.photo_camera_outlined,
                                principal: true,
                                onPressed:
                                    viewModel.salvando ||
                                        viewModel.selecionandoFoto
                                    ? null
                                    : () => iniciarRegistro(
                                        context,
                                        viewModel,
                                        cameraBuilder,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _AcaoInicial(
                              titulo: 'Ver Histórico',
                              descricao: 'Veja suas refeições anteriores',
                              icone: Icons.history_outlined,
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => HistoricoPage(
                                    viewModel: viewModel,
                                    cameraBuilder: cameraBuilder,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _AcaoInicial(
                              titulo: 'Configurações',
                              descricao: 'Lembretes, relatórios e registros',
                              icone: Icons.settings_outlined,
                              onPressed: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MaisPage(viewModel: viewModel),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    child: Text(
                      '$saudacao e boa refeição!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF17694F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartaoPendentes extends StatelessWidget {
  const _CartaoPendentes({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4E0),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFB7791F),
                child: Text(
                  '$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descreverPendentes(total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B4A12),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Toque para dizer como se sentiu',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8A6A2F)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8A6A2F)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcaoInicial extends StatelessWidget {
  const _AcaoInicial({
    required this.titulo,
    required this.descricao,
    required this.icone,
    required this.onPressed,
    this.principal = false,
  });

  final String titulo;
  final String descricao;
  final IconData icone;
  final VoidCallback? onPressed;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    final cor = principal ? Colors.white : const Color(0xFF20765D);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: principal
            ? const Color(0xFF247B63)
            : const Color(0xFFEAF2EF),
        foregroundColor: cor,
        minimumSize: const Size(0, 96),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(icone, size: 27),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descricao,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: principal
                        ? const Color(0xFFD3E9E1)
                        : const Color(0xFF61766D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
