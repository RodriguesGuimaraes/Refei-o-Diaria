import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:refeicao_diaria/data/repositories/configuracoes_repository.dart';
import 'package:refeicao_diaria/data/repositories/refeicao_repository.dart';
import 'package:refeicao_diaria/data/services/hive_service.dart';
import 'package:refeicao_diaria/data/services/notification_service.dart';
import 'package:refeicao_diaria/data/services/relatorio_service.dart';
import 'package:refeicao_diaria/main.dart';
import 'package:refeicao_diaria/models/configuracoes_lembretes.dart';
import 'package:refeicao_diaria/models/refeicao.dart';
import 'package:refeicao_diaria/ui/viewmodels/home_viewmodel.dart';
import 'package:refeicao_diaria/ui/views/camera_page.dart';

class FakeRepository extends RefeicaoRepository {
  FakeRepository() : super(hiveService: HiveService(diretorio: Directory('.')));

  final itens = <Refeicao>[];
  bool falhar = false;

  @override
  Future<List<Refeicao>> listar() async => [
    for (var i = 0; i < itens.length; i++) itens[i].copyWith(id: i),
  ];

  @override
  Future<void> responder(List<Refeicao> respostas) async {
    if (falhar) throw StateError('Falha');
    for (final resposta in respostas) {
      itens[resposta.id!] = itens[resposta.id!].comFeedback(
        passouMal: resposta.passouMal,
        observacao: resposta.observacao,
      );
    }
  }

  @override
  Future<void> atualizar(Refeicao refeicao) async {
    itens[refeicao.id!] = refeicao;
  }
}

class FakeNotificacoes implements NotificationService {
  final controller = StreamController<String>.broadcast();
  String? inicial;
  bool permitido = true;
  bool concederAoPedir = true;
  int pedidos = 0;
  final agendamentos = <ConfiguracoesLembretes>[];

  @override
  Stream<String> get aberturas => controller.stream;

  @override
  Future<void> inicializar() async {}

  @override
  String? consumirAberturaInicial() {
    final valor = inicial;
    inicial = null;
    return valor;
  }

  @override
  Future<bool> permissaoConcedida() async => permitido;

  @override
  Future<bool> solicitarPermissao() async {
    pedidos++;
    permitido = permitido || concederAoPedir;
    return permitido;
  }

  @override
  Future<void> agendar(ConfiguracoesLembretes configuracoes) async {
    agendamentos.add(configuracoes);
  }

  @override
  Future<void> abrirConfiguracoesNotificacao() async {}

  @override
  Future<void> abrirConfiguracoesBateria() async {}
}

class FakeRelatorio implements RelatorioService {
  List<Refeicao>? refeicoes;
  DateTime? inicio;
  bool? incluirFotos;
  bool? incluirSemMalEstar;

  @override
  Future<void> compartilhar({
    required List<Refeicao> refeicoes,
    required DateTime inicio,
    required DateTime fim,
    bool incluirFotos = true,
    bool incluirSemMalEstar = false,
  }) async {
    this.refeicoes = refeicoes;
    this.inicio = inicio;
    this.incluirFotos = incluirFotos;
    this.incluirSemMalEstar = incluirSemMalEstar;
  }
}

void main() {
  final agora = DateTime.now();
  final hojeAoMeioDia = DateTime(agora.year, agora.month, agora.day, 12);

  group('modelo', () {
    test('registro antigo sem feedback fica pendente', () {
      final antigo = Refeicao.fromMap({
        'data': DateTime(2025).toIso8601String(),
        'descricao': 'Antigo',
      });
      expect(antigo.pendente, isTrue);
      expect(antigo.observacao, isNull);
    });

    test('feedback ignora observacao vazia e passou bem', () {
      final base = Refeicao(data: DateTime(2026), descricao: 'Sopa');
      expect(
        base.comFeedback(passouMal: true, observacao: '  ').observacao,
        isNull,
      );
      final mal = base.comFeedback(passouMal: true, observacao: ' Azia ');
      expect(mal.observacao, 'Azia');
      expect(Refeicao.fromMap(mal.toMap()).passouMal, isTrue);
      expect(mal.copyWith(descricao: 'Outra').observacao, 'Azia');
      expect(base.comFeedback(passouMal: null).pendente, isTrue);
    });

    test('configuracoes usam padrao para valores invalidos', () {
      final config = ConfiguracoesLembretes.fromMap({
        'noite': {'ativo': false, 'hora': 99, 'minuto': 15},
      });
      expect(config.noite.ativo, isFalse);
      expect(config.noite.hora, 20);
      expect(config.noite.minuto, 15);
      expect(config.almoco, ConfiguracoesLembretes.almocoPadrao);
      expect(config.noite.horario, '20:15');
    });
  });

  group('persistencia', () {
    late Directory diretorio;
    late HiveService hive;
    late RefeicaoRepository repository;

    setUp(() async {
      diretorio = await Directory.systemTemp.createTemp('feedback_test_');
      hive = HiveService(diretorio: diretorio);
      await hive.inicializar();
      repository = RefeicaoRepository(hiveService: hive);
    });

    tearDown(() async {
      await hive.fechar();
      await diretorio.delete(recursive: true);
    });

    test('responder grava feedback e edicao preserva', () async {
      await repository.adicionar(
        Refeicao(data: DateTime(2026, 1, 2), descricao: 'Feijoada'),
      );
      final salva = (await repository.listar()).single;
      expect(salva.pendente, isTrue);

      await repository.responder([
        salva.comFeedback(passouMal: true, observacao: 'Azia'),
      ]);
      await hive.fechar();
      await hive.inicializar();
      final respondida = (await repository.listar()).single;
      expect(respondida.passouMal, isTrue);
      expect(respondida.observacao, 'Azia');

      await repository.atualizar(respondida.copyWith(porcao: 2));
      final editada = (await repository.listar()).single;
      expect(editada.porcao, 2);
      expect(editada.passouMal, isTrue);
      expect(editada.observacao, 'Azia');
    });

    test('configuracoes de lembrete sobrevivem ao reabrir', () async {
      final configuracoes = ConfiguracoesRepository(hiveService: hive);
      expect(configuracoes.carregarLembretes().noite.horario, '20:00');
      await configuracoes.salvarLembretes(
        const ConfiguracoesLembretes().alterar(
          TipoLembrete.noite,
          const Lembrete(ativo: true, hora: 21, minuto: 30),
        ),
      );
      await hive.fechar();
      await hive.inicializar();
      expect(configuracoes.carregarLembretes().noite.horario, '21:30');
    });

    test('limpar refeicoes mantem configuracoes', () async {
      final configuracoes = ConfiguracoesRepository(hiveService: hive);
      await configuracoes.salvarLembretes(
        const ConfiguracoesLembretes().alterar(
          TipoLembrete.jantar,
          const Lembrete(ativo: true, hora: 19, minuto: 45),
        ),
      );
      await repository.limparTudo();
      expect(configuracoes.carregarLembretes().jantar.ativo, isTrue);
    });
  });

  test('relatorio gera um PDF valido', () async {
    final bytes = await gerarRelatorioPdf(
      refeicoes: [
        Refeicao(
          data: DateTime(2026, 3, 1, 12),
          descricao: 'Feijoada com açúcar',
        ).comFeedback(passouMal: true, observacao: 'Azia e enjoo'),
        Refeicao(data: DateTime(2026, 3, 2, 12), descricao: 'Salada'),
      ],
      inicio: DateTime(2026, 3, 1),
      fim: DateTime(2026, 3, 2),
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('sem a opcao, so as refeicoes em que passou mal entram', () async {
    final carregadas = <String>[];
    final refeicoes = [
      Refeicao(
        data: DateTime(2026, 3, 1, 12),
        descricao: 'Feijoada',
        caminhoImagem: 'mal.jpg',
      ).comFeedback(passouMal: true),
      Refeicao(
        data: DateTime(2026, 3, 1, 19),
        descricao: 'Sopa',
        caminhoImagem: 'bem.jpg',
      ).comFeedback(passouMal: false),
      Refeicao(
        data: DateTime(2026, 3, 2, 12),
        descricao: 'Salada',
        caminhoImagem: 'pendente.jpg',
      ),
    ];
    Future<Uint8List?> carregar(String caminho) async {
      carregadas.add(caminho);
      return null;
    }

    final soMal = await gerarRelatorioPdf(
      refeicoes: refeicoes,
      inicio: DateTime(2026, 3, 1),
      fim: DateTime(2026, 3, 2),
      carregarFoto: carregar,
    );
    expect(carregadas, ['mal.jpg']);
    carregadas.clear();
    final todas = await gerarRelatorioPdf(
      refeicoes: refeicoes,
      inicio: DateTime(2026, 3, 1),
      fim: DateTime(2026, 3, 2),
      carregarFoto: carregar,
      incluirSemMalEstar: true,
    );
    expect(carregadas, ['mal.jpg', 'bem.jpg', 'pendente.jpg']);
    expect(String.fromCharCodes(soMal.take(4)), '%PDF');
    expect(todas.length, greaterThan(soMal.length));
  });

  group('fotos no relatorio', () {
    late Directory pasta;

    setUp(() async {
      pasta = await Directory.systemTemp.createTemp('relatorio_foto_');
    });
    tearDown(() => pasta.delete(recursive: true));

    Future<String> criarFoto(int largura, int altura) async {
      final imagem = img.Image(width: largura, height: altura);
      img.fill(imagem, color: img.ColorRgb8(200, 80, 40));
      final arquivo = File('${pasta.path}/foto_$largura.jpg');
      await arquivo.writeAsBytes(img.encodeJpg(imagem));
      return arquivo.path;
    }

    testWidgets('miniatura reduz foto grande e mantem proporcao', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final miniatura = await gerarMiniatura(
          await criarFoto(1200, 900),
          largura: 300,
        );
        expect(miniatura, isNotNull);
        final decodificada = img.decodeJpg(miniatura!)!;
        expect(decodificada.width, 300);
        expect(decodificada.height, 225);

        final pequena = img.decodeJpg(
          (await gerarMiniatura(await criarFoto(120, 90), largura: 300))!,
        )!;
        expect(pequena.width, 120);
        expect(await gerarMiniatura('${pasta.path}/nao_existe.jpg'), isNull);
      });
    });

    test('PDF com fotos embute a imagem e tolera foto ausente', () async {
      final foto = img.encodeJpg(img.Image(width: 40, height: 30));
      final carregadas = <String>[];
      final refeicoes = [
        Refeicao(
          data: DateTime(2026, 3, 1, 12),
          descricao: 'Com foto',
          caminhoImagem: 'a.jpg',
        ),
        Refeicao(
          data: DateTime(2026, 3, 1, 19),
          descricao: 'Foto perdida',
          caminhoImagem: 'b.jpg',
        ),
        Refeicao(data: DateTime(2026, 3, 2, 12), descricao: 'Sem foto'),
      ];
      final comFotos = await gerarRelatorioPdf(
        refeicoes: refeicoes,
        inicio: DateTime(2026, 3, 1),
        fim: DateTime(2026, 3, 2),
        incluirSemMalEstar: true,
        carregarFoto: (caminho) async {
          carregadas.add(caminho);
          return caminho == 'a.jpg' ? foto : null;
        },
      );
      final semFotos = await gerarRelatorioPdf(
        refeicoes: refeicoes,
        inicio: DateTime(2026, 3, 1),
        fim: DateTime(2026, 3, 2),
        incluirSemMalEstar: true,
      );
      expect(carregadas, ['a.jpg', 'b.jpg']);
      expect(String.fromCharCodes(comFotos.take(4)), '%PDF');
      // O PDF é comprimido; a foto embutida aparece como aumento de tamanho.
      expect(comFotos.length, greaterThan(semFotos.length + foto.length ~/ 2));
    });
  });

  group('view model', () {
    late FakeRepository repository;
    late FakeNotificacoes notificacoes;
    late FakeRelatorio relatorio;
    late HomeViewModel model;

    setUp(() {
      repository = FakeRepository();
      notificacoes = FakeNotificacoes();
      relatorio = FakeRelatorio();
      model = HomeViewModel(
        repository: repository,
        notificacoes: notificacoes,
        relatorios: relatorio,
        selecionarFoto: () async => null,
        recuperarFotos: () async => LostDataResponse.empty(),
      );
    });
    tearDown(() => model.dispose());

    test('conta pendentes de todos os dias e responde em lote', () async {
      repository.itens.addAll([
        Refeicao(data: hojeAoMeioDia, descricao: 'Hoje'),
        Refeicao(data: DateTime(2025, 1, 1), descricao: 'Antiga'),
        Refeicao(
          data: DateTime(2025, 1, 2),
          descricao: 'Respondida',
        ).comFeedback(passouMal: true),
      ]);
      await model.inicializar();
      expect(model.totalPendentes, 2);
      expect(model.refeicoesDoDia(agora).single.descricao, 'Hoje');

      expect(await model.passeiBemEmTodas(model.refeicoes), isTrue);
      expect(model.totalPendentes, 0);
      expect(repository.itens[2].passouMal, isTrue);
      expect(repository.itens[0].passouMal, isFalse);
    });

    test('falha ao responder preserva pendencia', () async {
      repository.itens.add(Refeicao(data: hojeAoMeioDia, descricao: 'Hoje'));
      await model.inicializar();
      repository.falhar = true;
      final ok = await model.responder(model.refeicoes.single, passouMal: true);
      expect(ok, isFalse);
      expect(model.totalPendentes, 1);
      expect(model.respondendo, isFalse);
    });

    test('prepara lembretes pedindo permissao e agenda', () async {
      notificacoes.permitido = false;
      await model.prepararLembretes();
      expect(notificacoes.pedidos, 1);
      expect(model.notificacoesPermitidas, isTrue);
      expect(notificacoes.agendamentos.single.noite.horario, '20:00');
    });

    test('alterar lembrete reagenda com novo horario', () async {
      await model.prepararLembretes();
      final ok = await model.alterarLembrete(
        TipoLembrete.noite,
        const Lembrete(ativo: true, hora: 21, minuto: 15),
      );
      expect(ok, isTrue);
      expect(model.lembretes.noite.horario, '21:15');
      expect(notificacoes.agendamentos.last.noite.horario, '21:15');
    });

    test('relatorio filtra o periodo escolhido', () async {
      repository.itens.addAll([
        Refeicao(data: hojeAoMeioDia, descricao: 'Recente'),
        Refeicao(
          data: hojeAoMeioDia.subtract(const Duration(days: 40)),
          descricao: 'Antiga',
        ),
      ]);
      await model.inicializar();
      expect(await model.compartilharRelatorio(dias: 7), isTrue);
      expect(relatorio.refeicoes!.map((r) => r.descricao), ['Recente']);
      expect(relatorio.incluirFotos, isTrue);
      expect(await model.compartilharRelatorio(incluirFotos: false), isTrue);
      expect(relatorio.refeicoes, hasLength(2));
      expect(relatorio.incluirFotos, isFalse);
      expect(model.gerandoRelatorio, isFalse);
    });
  });

  group('telas', () {
    late FakeRepository repository;
    late FakeNotificacoes notificacoes;
    late HomeViewModel model;

    setUp(() {
      repository = FakeRepository();
      notificacoes = FakeNotificacoes();
      model = HomeViewModel(
        repository: repository,
        notificacoes: notificacoes,
        relatorios: FakeRelatorio(),
        selecionarFoto: () async => null,
        recuperarFotos: () async => LostDataResponse.empty(),
      );
    });
    tearDown(() => model.dispose());

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await model.inicializar();
      await tester.pumpWidget(
        MyApp(
          viewModel: model,
          cameraBuilder: (_) => CameraPage(
            listarCameras: () async => [],
            selecionarDaGaleria: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('contador some quando nao ha pendentes', (tester) async {
      await abrir(tester);
      expect(find.textContaining('aguardando sua resposta'), findsNothing);
    });

    testWidgets('contador abre pendentes e registra passou mal com nota', (
      tester,
    ) async {
      repository.itens.addAll([
        Refeicao(data: hojeAoMeioDia, descricao: 'Feijoada'),
        Refeicao(data: DateTime(2025, 4, 17, 19, 10), descricao: 'Macarrao'),
      ]);
      await abrir(tester);
      expect(find.text('2 refeições aguardando sua resposta'), findsOneWidget);

      await tester.tap(find.text('2 refeições aguardando sua resposta'));
      await tester.pumpAndSettle();
      expect(find.text('Como você se sentiu?'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('17 de abr. de 2025'), findsOneWidget);

      await tester.tap(find.text('Passei mal').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Azia');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(repository.itens[0].passouMal, isTrue);
      expect(repository.itens[0].observacao, 'Azia');
      expect(find.text('Azia'), findsOneWidget);
      // A refeição respondida continua visível nesta tela.
      expect(find.text('Feijoada'), findsOneWidget);

      await tester.tap(find.text('Passei bem em todas'));
      await tester.pumpAndSettle();
      expect(repository.itens[0].passouMal, isTrue);
      expect(repository.itens[1].passouMal, isFalse);
      expect(find.text('Obrigado! Respostas salvas.'), findsOneWidget);
      expect(find.textContaining('aguardando sua resposta'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cancelar a nota nao salva passou mal', (tester) async {
      repository.itens.add(Refeicao(data: hojeAoMeioDia, descricao: 'Sopa'));
      await abrir(tester);
      await tester.tap(find.text('1 refeição aguardando sua resposta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passei mal'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(repository.itens.single.pendente, isTrue);
    });

    testWidgets('notificacao abre Como foi seu dia com refeicoes de hoje', (
      tester,
    ) async {
      repository.itens.addAll([
        Refeicao(data: hojeAoMeioDia, descricao: 'Almoço de hoje'),
        Refeicao(data: DateTime(2025, 4, 17), descricao: 'De outro dia'),
      ]);
      notificacoes.inicial = aberturaFeedback;
      await abrir(tester);
      expect(find.text('Como foi seu dia?'), findsOneWidget);
      expect(find.text('Almoço de hoje'), findsOneWidget);
      expect(find.text('De outro dia'), findsNothing);
      expect(find.text('1 refeição de outro dia sem resposta'), findsOneWidget);

      await tester.tap(find.text('Passei bem o dia todo'));
      await tester.pumpAndSettle();
      expect(repository.itens[0].passouMal, isFalse);
      expect(repository.itens[1].pendente, isTrue);
      expect(find.text('1 refeição aguardando sua resposta'), findsOneWidget);
    });

    testWidgets('notificacao com app aberto e dia sem refeicoes', (
      tester,
    ) async {
      repository.itens.add(
        Refeicao(data: DateTime(2025, 4, 17), descricao: 'Antiga'),
      );
      await abrir(tester);
      notificacoes.controller.add(aberturaFeedback);
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma refeição registrada hoje.'), findsOneWidget);
      await tester.tap(find.text('Responder anteriores (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Como você se sentiu?'), findsOneWidget);
      expect(find.text('Antiga'), findsOneWidget);
    });

    testWidgets('historico mostra icones e detalhe altera sentimento', (
      tester,
    ) async {
      repository.itens.addAll([
        Refeicao(data: hojeAoMeioDia, descricao: 'Frango'),
        Refeicao(
          data: DateTime(2025, 4, 17),
          descricao: 'Peixe',
        ).comFeedback(passouMal: true, observacao: 'Enjoo'),
      ]);
      await abrir(tester);
      await tester.ensureVisible(find.text('Ver Histórico'));
      await tester.tap(find.text('Ver Histórico'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Aguardando resposta'), findsOneWidget);
      expect(find.byTooltip('Passou mal'), findsOneWidget);

      await tester.tap(find.text('Peixe'));
      await tester.pumpAndSettle();
      expect(find.text('Como se sentiu'), findsOneWidget);
      expect(find.text('Passei mal: Enjoo'), findsOneWidget);

      await tester.tap(find.text('Como se sentiu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passei bem'));
      await tester.pumpAndSettle();
      expect(repository.itens[1].passouMal, isFalse);
      expect(repository.itens[1].observacao, isNull);
      expect(find.text('Passei bem'), findsOneWidget);
    });

    testWidgets('Mais permite configurar lembretes e gerar relatorio', (
      tester,
    ) async {
      final relatorio = FakeRelatorio();
      model.dispose();
      model = HomeViewModel(
        repository: repository,
        notificacoes: notificacoes,
        relatorios: relatorio,
        selecionarFoto: () async => null,
        recuperarFotos: () async => LostDataResponse.empty(),
      );
      repository.itens.add(Refeicao(data: hojeAoMeioDia, descricao: 'Sopa'));
      await abrir(tester);
      await model.prepararLembretes();
      await tester.ensureVisible(find.text('Ver Histórico'));
      await tester.tap(find.text('Ver Histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sopa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();

      expect(find.text('Como foi seu dia?'), findsOneWidget);
      expect(find.text('Todos os dias às 20:00'), findsOneWidget);
      expect(find.text('Todos os dias às 12:30'), findsOneWidget);
      expect(find.text('Desligado (19:00)'), findsOneWidget);

      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();
      expect(find.text('Todos os dias às 19:00'), findsOneWidget);
      expect(notificacoes.agendamentos.last.jantar.ativo, isTrue);

      await tester.tap(find.text('Todos os dias às 20:00'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Relatório para o médico'),
        200,
      );
      await tester.tap(find.text('Relatório para o médico'));
      await tester.pumpAndSettle();
      expect(find.text('Incluir fotos'), findsOneWidget);
      expect(find.text('Sempre incluídas'), findsOneWidget);
      await tester.tap(find.text('Incluir refeições sem mal-estar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Incluir fotos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Últimos 7 dias'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não foi possível gerar'), findsNothing);
      expect(relatorio.incluirFotos, isFalse);
      expect(relatorio.incluirSemMalEstar, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Mais avisa quando notificacoes estao bloqueadas', (
      tester,
    ) async {
      notificacoes
        ..permitido = false
        ..concederAoPedir = false;
      await abrir(tester);
      await model.prepararLembretes();
      repository.itens.add(Refeicao(data: hojeAoMeioDia, descricao: 'Sopa'));
      await model.carregar();
      await tester.ensureVisible(find.text('Ver Histórico'));
      await tester.tap(find.text('Ver Histórico'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sopa'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mais opções'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();
      expect(find.text('As notificações estão bloqueadas'), findsOneWidget);

      notificacoes.concederAoPedir = true;
      await tester.tap(find.text('Permitir notificações'));
      await tester.pumpAndSettle();
      expect(find.text('As notificações estão bloqueadas'), findsNothing);
    });
  });
}
