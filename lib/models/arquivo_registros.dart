import 'dart:typed_data';

import 'refeicao.dart';

class RegistroArquivo {
  const RegistroArquivo({required this.refeicao, this.foto});

  final Refeicao refeicao;
  final Uint8List? foto;
}

class ArquivoRegistros {
  ArquivoRegistros(Iterable<RegistroArquivo> registros)
    : registros = List.unmodifiable(registros);

  final List<RegistroArquivo> registros;
}

class ResultadoImportacao {
  const ResultadoImportacao({
    required this.importados,
    required this.duplicados,
  });

  final int importados;
  final int duplicados;
}
