import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:refeicao_diaria/data/repositories/refeicao_repository.dart';
import 'package:refeicao_diaria/data/services/hive_service.dart';
import 'package:refeicao_diaria/models/refeicao.dart';

void main() {
  test('modelo preserva data, descricao e imagem no armazenamento', () {
    final refeicao = Refeicao(
      data: DateTime(2026, 10, 24),
      descricao: 'Arroz e feijao',
      caminhoImagem: 'imagens/foto.jpg',
    );
    final restaurada = Refeicao.fromMap(refeicao.toMap());

    expect(restaurada.data, refeicao.data);
    expect(restaurada.descricao, refeicao.descricao);
    expect(restaurada.caminhoImagem, refeicao.caminhoImagem);
  });

  test('modelo aceita refeicao sem foto', () {
    final refeicao = Refeicao(data: DateTime(2026), descricao: 'Almoco');
    expect(Refeicao.fromMap(refeicao.toMap()).caminhoImagem, isNull);
  });

  group('persistencia', () {
    late Directory diretorio;
    late HiveService hive;
    late RefeicaoRepository repository;

    setUp(() async {
      diretorio = await Directory.systemTemp.createTemp('refeicoes_test_');
      hive = HiveService(diretorio: diretorio);
      await hive.inicializar();
      repository = RefeicaoRepository(hiveService: hive);
    });

    tearDown(() async {
      await hive.fechar();
      await diretorio.delete(recursive: true);
    });

    test('preserva registros apos reabrir e ordena por data', () async {
      await repository.adicionar(
        Refeicao(data: DateTime(2026, 10, 24), descricao: '  Almoco  '),
      );
      await repository.adicionar(
        Refeicao(data: DateTime(2026, 10, 23), descricao: 'Jantar'),
      );
      await repository.adicionar(
        Refeicao(data: DateTime(2026, 10, 24), descricao: 'Lanche'),
      );
      await hive.fechar();
      await hive.inicializar();
      final refeicoes = await repository.listar();
      expect(refeicoes.map((item) => item.descricao), [
        'Lanche',
        'Almoco',
        'Jantar',
      ]);
      expect(refeicoes.first.caminhoImagem, isNull);
    });

    test(
      'copia fotos com destinos unicos e persiste caminho relativo',
      () async {
        final origem = File(path.join(diretorio.path, 'origem.jpg'));
        await origem.writeAsBytes([1, 2, 3]);
        for (var indice = 0; indice < 2; indice++) {
          await repository.adicionar(
            Refeicao(
              data: DateTime(2026),
              descricao: 'Foto $indice',
              caminhoImagem: origem.path,
            ),
          );
        }
        await origem.delete();
        expect(
          path.isRelative(hive.box.values.first['caminhoImagem'] as String),
          isTrue,
        );
        await hive.fechar();
        await hive.inicializar();
        final refeicoes = await repository.listar();
        expect(refeicoes[0].caminhoImagem, isNot(refeicoes[1].caminhoImagem));
        for (final refeicao in refeicoes) {
          expect(await File(refeicao.caminhoImagem!).readAsBytes(), [1, 2, 3]);
        }
      },
    );

    test('falha de copia nao grava e remove pasta incompleta', () async {
      await expectLater(
        repository.adicionar(
          Refeicao(
            data: DateTime(2026),
            descricao: 'Foto ausente',
            caminhoImagem: path.join(diretorio.path, 'ausente.jpg'),
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await repository.listar(), isEmpty);
      expect(
        await Directory(path.join(diretorio.path, 'imagens')).list().length,
        0,
      );
    });

    test('falha do Hive remove somente a nova copia', () async {
      final origem = File(path.join(diretorio.path, 'origem.jpg'));
      await origem.writeAsBytes([1]);
      await hive.fechar();
      await expectLater(
        repository.adicionar(
          Refeicao(
            data: DateTime(2026),
            descricao: 'Almoco',
            caminhoImagem: origem.path,
          ),
        ),
        throwsStateError,
      );
      expect(await origem.exists(), isTrue);
      expect(
        await Directory(path.join(diretorio.path, 'imagens')).list().length,
        0,
      );
    });

    test('rejeita descricao vazia', () async {
      await expectLater(
        repository.adicionar(Refeicao(data: DateTime(2026), descricao: '  ')),
        throwsArgumentError,
      );
      expect(await repository.listar(), isEmpty);
    });

    test('atualiza campos, troca foto e remove a copia antiga', () async {
      final origem = File(path.join(diretorio.path, 'origem.jpg'));
      await origem.writeAsBytes([1]);
      await repository.adicionar(
        Refeicao(
          data: DateTime(2026),
          descricao: 'Almoco',
          caminhoImagem: origem.path,
        ),
      );
      final original = (await repository.listar()).single;
      expect(original.id, isNotNull);
      expect(original.porcao, 1);

      final nova = File(path.join(diretorio.path, 'nova.jpg'));
      await nova.writeAsBytes([2]);
      await repository.atualizar(
        original.copyWith(
          descricao: '  Jantar  ',
          porcao: 3,
          data: DateTime(2026, 5, 1, 19, 30),
          caminhoImagem: nova.path,
        ),
      );
      await hive.fechar();
      await hive.inicializar();
      final atualizada = (await repository.listar()).single;
      expect(atualizada.id, original.id);
      expect(atualizada.descricao, 'Jantar');
      expect(atualizada.porcao, 3);
      expect(atualizada.data, DateTime(2026, 5, 1, 19, 30));
      expect(await File(atualizada.caminhoImagem!).readAsBytes(), [2]);
      expect(await File(original.caminhoImagem!).exists(), isFalse);
    });

    test('atualizar sem trocar foto mantem a mesma copia', () async {
      final origem = File(path.join(diretorio.path, 'origem.jpg'));
      await origem.writeAsBytes([1]);
      await repository.adicionar(
        Refeicao(
          data: DateTime(2026),
          descricao: 'Almoco',
          caminhoImagem: origem.path,
        ),
      );
      final original = (await repository.listar()).single;
      await repository.atualizar(original.copyWith(descricao: 'Outro'));
      final atualizada = (await repository.listar()).single;
      expect(atualizada.caminhoImagem, original.caminhoImagem);
      expect(await File(atualizada.caminhoImagem!).readAsBytes(), [1]);
    });

    test('falha ao copiar nova foto preserva registro original', () async {
      await repository.adicionar(
        Refeicao(data: DateTime(2026), descricao: 'Almoco'),
      );
      final original = (await repository.listar()).single;
      await expectLater(
        repository.atualizar(
          original.copyWith(
            descricao: 'Outro',
            caminhoImagem: path.join(diretorio.path, 'ausente.jpg'),
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
      final depois = (await repository.listar()).single;
      expect(depois.descricao, 'Almoco');
      expect(depois.caminhoImagem, isNull);
    });

    test('excluir remove registro e a copia da foto', () async {
      final origem = File(path.join(diretorio.path, 'origem.jpg'));
      await origem.writeAsBytes([1]);
      await repository.adicionar(
        Refeicao(
          data: DateTime(2026),
          descricao: 'Almoco',
          caminhoImagem: origem.path,
        ),
      );
      await repository.adicionar(
        Refeicao(data: DateTime(2025), descricao: 'Fica'),
      );
      final alvo = (await repository.listar()).first;
      await repository.excluir(alvo.id!);
      await hive.fechar();
      await hive.inicializar();
      final restantes = await repository.listar();
      expect(restantes.map((r) => r.descricao), ['Fica']);
      expect(await File(alvo.caminhoImagem!).exists(), isFalse);
      expect(await origem.exists(), isTrue);
    });

    test('limpar tudo remove registros e fotos copiadas', () async {
      final origem = File(path.join(diretorio.path, 'origem.jpg'));
      await origem.writeAsBytes([1]);
      await repository.adicionar(
        Refeicao(
          data: DateTime(2026),
          descricao: 'Com foto',
          caminhoImagem: origem.path,
        ),
      );
      await repository.adicionar(
        Refeicao(data: DateTime(2025), descricao: 'Sem foto'),
      );
      await repository.limparTudo();
      await hive.fechar();
      await hive.inicializar();
      expect(await repository.listar(), isEmpty);
      expect(
        await Directory(path.join(diretorio.path, 'imagens')).exists(),
        isFalse,
      );
      expect(await origem.exists(), isTrue);
      await repository.adicionar(
        Refeicao(
          data: DateTime(2026),
          descricao: 'Nova',
          caminhoImagem: origem.path,
        ),
      );
      expect((await repository.listar()).single.descricao, 'Nova');
    });

    test('registro antigo sem porcao assume uma refeicao', () async {
      await hive.box.add({
        'data': DateTime(2025).toIso8601String(),
        'descricao': 'Antigo',
        'caminhoImagem': null,
      });
      expect((await repository.listar()).single.porcao, 1);
    });
  });
}
