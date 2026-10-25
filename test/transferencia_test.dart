import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:refeicao_diaria/data/repositories/refeicao_repository.dart';
import 'package:refeicao_diaria/data/services/hive_service.dart';
import 'package:refeicao_diaria/data/services/transferencia_service.dart';
import 'package:refeicao_diaria/main.dart';
import 'package:refeicao_diaria/models/arquivo_registros.dart';
import 'package:refeicao_diaria/models/refeicao.dart';
import 'package:refeicao_diaria/ui/viewmodels/home_viewmodel.dart';

class TransferenciaFalsa implements TransferenciaService {
  ArquivoRegistros? arquivo;
  List<Refeicao>? exportadas;
  bool falhar = false;
  Completer<void>? aguardar;

  @override
  Future<ArquivoRegistros?> selecionar() async {
    if (falhar) throw const FormatException('Arquivo inválido.');
    return arquivo;
  }

  @override
  Future<void> exportar(List<Refeicao> refeicoes) async {
    if (falhar) throw const FileSystemException('Sem espaço.');
    exportadas = refeicoes;
    await aguardar?.future;
  }
}

class RepositoryTela extends RefeicaoRepository {
  RepositoryTela(HiveService hive) : super(hiveService: hive);

  final itens = <Refeicao>[];

  @override
  Future<List<Refeicao>> listar() async => List.of(itens);

  @override
  Future<ResultadoImportacao> importar(ArquivoRegistros arquivo) async {
    for (final registro in arquivo.registros) {
      itens.add(registro.refeicao.copyWith(id: itens.length));
    }
    return ResultadoImportacao(
      importados: arquivo.registros.length,
      duplicados: 0,
    );
  }
}

void main() {
  final refeicao = Refeicao(
    data: DateTime(2026, 10, 25, 12, 34, 56),
    descricao: 'Arroz, feijão e salada',
    porcao: 2,
    passouMal: true,
    observacao: 'Dor após o almoço',
  );
  final foto = Uint8List.fromList(
    img.encodePng(img.Image(width: 2, height: 2)),
  );

  group('formato de transferência', () {
    test('preserva todos os campos e fotos sem caminhos ou ids locais', () {
      final original = ArquivoRegistros([
        RegistroArquivo(
          refeicao: refeicao.copyWith(id: 999, caminhoImagem: 'privado/foto'),
          foto: foto,
        ),
        RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: false)),
        RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: null)),
      ]);
      final bytes = codificarRegistros(original);
      expect(utf8.decode(bytes), isNot(contains('privado')));
      final copia = decodificarRegistros(bytes);
      expect(copia.registros, hasLength(3));
      expect(copia.registros.first.refeicao.toMap(), refeicao.toMap());
      expect(copia.registros.first.refeicao.id, isNull);
      expect(copia.registros.first.foto, foto);
      expect(copia.registros[1].refeicao.passouMal, isFalse);
      expect(copia.registros[2].refeicao.pendente, isTrue);
    });

    test('aceita arquivo sem registros', () {
      expect(
        decodificarRegistros(codificarRegistros(ArquivoRegistros([])))
            .registros,
        isEmpty,
      );
    });

    test('rejeita JSON inválido, PDF e formato/versão desconhecidos', () {
      for (final entrada in [
        '%PDF-1.4',
        '{',
        '[]',
        '{}',
        '{"formato":"outro","versao":1,"registros":[]}',
        '{"formato":"meu-almoco","versao":2,"registros":[]}',
      ]) {
        expect(
          () => decodificarRegistros(Uint8List.fromList(utf8.encode(entrada))),
          throwsFormatException,
        );
      }
    });

    test('valida todos os registros antes de aceitar o arquivo', () {
      for (final alteracao in <Map<String, Object?>>[
        {'data': '2026-02-30T12:00:00.000'},
        {'descricao': '  '},
        {'descricao': 1},
        {'porcao': 0},
        {'porcao': 1.5},
        {'passouMal': 'sim'},
        {'observacao': 42},
        {'foto': 'não é base64!'},
        {'foto': ''},
      ]) {
        final item = {...refeicao.toMap(), 'foto': null, ...alteracao};
        final bytes = Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'formato': 'meu-almoco',
              'versao': 1,
              'registros': [refeicao.toMap(), item],
            }),
          ),
        );
        expect(() => decodificarRegistros(bytes), throwsFormatException);
      }
    });

    test('rejeita arquivo maior que 100 MB antes de decodificar', () {
      expect(
        () => decodificarRegistros(Uint8List(limiteArquivoRegistros + 1)),
        throwsFormatException,
      );
    });
  });

  group('persistência e telas', () {
    late Directory pasta;
    late HiveService hive;
    late RefeicaoRepository repository;
    late TransferenciaFalsa servico;
    late HomeViewModel model;

    setUp(() async {
      pasta = await Directory.systemTemp.createTemp('transferencia_teste_');
      hive = HiveService(diretorio: pasta);
      await hive.inicializar();
      repository = RefeicaoRepository(hiveService: hive);
      servico = TransferenciaFalsa();
      model = HomeViewModel(
        repository: repository,
        transferencia: servico,
        selecionarFoto: () async => null,
        recuperarFotos: () async => LostDataResponse.empty(),
      );
    });

    tearDown(() async {
      model.dispose();
      await hive.fechar();
      await pasta.delete(recursive: true);
    });

    test(
      'mescla, preserva dados e fotos e ignora duplicatas repetidas',
      () async {
        await repository.adicionar(refeicao);
        final original = (await repository.listar()).single;
        final arquivo = decodificarRegistros(
          codificarRegistros(
            ArquivoRegistros([
              RegistroArquivo(refeicao: refeicao, foto: foto),
              RegistroArquivo(refeicao: refeicao, foto: foto),
              RegistroArquivo(refeicao: refeicao),
              RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: false)),
              RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: null)),
            ]),
          ),
        );
        final resultado = await model.importarRegistros(arquivo);
        expect(resultado!.importados, 3);
        expect(resultado.duplicados, 2);
        expect(model.refeicoes, hasLength(4));
        expect(model.totalPendentes, 1);
        expect(
          model.refeicoes.firstWhere((r) => r.id == original.id).toMap(),
          original.toMap(),
        );
        final comFoto = model.refeicoes.singleWhere(
          (r) => r.caminhoImagem != null,
        );
        expect(await File(comFoto.caminhoImagem!).readAsBytes(), foto);

        final novamente = await model.importarRegistros(arquivo);
        expect(novamente!.importados, 0);
        expect(novamente.duplicados, 5);
        await hive.fechar();
        hive = HiveService(diretorio: pasta);
        await hive.inicializar();
        final reabertas = await RefeicaoRepository(hiveService: hive).listar();
        expect(reabertas, hasLength(4));
        expect(
          await File(
            reabertas
                .singleWhere((r) => r.caminhoImagem != null)
                .caminhoImagem!,
          ).readAsBytes(),
          foto,
        );
      },
    );

    test('mesma foto em outro caminho não duplica o registro', () async {
      final origem = File('${pasta.path}\\origem.png');
      await origem.writeAsBytes(foto);
      await repository.adicionar(refeicao.copyWith(caminhoImagem: origem.path));
      await origem.delete();
      final resultado = await repository.importar(
        ArquivoRegistros([RegistroArquivo(refeicao: refeicao, foto: foto)]),
      );
      expect(resultado.importados, 0);
      expect(resultado.duplicados, 1);
    });

    test(
      'arquivo exportado preserva dados e foto original em outro armazenamento',
      () async {
        final origem = File('${pasta.path}\\foto.png');
        await origem.writeAsBytes(foto);
        await repository.adicionar(
          refeicao.copyWith(caminhoImagem: origem.path),
        );
        final exportado = await ArquivoTransferenciaService().gerarArquivo(
          await repository.listar(),
          pasta,
        );
        final arquivo = decodificarRegistros(await exportado.readAsBytes());
        await repository.limparTudo();
        final resultado = await repository.importar(arquivo);
        expect(resultado.importados, 1);
        final importada = (await repository.listar()).single;
        expect(importada.descricao, refeicao.descricao);
        expect(importada.data, refeicao.data);
        expect(importada.porcao, refeicao.porcao);
        expect(importada.passouMal, refeicao.passouMal);
        expect(importada.observacao, refeicao.observacao);
        expect(await File(importada.caminhoImagem!).readAsBytes(), foto);
      },
    );

    test(
      'exportar com foto ausente falha sem criar backup incompleto',
      () async {
        await expectLater(
          ArquivoTransferenciaService().gerarArquivo([
            refeicao.copyWith(caminhoImagem: '${pasta.path}\\ausente.png'),
          ], pasta),
          throwsA(isA<FileSystemException>()),
        );
        expect(pasta.listSync().whereType<Directory>(), isEmpty);
      },
    );

    test('falha ao gravar fotos não altera os registros atuais', () async {
      await repository.adicionar(refeicao);
      await File('${pasta.path}\\imagens').writeAsString('bloquear diretório');
      final resultado = await model.importarRegistros(
        ArquivoRegistros([
          RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: false)),
          RegistroArquivo(refeicao: refeicao, foto: foto),
        ]),
      );
      expect(resultado, isNull);
      expect(model.erroTransferencia, isNotNull);
      expect(await repository.listar(), hasLength(1));
      expect((await repository.listar()).single.passouMal, isTrue);
    });

    test('cancelamento e erro ao selecionar não gravam registros', () async {
      expect(await model.selecionarRegistros(), isNull);
      expect(model.erroTransferencia, isNull);
      servico.falhar = true;
      expect(await model.selecionarRegistros(), isNull);
      expect(model.erroTransferencia, 'Arquivo inválido.');
      expect(await repository.listar(), isEmpty);
    });

    test(
      'exporta todos, bloqueia operações simultâneas e informa falhas',
      () async {
        await repository.adicionar(refeicao);
        await repository.adicionar(refeicao.copyWith(data: DateTime(2020)));
        await model.carregar();
        servico.aguardar = Completer<void>();
        final primeira = model.exportarRegistros();
        expect(model.transferindo, isTrue);
        expect(await model.exportarRegistros(), isFalse);
        expect(await model.limparTudo(), isFalse);
        expect(await model.excluir(model.refeicoes.first.id!), isFalse);
        servico.aguardar!.complete();
        expect(await primeira, isTrue);
        expect(servico.exportadas, hasLength(2));
        servico.falhar = true;
        expect(await model.exportarRegistros(), isFalse);
        expect(model.erroTransferencia, isNotNull);
        expect(model.transferindo, isFalse);
      },
    );

    Future<void> abrirConfiguracoes(WidgetTester tester) async {
      model.dispose();
      model = HomeViewModel(
        repository: RepositoryTela(hive),
        transferencia: servico,
        selecionarFoto: () async => null,
        recuperarFotos: () async => LostDataResponse.empty(),
      );
      await model.inicializar();
      await tester.pumpWidget(MyApp(viewModel: model));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Configurações'));
      await tester.tap(find.text('Configurações'));
      await tester.pumpAndSettle();
      expect(find.text('Mais'), findsOneWidget);
    }

    testWidgets('Home abre Mais e relatório oferece os dois formatos', (
      tester,
    ) async {
      await abrirConfiguracoes(tester);
      await tester.scrollUntilVisible(
        find.text('Relatório para o médico'),
        200,
      );
      await tester.tap(find.text('Relatório para o médico'));
      await tester.pumpAndSettle();
      expect(find.text('PDF para o médico'), findsOneWidget);
      expect(find.text('Arquivo para outro celular'), findsOneWidget);
      await tester.tap(find.text('Arquivo para outro celular'));
      await tester.pumpAndSettle();
      expect(find.text('Exportar registros?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(servico.exportadas, isNull);
    });

    testWidgets('confirma antes de exportar todos os registros', (
      tester,
    ) async {
      await abrirConfiguracoes(tester);
      await tester.scrollUntilVisible(find.text('Exportar registros'), 200);
      await tester.tap(find.text('Exportar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exportar'));
      await tester.pumpAndSettle();
      expect(servico.exportadas, isEmpty);
    });

    testWidgets('importação permite cancelar, confirmar e atualiza contador', (
      tester,
    ) async {
      servico.arquivo = ArquivoRegistros([
        RegistroArquivo(refeicao: refeicao.comFeedback(passouMal: null)),
      ]);
      await abrirConfiguracoes(tester);
      await tester.scrollUntilVisible(find.text('Importar registros'), 200);
      await tester.ensureVisible(find.text('Importar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar registros'));
      await tester.pumpAndSettle();
      expect(find.text('Importar registros?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(model.refeicoes, isEmpty);
      await tester.ensureVisible(find.text('Importar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar'));
      await tester.pumpAndSettle();
      expect(model.refeicoes, hasLength(1));
      expect(model.totalPendentes, 1);
      expect(find.textContaining('1 registro(s) importado(s)'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Toque para dizer como se sentiu'), findsOneWidget);
    });

    testWidgets('importação inválida mostra erro sem confirmação', (
      tester,
    ) async {
      servico.falhar = true;
      await abrirConfiguracoes(tester);
      await tester.scrollUntilVisible(find.text('Importar registros'), 200);
      await tester.ensureVisible(find.text('Importar registros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Importar registros'));
      await tester.pumpAndSettle();
      expect(find.text('Arquivo inválido.'), findsOneWidget);
      expect(find.text('Importar registros?'), findsNothing);
    });
  });
}
