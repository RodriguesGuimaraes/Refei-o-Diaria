import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../models/refeicao.dart';

abstract class RelatorioService {
  Future<void> compartilhar({
    required List<Refeicao> refeicoes,
    required DateTime inicio,
    required DateTime fim,
    bool incluirFotos = true,
    bool incluirSemMalEstar = false,
  });
}

/// Retorna a foto já reduzida em JPEG, ou `null` se não puder ser lida.
typedef CarregarFoto = Future<Uint8List?> Function(String caminho);

/// Reduz a foto para [largura] pixels e recomprime, para o PDF ficar leve.
Future<Uint8List?> gerarMiniatura(String caminho, {int largura = 300}) async {
  try {
    final arquivo = File(caminho);
    if (!await arquivo.exists()) return null;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      await arquivo.readAsBytes(),
    );
    // O decodificador nativo é rápido e já aplica a rotação gravada pela câmera.
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) => w > largura
          ? ui.TargetImageSize(width: largura)
          : const ui.TargetImageSize(),
    );
    final quadro = await codec.getNextFrame();
    final imagem = quadro.image;
    final largura0 = imagem.width;
    final altura = imagem.height;
    final rgba = await imagem.toByteData(format: ui.ImageByteFormat.rawRgba);
    imagem.dispose();
    codec.dispose();
    if (rgba == null) return null;
    final pixels = rgba.buffer;
    return await Isolate.run(
      () => img.encodeJpg(
        img.Image.fromBytes(
          width: largura0,
          height: altura,
          bytes: pixels,
          numChannels: 4,
        ),
        quality: 70,
      ),
    );
  } catch (_) {
    return null;
  }
}

String _data(DateTime data) =>
    '${data.day.toString().padLeft(2, '0')}/'
    '${data.month.toString().padLeft(2, '0')}/${data.year}';

String _hora(DateTime data) =>
    '${data.hour.toString().padLeft(2, '0')}:'
    '${data.minute.toString().padLeft(2, '0')}';

String _sentimento(Refeicao refeicao) => switch (refeicao.passouMal) {
  true => 'Passou mal',
  false => 'Passou bem',
  null => 'Sem resposta',
};

const _verde = PdfColor.fromInt(0xFF2A7A5C);
const _vermelho = PdfColor.fromInt(0xFFC62828);
const _fundoVermelho = PdfColor.fromInt(0xFFFDECEA);
const _tamanhoFoto = 64.0;

/// Gera o PDF com as refeições em ordem cronológica.
///
/// As refeições em que passou mal sempre entram; as demais (passou bem ou
/// sem resposta) só com [incluirSemMalEstar]. O resumo sempre conta todas.
/// Sem [carregarFoto] o relatório sai sem a coluna de fotos.
Future<Uint8List> gerarRelatorioPdf({
  required List<Refeicao> refeicoes,
  required DateTime inicio,
  required DateTime fim,
  CarregarFoto? carregarFoto,
  bool incluirSemMalEstar = false,
}) async {
  final ordenadas = [...refeicoes]..sort((a, b) => a.data.compareTo(b.data));
  final mal = ordenadas.where((r) => r.passouMal == true).toList();
  final bem = ordenadas.where((r) => r.passouMal == false).length;
  final pendentes = ordenadas.where((r) => r.pendente).length;
  final listadas = incluirSemMalEstar ? ordenadas : mal;

  final fotos = <Refeicao, pw.MemoryImage>{};
  if (carregarFoto != null) {
    // Uma de cada vez para não ocupar muita memória no celular.
    for (final refeicao in listadas) {
      final caminho = refeicao.caminhoImagem;
      if (caminho == null) continue;
      final bytes = await carregarFoto(caminho);
      if (bytes != null) fotos[refeicao] = pw.MemoryImage(bytes);
    }
  }

  final documento = pw.Document(
    title: 'Relatório de refeições',
    author: 'Meu Almoço',
  );
  documento.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (contexto) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${contexto.pageNumber} de ${contexto.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ),
      build: (contexto) => [
        pw.Text(
          'Relatório de refeições',
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            color: _verde,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Período: ${_data(inicio)} a ${_data(fim)}'),
        pw.Text(
          'Gerado pelo aplicativo Meu Almoço em ${_data(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Resumo',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Refeições registradas: ${ordenadas.length}'),
        pw.Text(
          'Passou mal: ${mal.length}',
          style: pw.TextStyle(color: _vermelho, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('Passou bem: $bem'),
        pw.Text('Sem resposta: $pendentes'),
        if (incluirSemMalEstar && mal.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Refeições após as quais passou mal',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _vermelho,
            ),
          ),
          pw.SizedBox(height: 4),
          for (final refeicao in mal)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '- ${_data(refeicao.data)} ${_hora(refeicao.data)}: '
                '${refeicao.descricao}'
                '${refeicao.observacao == null ? '' : ' (${refeicao.observacao})'}',
              ),
            ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          incluirSemMalEstar
              ? 'Todas as refeições'
              : 'Refeições após as quais passou mal',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: incluirSemMalEstar ? null : _vermelho,
          ),
        ),
        pw.SizedBox(height: 6),
        if (listadas.isEmpty)
          pw.Text(
            incluirSemMalEstar
                ? 'Nenhuma refeição registrada no período.'
                : 'Não passou mal depois de nenhuma refeição no período.',
          )
        else
          _tabela(listadas, carregarFoto == null ? null : fotos),
      ],
    ),
  );
  return documento.save();
}

pw.Widget _tabela(
  List<Refeicao> refeicoes,
  Map<Refeicao, pw.MemoryImage>? fotos,
) {
  const estiloCabecalho = pw.TextStyle(
    color: PdfColors.white,
    fontSize: 10,
    fontWeight: pw.FontWeight.bold,
  );
  const estiloCelula = pw.TextStyle(fontSize: 9);
  pw.Widget celula(String texto, {pw.TextStyle estilo = estiloCelula}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(texto, style: estilo),
      );

  pw.Widget foto(Refeicao refeicao) {
    final imagem = fotos![refeicao];
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: imagem == null
          ? pw.Container(
              width: _tamanhoFoto,
              height: _tamanhoFoto,
              alignment: pw.Alignment.center,
              color: PdfColors.grey200,
              child: pw.Text(
                'Sem foto',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                ),
              ),
            )
          : pw.ClipRRect(
              horizontalRadius: 4,
              verticalRadius: 4,
              child: pw.Image(
                imagem,
                width: _tamanhoFoto,
                height: _tamanhoFoto,
                fit: pw.BoxFit.cover,
              ),
            ),
    );
  }

  final comFotos = fotos != null;
  final cabecalhos = [
    if (comFotos) 'Foto',
    'Data',
    'Hora',
    'Refeição',
    'Porção',
    'Como se sentiu',
    'Observação',
  ];
  final larguras = <pw.TableColumnWidth>[
    if (comFotos) const pw.FixedColumnWidth(_tamanhoFoto + 6),
    const pw.FixedColumnWidth(54),
    const pw.FixedColumnWidth(32),
    const pw.FlexColumnWidth(3),
    const pw.FixedColumnWidth(38),
    const pw.FixedColumnWidth(58),
    const pw.FlexColumnWidth(2),
  ];
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
    columnWidths: larguras.asMap(),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _verde),
        children: [
          for (final texto in cabecalhos)
            celula(texto, estilo: estiloCabecalho),
        ],
      ),
      for (final refeicao in refeicoes)
        pw.TableRow(
          decoration: refeicao.passouMal == true
              ? const pw.BoxDecoration(color: _fundoVermelho)
              : null,
          children: [
            if (comFotos) foto(refeicao),
            celula(_data(refeicao.data)),
            celula(_hora(refeicao.data)),
            celula(refeicao.descricao),
            celula('${refeicao.porcao}'),
            celula(
              _sentimento(refeicao),
              estilo: refeicao.passouMal == true
                  ? pw.TextStyle(
                      fontSize: 9,
                      color: _vermelho,
                      fontWeight: pw.FontWeight.bold,
                    )
                  : estiloCelula,
            ),
            celula(refeicao.observacao ?? ''),
          ],
        ),
    ],
  );
}

class PdfRelatorioService implements RelatorioService {
  @override
  Future<void> compartilhar({
    required List<Refeicao> refeicoes,
    required DateTime inicio,
    required DateTime fim,
    bool incluirFotos = true,
    bool incluirSemMalEstar = false,
  }) async {
    final bytes = await gerarRelatorioPdf(
      refeicoes: refeicoes,
      inicio: inicio,
      fim: fim,
      carregarFoto: incluirFotos ? gerarMiniatura : null,
      incluirSemMalEstar: incluirSemMalEstar,
    );
    final pasta = await getTemporaryDirectory();
    final arquivo = File(
      path.join(
        pasta.path,
        'relatorio_refeicoes_${_data(fim).replaceAll('/', '-')}.pdf',
      ),
    );
    await arquivo.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(arquivo.path, mimeType: 'application/pdf')],
        subject: 'Relatório de refeições',
        text:
            'Relatório de refeições de ${_data(inicio)} a ${_data(fim)} '
            '(Meu Almoço).',
      ),
    );
  }
}
