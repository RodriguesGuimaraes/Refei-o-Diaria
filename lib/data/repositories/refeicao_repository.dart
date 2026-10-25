import 'dart:io';

import 'package:path/path.dart' as path;

import '../../models/refeicao.dart';
import '../services/hive_service.dart';

class RefeicaoRepository {
  RefeicaoRepository({required this.hiveService});

  final HiveService hiveService;

  Future<List<Refeicao>> listar() async {
    final registros = hiveService.box.toMap().entries.toList();
    registros.sort((primeiro, segundo) {
      final data = DateTime.parse(segundo.value['data'] as String)
          .compareTo(DateTime.parse(primeiro.value['data'] as String));
      return data != 0
          ? data
          : (segundo.key as int).compareTo(primeiro.key as int);
    });
    return registros.map((registro) {
      final refeicao = Refeicao.fromMap(
        registro.value,
        id: registro.key as int,
      );
      return Refeicao(
        id: refeicao.id,
        data: refeicao.data,
        descricao: refeicao.descricao,
        porcao: refeicao.porcao,
        passouMal: refeicao.passouMal,
        observacao: refeicao.observacao,
        caminhoImagem: refeicao.caminhoImagem == null
            ? null
            : path.join(hiveService.diretorio.path, refeicao.caminhoImagem!),
      );
    }).toList();
  }

  /// Grava apenas o feedback (passou mal / observação) das refeições.
  Future<void> responder(List<Refeicao> respostas) async {
    final atualizados = <int, Map>{};
    for (final resposta in respostas) {
      final id = resposta.id;
      if (id == null) throw ArgumentError('Refeicao sem identificador.');
      final armazenado = hiveService.box.get(id);
      if (armazenado == null) throw StateError('Refeicao nao encontrada.');
      final normalizada = resposta.comFeedback(
        passouMal: resposta.passouMal,
        observacao: resposta.observacao,
      );
      atualizados[id] = Map<dynamic, dynamic>.from(armazenado)
        ..['passouMal'] = normalizada.passouMal
        ..['observacao'] = normalizada.observacao;
    }
    if (atualizados.isNotEmpty) await hiveService.box.putAll(atualizados);
  }

  Directory get _imagens =>
      Directory(path.join(hiveService.diretorio.path, 'imagens'));

  Future<Directory> _copiarFoto(String origem) async {
    await _imagens.create(recursive: true);
    final pasta = await _imagens.createTemp('refeicao_');
    try {
      await File(origem).copy(path.join(pasta.path, 'foto'));
    } catch (_) {
      await pasta.delete(recursive: true);
      rethrow;
    }
    return pasta;
  }

  String _relativo(Directory pasta) => path.relative(
    path.join(pasta.path, 'foto'),
    from: hiveService.diretorio.path,
  );

  String _validarDescricao(Refeicao refeicao) {
    final descricao = refeicao.descricao.trim();
    if (descricao.isEmpty) {
      throw ArgumentError('Informe a descricao da refeicao.');
    }
    return descricao;
  }

  Future<void> atualizar(Refeicao refeicao) async {
    final id = refeicao.id;
    if (id == null) throw ArgumentError('Refeicao sem identificador.');
    final descricao = _validarDescricao(refeicao);
    final armazenado = hiveService.box.get(id);
    if (armazenado == null) throw StateError('Refeicao nao encontrada.');

    final relativoAtual = armazenado['caminhoImagem'] as String?;
    final absolutoAtual = relativoAtual == null
        ? null
        : path.join(hiveService.diretorio.path, relativoAtual);
    var relativoNovo = relativoAtual;
    Directory? pastaNova;
    try {
      if (refeicao.caminhoImagem != absolutoAtual) {
        if (refeicao.caminhoImagem == null) {
          relativoNovo = null;
        } else {
          pastaNova = await _copiarFoto(refeicao.caminhoImagem!);
          relativoNovo = _relativo(pastaNova);
        }
      }
      await hiveService.box.put(
        id,
        Refeicao(
              data: refeicao.data,
              descricao: descricao,
              caminhoImagem: relativoNovo,
              porcao: refeicao.porcao,
            )
            .comFeedback(
              passouMal: refeicao.passouMal,
              observacao: refeicao.observacao,
            )
            .toMap(),
      );
    } catch (erro, stack) {
      try {
        await pastaNova?.delete(recursive: true);
      } catch (_) {}
      Error.throwWithStackTrace(erro, stack);
    }

    if (absolutoAtual != null && relativoNovo != relativoAtual) {
      final pastaAntiga = path.dirname(absolutoAtual);
      if (path.isWithin(_imagens.path, pastaAntiga)) {
        try {
          await Directory(pastaAntiga).delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<void> excluir(int id) async {
    final armazenado = hiveService.box.get(id);
    if (armazenado == null) return;
    await hiveService.box.delete(id);
    final relativo = armazenado['caminhoImagem'] as String?;
    if (relativo == null) return;
    final pasta = path.dirname(path.join(hiveService.diretorio.path, relativo));
    if (path.isWithin(_imagens.path, pasta)) {
      try {
        await Directory(pasta).delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> limparTudo() async {
    await hiveService.box.clear();
    try {
      if (await _imagens.exists()) await _imagens.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> adicionar(Refeicao refeicao) async {
    final descricao = _validarDescricao(refeicao);

    Directory? pastaFoto;
    try {
      String? caminhoRelativo;
      if (refeicao.caminhoImagem != null) {
        pastaFoto = await _copiarFoto(refeicao.caminhoImagem!);
        caminhoRelativo = _relativo(pastaFoto);
      }
      await hiveService.box.add(
        Refeicao(
              data: refeicao.data,
              descricao: descricao,
              caminhoImagem: caminhoRelativo,
              porcao: refeicao.porcao,
            )
            .comFeedback(
              passouMal: refeicao.passouMal,
              observacao: refeicao.observacao,
            )
            .toMap(),
      );
    } catch (erro, stack) {
      try {
        await pastaFoto?.delete(recursive: true);
      } catch (_) {
        Error.throwWithStackTrace(erro, stack);
      }
      Error.throwWithStackTrace(erro, stack);
    }
  }
}
