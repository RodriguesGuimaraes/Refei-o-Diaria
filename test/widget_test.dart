import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:refeicao_diaria/data/repositories/refeicao_repository.dart';
import 'package:refeicao_diaria/data/services/hive_service.dart';
import 'package:refeicao_diaria/main.dart';
import 'package:refeicao_diaria/models/refeicao.dart';
import 'package:refeicao_diaria/ui/viewmodels/home_viewmodel.dart';
import 'package:refeicao_diaria/ui/views/camera_page.dart';

class WidgetRepository extends RefeicaoRepository {
  WidgetRepository()
    : super(hiveService: HiveService(diretorio: Directory('.')));

  final itens = <Refeicao>[];
  bool falhar = false;

  @override
  Future<List<Refeicao>> listar() async => [
    for (var i = 0; i < itens.length; i++) itens[i].copyWith(id: i),
  ];

  @override
  Future<void> atualizar(Refeicao refeicao) async {
    if (falhar) throw StateError('Falha');
    itens[refeicao.id!] = refeicao;
  }

  @override
  Future<void> excluir(int id) async {
    if (falhar) throw StateError('Falha');
    itens.removeAt(id);
  }

  @override
  Future<void> limparTudo() async {
    if (falhar) throw StateError('Falha');
    itens.clear();
  }

  @override
  Future<void> adicionar(Refeicao refeicao) async {
    if (falhar) throw StateError('Falha');
    itens.add(refeicao);
  }
}

void main() {
  late WidgetRepository repository;
  late HomeViewModel model;

  setUp(() {
    repository = WidgetRepository();
    model = HomeViewModel(
      repository: repository,
      selecionarFoto: () async => null,
      recuperarFotos: () async => LostDataResponse.empty(),
    );
  });
  tearDown(() => model.dispose());

  Future<void> abrir(WidgetTester tester) async {
    await model.inicializar();
    await tester.pumpWidget(
      MyApp(
        viewModel: model,
        cameraBuilder: (_) => CameraPage(
          listarCameras: () async => [],
          selecionarDaGaleria: () async => XFile('foto_teste.jpg'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void telaCelular(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> irParaFormulario(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Registrar Refeição'));
    await tester.tap(find.text('Registrar Refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeria'));
    await tester.pumpAndSettle();
  }

  testWidgets('botao abre tela de camera e fechar nao abre formulario', (
    tester,
  ) async {
    await abrir(tester);
    await tester.tap(find.text('Registrar Refeição'));
    await tester.pumpAndSettle();
    expect(find.text('Registrar refeição'), findsOneWidget);
    expect(find.text('Galeria'), findsOneWidget);
    expect(find.text('Trocar câmera'), findsOneWidget);
    expect(find.byTooltip('Tirar foto'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar Refeição'), findsNothing);
    expect(find.text('Meu Almoço'), findsOneWidget);
    expect(repository.itens, isEmpty);
  });

  testWidgets('foto da galeria segue para o formulario com a imagem', (
    tester,
  ) async {
    await abrir(tester);
    await irParaFormulario(tester);
    expect(find.text('Salvar Refeição'), findsOneWidget);
    expect(model.caminhoImagem, 'foto_teste.jpg');
    await tester.enterText(find.byType(TextFormField), 'Prato');
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.caminhoImagem, 'foto_teste.jpg');
  });

  testWidgets('menu de tres pontos abre Mais e foto pode ser trocada', (
    tester,
  ) async {
    await abrir(tester);
    await irParaFormulario(tester);
    await tester.tap(find.bySemanticsLabel('Alterar foto da refeição'));
    await tester.pumpAndSettle();
    expect(find.text('Trocar câmera'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar Refeição'), findsOneWidget);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Limpar dados'), 200);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
  });

  testWidgets('tocar no historico abre detalhes e permite editar', (
    tester,
  ) async {
    telaCelular(tester);
    repository.itens.add(
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    expect(find.text('Porção'), findsOneWidget);
    expect(find.text('1 refeição'), findsOneWidget);
    expect(find.text('18 de abr. de 2025 • 12:48'), findsOneWidget);

    await tester.tap(find.text('Descrição'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Frango e arroz');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.descricao, 'Frango e arroz');
    expect(find.text('Frango e arroz'), findsNWidgets(2));

    await tester.tap(find.text('Porção'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.porcao, 2);
    expect(find.text('2 refeições'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Alterar foto da refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeria'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.caminhoImagem, 'foto_teste.jpg');

    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Limpar dados'), 200);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar edicao nao altera registro', (tester) async {
    telaCelular(tester);
    repository.itens.add(
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descrição'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Outro');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Alterar foto da refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.descricao, 'Frango');
    expect(repository.itens.single.caminhoImagem, isNull);
  });

  testWidgets('falha ao editar mostra aviso e preserva dados', (tester) async {
    telaCelular(tester);
    repository.itens.add(
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    repository.falhar = true;
    await tester.tap(find.text('Porção'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pump();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível salvar a alteração. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('1 refeição'), findsOneWidget);
    expect(repository.itens.single.porcao, 1);
  });

  Future<void> abrirDetalheFrango(WidgetTester tester) async {
    repository.itens.add(
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir registro'));
    await tester.pumpAndSettle();
  }

  testWidgets('excluir pelo menu remove registro e volta ao historico', (
    tester,
  ) async {
    telaCelular(tester);
    await abrirDetalheFrango(tester);
    expect(find.text('Excluir registro?'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(repository.itens, isEmpty);
    expect(find.text('Ainda não há registros'), findsOneWidget);
    expect(find.text('Registro excluído.'), findsOneWidget);
    expect(find.text('Frango'), findsNothing);
  });

  testWidgets('cancelar exclusao mantem registro', (tester) async {
    telaCelular(tester);
    await abrirDetalheFrango(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.itens, hasLength(1));
    expect(find.text('Porção'), findsOneWidget);
  });

  testWidgets('falha ao excluir mostra aviso e mantem tela', (tester) async {
    telaCelular(tester);
    await abrirDetalheFrango(tester);
    repository.falhar = true;
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(repository.itens, hasLength(1));
    expect(
      find.text('Não foi possível excluir o registro. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Porção'), findsOneWidget);
  });

  testWidgets('historico vazio mostra ilustracao e registra pelo botao', (
    tester,
  ) async {
    telaCelular(tester);
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    final imagem = tester.widget<Image>(find.byType(Image));
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/Prato e talheres.png',
    );
    expect(find.text('Ainda não há registros'), findsOneWidget);
    expect(find.byTooltip('Histórico por calendário'), findsNothing);
    expect(find.text('Todas as refeições'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar Refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeria'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Sopa');
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.descricao, 'Sopa');
    expect(find.text('Todas as refeições'), findsOneWidget);
    expect(find.text('Sopa'), findsOneWidget);
    expect(find.text('Ainda não há registros'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu de detalhes mostra Excluir antes de Mais', (tester) async {
    telaCelular(tester);
    repository.itens.add(
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    final excluir = tester.getTopLeft(find.text('Excluir registro'));
    final mais = tester.getTopLeft(find.text('Mais'));
    expect(excluir.dy, lessThan(mais.dy));
  });

  Future<void> abrirMaisPeloDetalhe(WidgetTester tester) async {
    repository.itens.addAll([
      Refeicao(data: DateTime(2025, 4, 18, 12, 48), descricao: 'Frango'),
      Refeicao(data: DateTime(2025, 4, 17, 19, 10), descricao: 'Macarrao'),
    ]);
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frango'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Limpar dados'), 200);
  }

  testWidgets('tela Mais mostra versao e sobre, sem configuracoes', (
    tester,
  ) async {
    telaCelular(tester);
    await abrirMaisPeloDetalhe(tester);
    expect(find.text('Sobre o app'), findsOneWidget);
    expect(find.text('Versão 1.0.0'), findsOneWidget);
    expect(find.text('Limpar dados'), findsOneWidget);
    expect(find.text('Remover todas as refeições'), findsOneWidget);
    expect(find.text('Configurações'), findsNothing);
    await tester.tap(find.text('Sobre o app'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('limpar dados apaga tudo e volta ao inicio', (tester) async {
    telaCelular(tester);
    await abrirMaisPeloDetalhe(tester);
    await tester.tap(find.text('Limpar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.itens, hasLength(2));

    await tester.tap(find.text('Limpar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar tudo'));
    await tester.pumpAndSettle();
    expect(repository.itens, isEmpty);
    expect(model.refeicoes, isEmpty);
    expect(find.text('Meu Almoço'), findsOneWidget);
    expect(find.text('Todos os dados foram apagados.'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Ainda não há registros'), findsOneWidget);
  });

  testWidgets('falha ao limpar dados avisa e preserva registros', (
    tester,
  ) async {
    telaCelular(tester);
    await abrirMaisPeloDetalhe(tester);
    repository.falhar = true;
    await tester.tap(find.text('Limpar dados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar tudo'));
    await tester.pumpAndSettle();
    expect(repository.itens, hasLength(2));
    expect(
      find.text('Não foi possível limpar os dados. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Limpar dados'), findsOneWidget);
  });

  testWidgets('inicio carrega o icone original e as duas acoes', (
    tester,
  ) async {
    await abrir(tester);
    final imagem = tester.widget<Image>(find.byType(Image));
    expect(
      (imagem.image as AssetImage).assetName,
      'assets/Ícone de refeição — círculo verde.png',
    );
    expect(find.text('Meu Almoço'), findsOneWidget);
    expect(find.text('Registrar Refeição'), findsOneWidget);
    expect(find.text('Ver Histórico'), findsOneWidget);
    expect(find.textContaining('e boa refeição!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final tamanho in [const Size(320, 568), const Size(740, 360)]) {
    testWidgets('inicio acessivel com texto ampliado em $tamanho', (
      tester,
    ) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester);
      await tester.ensureVisible(find.text('Ver Histórico'));
      await tester.tap(find.text('Ver Histórico'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ainda n'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await irParaFormulario(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Meu Almoço'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lista vazia e cadastro com validacao', (tester) async {
    await abrir(tester);
    expect(find.text('Meu Almoço'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ainda n'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await irParaFormulario(tester);
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(find.text('Informe a descrição da refeição.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Arroz e feijao');
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(find.text('Meu Almoço'), findsOneWidget);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz e feijao'), findsOneWidget);
    expect(repository.itens, hasLength(1));
  });

  testWidgets('erro de salvamento preserva texto e permite tentar novamente', (
    tester,
  ) async {
    await abrir(tester);
    await irParaFormulario(tester);
    await tester.enterText(find.byType(TextFormField), 'Lanche');
    repository.falhar = true;
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nao foi possivel salvar a refeicao. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Lanche'), findsOneWidget);
    repository.falhar = false;
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(repository.itens.single.descricao, 'Lanche');
  });

  testWidgets('cancelar nao grava e limpa rascunho', (tester) async {
    await abrir(tester);
    await irParaFormulario(tester);
    await tester.enterText(find.byType(TextFormField), 'Rascunho');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(repository.itens, isEmpty);
    expect(model.descricao, isEmpty);
  });

  testWidgets('tela pequena com texto grande nao apresenta overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    repository.itens.add(
      Refeicao(
        data: DateTime(2026, 10, 24),
        descricao: List.filled(20, 'Uma descricao longa').join(' '),
      ),
    );
    await abrir(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Registrar Refeição'));
    await tester.tap(find.text('Registrar Refeição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Galeria'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Almoco');
    await tester.ensureVisible(find.text('Salvar Refeição'));
    await tester.tap(find.text('Salvar Refeição'));
    await tester.pumpAndSettle();
    expect(repository.itens, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('historico ordena recentes primeiro e abre calendario', (
    tester,
  ) async {
    final hoje = DateTime.now();
    repository.itens.addAll([
      Refeicao(
        data: DateTime(hoje.year, hoje.month, hoje.day, 12, 48),
        descricao: 'Frango de hoje',
      ),
      Refeicao(data: DateTime(2025, 4, 17, 19, 10), descricao: 'Macarrao'),
    ]);
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Todas as refeições'), findsOneWidget);
    expect(find.text('17 de abr. de 2025 • 19:10'), findsOneWidget);
    await tester.tap(find.byTooltip('Histórico por calendário'));
    await tester.pumpAndSettle();
    expect(find.text('Refeições do dia selecionado'), findsOneWidget);
    expect(find.text('Frango de hoje'), findsOneWidget);
    expect(find.text('Macarrao'), findsNothing);
    expect(find.text('12:48'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arquivo ausente mostra alternativa sem quebrar a lista', (
    tester,
  ) async {
    repository.itens.add(
      Refeicao(
        data: DateTime(2026),
        descricao: 'Foto indisponivel',
        caminhoImagem: 'arquivo_inexistente.jpg',
      ),
    );
    await abrir(tester);
    await tester.ensureVisible(find.text('Ver Histórico'));
    await tester.tap(find.text('Ver Histórico'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await File('arquivo_inexistente.jpg').exists();
    });
    await tester.pumpAndSettle();
    expect(find.text('Foto indisponivel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
