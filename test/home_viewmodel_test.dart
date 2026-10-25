import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:refeicao_diaria/data/repositories/refeicao_repository.dart';
import 'package:refeicao_diaria/data/services/hive_service.dart';
import 'package:refeicao_diaria/models/refeicao.dart';
import 'package:refeicao_diaria/ui/viewmodels/home_viewmodel.dart';

class MemoryRepository extends RefeicaoRepository {
  MemoryRepository()
    : super(hiveService: HiveService(diretorio: Directory('.')));

  final itens = <Refeicao>[];
  bool falhar = false;
  Completer<void>? pendente;

  @override
  Future<List<Refeicao>> listar() async {
    if (falhar) throw StateError('Falha');
    return List.of(itens);
  }

  @override
  Future<void> adicionar(Refeicao refeicao) async {
    await pendente?.future;
    if (falhar) throw StateError('Falha');
    itens.add(refeicao);
  }
}

void main() {
  late MemoryRepository repository;
  late HomeViewModel model;

  setUp(() {
    repository = MemoryRepository();
    model = HomeViewModel(
      repository: repository,
      selecionarFoto: () async => null,
      recuperarFotos: () async => LostDataResponse.empty(),
    );
  });
  tearDown(() => model.dispose());

  test(
    'inicializa lista vazia sem plugins e bloqueia edicao da lista',
    () async {
      await model.inicializar();
      expect(model.refeicoes, isEmpty);
      expect(model.erroCarregamento, isNull);
      expect(model.selecionandoFoto, isFalse);
      expect(() => model.refeicoes.clear(), throwsUnsupportedError);
    },
  );

  test('valida descricao antes de salvar', () async {
    model.alterarDescricao('  ');
    expect(await model.salvar(), isFalse);
    expect(repository.itens, isEmpty);
    expect(model.erroFormulario, isNotNull);
  });

  test('salva, atualiza lista e limpa rascunho', () async {
    model.alterarDescricao('  Almoco  ');
    model.alterarData(DateTime(2026, 10, 24));
    expect(await model.salvar(), isTrue);
    expect(model.refeicoes.single.descricao, 'Almoco');
    expect(model.refeicoes.single.data, DateTime(2026, 10, 24));
    expect(model.descricao, isEmpty);
  });

  test('erro preserva rascunho e permite nova tentativa', () async {
    repository.falhar = true;
    model.alterarDescricao('Almoco');
    model.caminhoImagem = 'foto.jpg';
    expect(await model.salvar(), isFalse);
    expect(model.descricao, 'Almoco');
    expect(model.caminhoImagem, 'foto.jpg');
    expect(model.erroFormulario, isNotNull);
    repository.falhar = false;
    expect(await model.salvar(), isTrue);
    expect(repository.itens, hasLength(1));
  });

  test('bloqueia envio duplo e alteracoes durante salvamento', () async {
    repository.pendente = Completer<void>();
    model.alterarDescricao('Almoco');
    final primeira = model.salvar();
    expect(await model.salvar(), isFalse);
    model.alterarDescricao('Outro');
    model.limparRascunho();
    expect(model.descricao, 'Almoco');
    repository.pendente!.complete();
    expect(await primeira, isTrue);
    expect(repository.itens, hasLength(1));
  });

  test('cancelamento da galeria preserva foto existente', () async {
    model.caminhoImagem = 'anterior.jpg';
    await model.selecionarImagem();
    expect(model.caminhoImagem, 'anterior.jpg');
    expect(model.erroFormulario, isNull);
  });

  test('falha no carregamento permite nova tentativa', () async {
    repository.falhar = true;
    await model.carregar();
    expect(model.erroCarregamento, isNotNull);
    repository.falhar = false;
    await model.carregar();
    expect(model.erroCarregamento, isNull);
  });

  test('recupera foto apos encerramento da atividade sem salvar', () async {
    final recuperado = HomeViewModel(
      repository: repository,
      recuperarFotos: () async => LostDataResponse(
        files: [XFile('recuperada.jpg')],
        type: RetrieveType.image,
      ),
    );
    addTearDown(recuperado.dispose);
    await recuperado.inicializar();
    expect(recuperado.caminhoImagem, 'recuperada.jpg');
    expect(repository.itens, isEmpty);
  });

  test('erros de selecao e recuperacao sao apresentados', () async {
    final comErro = HomeViewModel(
      repository: repository,
      selecionarFoto: () async => throw PlatformException(code: 'galeria'),
      recuperarFotos: () async =>
          LostDataResponse(exception: PlatformException(code: 'recuperacao')),
    );
    addTearDown(comErro.dispose);
    await comErro.inicializar();
    expect(comErro.erroFormulario, isNotNull);
    await comErro.selecionarImagem();
    expect(comErro.erroFormulario, isNotNull);
    expect(comErro.selecionandoFoto, isFalse);
  });

  test('conclusao assincrona apos dispose nao notifica', () async {
    final foto = Completer<XFile?>();
    final descartado = HomeViewModel(
      repository: repository,
      selecionarFoto: () => foto.future,
    );
    final selecao = descartado.selecionarImagem();
    descartado.dispose();
    foto.complete(XFile('foto.jpg'));
    await selecao;
    expect(descartado.caminhoImagem, isNull);
  });
}
