import 'dart:io';

import 'package:hive/hive.dart';

class HiveService {
  HiveService({required this.diretorio});

  final Directory diretorio;
  Box<Map>? _box;
  Box<dynamic>? _configuracoes;
  Future<void>? _inicializacao;

  Box<Map> get box {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Armazenamento nao inicializado.');
    }
    return box;
  }

  Box<dynamic> get configuracoes {
    final box = _configuracoes;
    if (box == null || !box.isOpen) {
      throw StateError('Armazenamento nao inicializado.');
    }
    return box;
  }

  Future<void> inicializar() {
    return _inicializacao ??= _abrir();
  }

  Future<void> _abrir() async {
    try {
      await diretorio.create(recursive: true);
      _box = await Hive.openBox<Map>('refeicoes', path: diretorio.path);
      _configuracoes = await Hive.openBox<dynamic>(
        'configuracoes',
        path: diretorio.path,
      );
    } catch (_) {
      await _box?.close();
      _box = null;
      _inicializacao = null;
      rethrow;
    }
  }

  Future<void> fechar() async {
    await _box?.close();
    await _configuracoes?.close();
    _box = null;
    _configuracoes = null;
    _inicializacao = null;
  }
}
