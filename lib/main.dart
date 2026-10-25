import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'data/repositories/configuracoes_repository.dart';
import 'data/repositories/refeicao_repository.dart';
import 'data/services/hive_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/relatorio_service.dart';
import 'data/services/transferencia_service.dart';
import 'ui/viewmodels/home_viewmodel.dart';
import 'ui/views/home_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.viewModel, this.cameraBuilder});

  final HomeViewModel? viewModel;
  final WidgetBuilder? cameraBuilder;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<HomeViewModel> _inicializacao;
  HomeViewModel? _model;
  HiveService? _hive;

  @override
  void initState() {
    super.initState();
    _inicializacao = widget.viewModel == null
        ? _preparar()
        : Future.value(widget.viewModel);
  }

  Future<HomeViewModel> _preparar() async {
    final diretorio = await getApplicationDocumentsDirectory();
    if (!mounted) throw StateError('Aplicativo encerrado.');
    final hive = HiveService(diretorio: diretorio);
    try {
      await hive.inicializar();
      if (!mounted) {
        await hive.fechar();
        throw StateError('Aplicativo encerrado.');
      }
      _hive = hive;
      final notificacoes = LocalNotificationService();
      try {
        // Precisa terminar antes da tela inicial para saber se o app foi
        // aberto por uma notificação.
        await notificacoes.inicializar();
      } catch (_) {}
      final model = HomeViewModel(
        repository: RefeicaoRepository(hiveService: hive),
        configuracoesRepository: ConfiguracoesRepository(hiveService: hive),
        notificacoes: notificacoes,
        relatorios: PdfRelatorioService(),
        transferencia: ArquivoTransferenciaService(),
      );
      _model = model;
      await model.inicializar();
      unawaited(model.prepararLembretes());
      return model;
    } catch (_) {
      await hive.fechar();
      rethrow;
    }
  }

  @override
  void dispose() {
    _model?.dispose();
    unawaited(_hive?.fechar());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Refeicao Diaria',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28734F)),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: FutureBuilder<HomeViewModel>(
        future: _inicializacao,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return HomePage(
              viewModel: snapshot.requireData,
              cameraBuilder: widget.cameraBuilder,
            );
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Refeicao Diaria')),
            body: Center(
              child: snapshot.hasError
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Nao foi possivel abrir o armazenamento.'),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => setState(() {
                              _inicializacao = _preparar();
                            }),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}
