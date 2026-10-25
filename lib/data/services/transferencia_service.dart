import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/arquivo_registros.dart';
import '../../models/refeicao.dart';

const limiteArquivoRegistros = 100 * 1024 * 1024;

Uint8List codificarRegistros(ArquivoRegistros arquivo) {
  final bytes = Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'formato': 'meu-almoco',
        'versao': 1,
        'registros': [
          for (final registro in arquivo.registros)
            {
              ...(registro.refeicao.toMap()..remove('caminhoImagem')),
              'foto': registro.foto == null
                  ? null
                  : base64Encode(registro.foto!),
            },
        ],
      }),
    ),
  );
  if (bytes.length > limiteArquivoRegistros) {
    throw const FormatException('O arquivo excede o limite de 100 MB.');
  }
  return bytes;
}

ArquivoRegistros decodificarRegistros(Uint8List bytes) {
  if (bytes.length > limiteArquivoRegistros) {
    throw const FormatException('O arquivo excede o limite de 100 MB.');
  }
  final Object? json = jsonDecode(utf8.decode(bytes));
  if (json is! Map<String, dynamic> ||
      json['formato'] != 'meu-almoco' ||
      json['versao'] != 1 ||
      json['registros'] is! List) {
    throw const FormatException('Arquivo incompatível com o Meu Almoço.');
  }
  final registros = <RegistroArquivo>[];
  for (final Object? item in json['registros'] as List) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Registro inválido no arquivo.');
    }
    final data = item['data'];
    final descricao = item['descricao'];
    final porcao = item['porcao'];
    final passouMal = item['passouMal'];
    final observacao = item['observacao'];
    final foto = item['foto'];
    final dataValida = data is String ? DateTime.tryParse(data) : null;
    if (dataValida == null ||
        dataValida.toIso8601String() != data ||
        descricao is! String ||
        descricao.trim().isEmpty ||
        porcao is! int ||
        porcao < 1 ||
        (passouMal != null && passouMal is! bool) ||
        (observacao != null && observacao is! String) ||
        (foto != null && foto is! String)) {
      throw const FormatException('Registro inválido no arquivo.');
    }
    final imagem = foto == null ? null : base64Decode(foto as String);
    if (imagem != null && imagem.isEmpty) {
      throw const FormatException('Foto vazia no arquivo.');
    }
    registros.add(
      RegistroArquivo(
        refeicao: Refeicao(
          data: dataValida,
          descricao: descricao,
          porcao: porcao,
          passouMal: passouMal as bool?,
          observacao: observacao as String?,
        ),
        foto: imagem,
      ),
    );
  }
  return ArquivoRegistros(registros);
}

abstract class TransferenciaService {
  Future<void> exportar(List<Refeicao> refeicoes);
  Future<ArquivoRegistros?> selecionar();
}

class ArquivoTransferenciaService implements TransferenciaService {
  Future<File> gerarArquivo(List<Refeicao> refeicoes, Directory cache) async {
    final registros = <RegistroArquivo>[];
    var tamanhoFotos = 0;
    for (final refeicao in refeicoes) {
      Uint8List? foto;
      if (refeicao.caminhoImagem case final caminho?) {
        final arquivo = File(caminho);
        tamanhoFotos += await arquivo.length();
        if (tamanhoFotos > limiteArquivoRegistros * 3 ~/ 4) {
          throw const FormatException('As fotos excedem o limite de 100 MB.');
        }
        foto = await arquivo.readAsBytes();
      }
      registros.add(RegistroArquivo(refeicao: refeicao, foto: foto));
    }
    final bytes = await compute(
      codificarRegistros,
      ArquivoRegistros(registros),
    );
    final pasta = await cache.createTemp('exportacao_');
    final arquivo = File(path.join(pasta.path, 'registros.meualmoco.json'));
    // O compartilhamento pode continuar depois que o app voltar ao primeiro
    // plano; o arquivo permanece no cache temporário gerenciado pelo Android.
    await arquivo.writeAsBytes(bytes, flush: true);
    return arquivo;
  }

  @override
  Future<void> exportar(List<Refeicao> refeicoes) async {
    final arquivo = await gerarArquivo(
      refeicoes,
      await getTemporaryDirectory(),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(arquivo.path, mimeType: 'application/json')],
        subject: 'Registros do Meu Almoço',
        text:
            'Importe este arquivo no Meu Almoço para transferir os registros. '
            'Contém informações de saúde e fotos: compartilhe apenas com pessoas de confiança.',
      ),
    );
  }

  @override
  Future<ArquivoRegistros?> selecionar() async {
    final arquivo = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Registros do Meu Almoço',
          extensions: ['json'],
          mimeTypes: ['application/json', 'application/octet-stream'],
        ),
      ],
    );
    if (arquivo == null) return null;
    if (await arquivo.length() > limiteArquivoRegistros) {
      throw const FormatException('O arquivo excede o limite de 100 MB.');
    }
    return compute(decodificarRegistros, await arquivo.readAsBytes());
  }
}
