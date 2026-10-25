import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/repositories/configuracoes_repository.dart';
import '../../data/repositories/refeicao_repository.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/relatorio_service.dart';
import '../../data/services/transferencia_service.dart';
import '../../models/arquivo_registros.dart';
import '../../models/configuracoes_lembretes.dart';
import '../../models/refeicao.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required this.repository,
    this.configuracoesRepository,
    NotificationService? notificacoes,
    this.relatorios,
    this.transferencia,
    Future<XFile?> Function()? selecionarFoto,
    Future<LostDataResponse> Function()? recuperarFotos,
  }) : notificacoes = notificacoes ?? const NotificacoesDesativadas(),
       _selecionarFoto =
           selecionarFoto ??
           (() => ImagePicker().pickImage(source: ImageSource.gallery)),
       _recuperarFotos = recuperarFotos ?? ImagePicker().retrieveLostData;

  final RefeicaoRepository repository;
  final ConfiguracoesRepository? configuracoesRepository;
  final NotificationService notificacoes;
  final RelatorioService? relatorios;
  final TransferenciaService? transferencia;
  final Future<XFile?> Function() _selecionarFoto;
  final Future<LostDataResponse> Function() _recuperarFotos;
  List<Refeicao> _refeicoes = [];
  bool _descartado = false;

  List<Refeicao> get refeicoes => List.unmodifiable(_refeicoes);
  bool carregando = false;
  bool salvando = false;
  bool atualizando = false;
  bool selecionandoFoto = false;
  String? erroCarregamento;
  String? erroFormulario;
  DateTime data = DateTime.now();
  String descricao = '';
  String? caminhoImagem;
  bool respondendo = false;
  bool gerandoRelatorio = false;
  bool transferindo = false;
  String? erroTransferencia;

  bool get ocupadoComRegistros =>
      carregando ||
      salvando ||
      atualizando ||
      respondendo ||
      gerandoRelatorio ||
      transferindo;

  Future<T?> _transferir<T>(Future<T> Function() operacao) async {
    if (_descartado || ocupadoComRegistros) return null;
    transferindo = true;
    erroTransferencia = null;
    _notificar();
    try {
      return await operacao();
    } on FormatException catch (erro) {
      erroTransferencia = erro.message;
      return null;
    } catch (erro, stack) {
      debugPrint('Falha na transferência de registros: $erro\n$stack');
      erroTransferencia =
          'Não foi possível transferir os registros. '
          'Verifique o arquivo, as fotos e o espaço disponível.';
      return null;
    } finally {
      transferindo = false;
      _notificar();
    }
  }

  TransferenciaService get _transferencia {
    final servico = transferencia;
    if (servico == null) {
      throw StateError('Transferência de registros indisponível.');
    }
    return servico;
  }

  Future<bool> exportarRegistros() async =>
      await _transferir(() async {
        await _transferencia.exportar(await repository.listar());
        return true;
      }) ??
      false;

  Future<ArquivoRegistros?> selecionarRegistros() =>
      _transferir<ArquivoRegistros?>(() => _transferencia.selecionar());

  Future<ResultadoImportacao?> importarRegistros(ArquivoRegistros arquivo) =>
      _transferir(() async {
        final resultado = await repository.importar(arquivo);
        await carregar();
        return resultado;
      });
  ConfiguracoesLembretes lembretes = const ConfiguracoesLembretes();

  /// `null` enquanto a permissão de notificação ainda não foi verificada.
  bool? notificacoesPermitidas;

  /// Refeições (de qualquer dia) sem resposta sobre como a pessoa se sentiu.
  List<Refeicao> get pendentes =>
      _refeicoes.where((refeicao) => refeicao.pendente).toList();

  int get totalPendentes => _refeicoes.where((r) => r.pendente).length;

  List<Refeicao> refeicoesDoDia(DateTime dia) => _refeicoes
      .where(
        (r) =>
            r.data.year == dia.year &&
            r.data.month == dia.month &&
            r.data.day == dia.day,
      )
      .toList();

  Future<void> inicializar() async {
    selecionandoFoto = true;
    _notificar();
    await carregar();
    if (_descartado) return;
    try {
      final resposta = await _recuperarFotos();
      if (_descartado) return;
      if (resposta.exception != null) {
        erroFormulario = 'Nao foi possivel recuperar a foto. Tente novamente.';
      } else if (resposta.files?.isNotEmpty ?? false) {
        caminhoImagem = resposta.files!.first.path;
      }
    } catch (_) {
      if (!_descartado) {
        erroFormulario = 'Nao foi possivel recuperar a foto. Tente novamente.';
      }
    } finally {
      selecionandoFoto = false;
      _notificar();
    }
  }

  Future<void> carregar() async {
    if (carregando || _descartado) return;
    carregando = true;
    erroCarregamento = null;
    _notificar();
    try {
      final resultado = await repository.listar();
      if (!_descartado) _refeicoes = resultado;
    } catch (_) {
      if (!_descartado) {
        erroCarregamento = 'Nao foi possivel carregar as refeicoes.';
      }
    } finally {
      carregando = false;
      _notificar();
    }
  }

  void alterarData(DateTime valor) {
    if (salvando) return;
    data = valor;
    _notificar();
  }

  void alterarDescricao(String valor) {
    if (salvando) return;
    descricao = valor;
  }

  Future<void> selecionarImagem() async {
    if (selecionandoFoto || salvando || _descartado) return;
    selecionandoFoto = true;
    erroFormulario = null;
    _notificar();
    try {
      final foto = await _selecionarFoto();
      if (!_descartado && foto != null) caminhoImagem = foto.path;
    } catch (_) {
      if (!_descartado) {
        erroFormulario = 'Nao foi possivel selecionar a foto. Tente novamente.';
      }
    } finally {
      selecionandoFoto = false;
      _notificar();
    }
  }

  void definirFoto(String caminho) {
    if (salvando) return;
    caminhoImagem = caminho;
    erroFormulario = null;
    _notificar();
  }

  void removerImagem() {
    if (salvando || selecionandoFoto) return;
    caminhoImagem = null;
    _notificar();
  }

  void limparRascunho() {
    if (salvando || selecionandoFoto) return;
    data = DateTime.now();
    descricao = '';
    caminhoImagem = null;
    erroFormulario = null;
    _notificar();
  }

  Future<bool> salvar() async {
    if (salvando || selecionandoFoto || transferindo || _descartado) {
      return false;
    }
    if (descricao.trim().isEmpty) {
      erroFormulario = 'Informe a descricao da refeicao.';
      _notificar();
      return false;
    }
    salvando = true;
    erroFormulario = null;
    _notificar();
    try {
      await repository.adicionar(
        Refeicao(
          data: data,
          descricao: descricao.trim(),
          caminhoImagem: caminhoImagem,
        ),
      );
      if (_descartado) return true;
      descricao = '';
      caminhoImagem = null;
      data = DateTime.now();
      await carregar();
      return true;
    } catch (_) {
      if (!_descartado) {
        erroFormulario = 'Nao foi possivel salvar a refeicao. Tente novamente.';
      }
      return false;
    } finally {
      salvando = false;
      _notificar();
    }
  }

  Future<bool> atualizar(Refeicao refeicao) async {
    if (atualizando || transferindo || _descartado) return false;
    atualizando = true;
    _notificar();
    try {
      await repository.atualizar(refeicao);
      if (_descartado) return true;
      await carregar();
      return true;
    } catch (_) {
      return false;
    } finally {
      atualizando = false;
      _notificar();
    }
  }

  Future<bool> excluir(int id) async {
    if (atualizando || transferindo || _descartado) return false;
    atualizando = true;
    _notificar();
    try {
      await repository.excluir(id);
      if (_descartado) return true;
      await carregar();
      return true;
    } catch (_) {
      return false;
    } finally {
      atualizando = false;
      _notificar();
    }
  }

  Future<bool> limparTudo() async {
    if (atualizando || salvando || transferindo || _descartado) return false;
    atualizando = true;
    _notificar();
    try {
      await repository.limparTudo();
      if (_descartado) return true;
      await carregar();
      return true;
    } catch (_) {
      return false;
    } finally {
      atualizando = false;
      _notificar();
    }
  }

  Future<bool> responder(
    Refeicao refeicao, {
    required bool? passouMal,
    String? observacao,
  }) => _gravarRespostas([
    refeicao.comFeedback(passouMal: passouMal, observacao: observacao),
  ]);

  /// Marca como "passou bem" todas as refeições ainda sem resposta da lista.
  Future<bool> passeiBemEmTodas(List<Refeicao> refeicoes) => _gravarRespostas([
    for (final refeicao in refeicoes)
      if (refeicao.pendente) refeicao.comFeedback(passouMal: false),
  ]);

  Future<bool> _gravarRespostas(List<Refeicao> respostas) async {
    if (respondendo || transferindo || _descartado) return false;
    if (respostas.isEmpty) return true;
    respondendo = true;
    _notificar();
    try {
      await repository.responder(respostas);
      if (_descartado) return true;
      await carregar();
      return true;
    } catch (_) {
      return false;
    } finally {
      respondendo = false;
      _notificar();
    }
  }

  /// Carrega as preferências, pede permissão se preciso e agenda os lembretes.
  Future<void> prepararLembretes() async {
    try {
      final salvos = configuracoesRepository?.carregarLembretes();
      if (salvos != null && !_descartado) lembretes = salvos;
      await notificacoes.inicializar();
      final algumAtivo = TipoLembrete.values.any(
        (tipo) => lembretes.obter(tipo).ativo,
      );
      var permitido = await notificacoes.permissaoConcedida();
      if (!permitido && algumAtivo) {
        permitido = await notificacoes.solicitarPermissao();
      }
      if (_descartado) return;
      notificacoesPermitidas = permitido;
      _notificar();
      await notificacoes.agendar(lembretes);
    } catch (_) {
      // Sem lembretes o restante do aplicativo continua funcionando.
    }
  }

  Future<void> verificarPermissao() async {
    try {
      final permitido = await notificacoes.permissaoConcedida();
      if (_descartado || permitido == notificacoesPermitidas) return;
      notificacoesPermitidas = permitido;
      _notificar();
    } catch (_) {}
  }

  Future<bool> alterarLembrete(TipoLembrete tipo, Lembrete lembrete) async {
    if (_descartado) return false;
    final anteriores = lembretes;
    lembretes = lembretes.alterar(tipo, lembrete);
    _notificar();
    try {
      if (lembrete.ativo && notificacoesPermitidas != true) {
        final permitido = await notificacoes.solicitarPermissao();
        if (_descartado) return false;
        notificacoesPermitidas = permitido;
        _notificar();
      }
      await configuracoesRepository?.salvarLembretes(lembretes);
      await notificacoes.agendar(lembretes);
      return true;
    } catch (_) {
      if (!_descartado) {
        lembretes = anteriores;
        _notificar();
      }
      return false;
    }
  }

  /// Gera e compartilha o relatório dos últimos [dias] (ou de todo o período).
  Future<bool> compartilharRelatorio({
    int? dias,
    bool incluirFotos = true,
    bool incluirSemMalEstar = false,
  }) async {
    final servico = relatorios;
    if (servico == null || gerandoRelatorio || _descartado) return false;
    final hoje = DateTime.now();
    final fimDoDia = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final DateTime inicio;
    if (dias != null) {
      inicio = DateTime(hoje.year, hoje.month, hoje.day - dias + 1);
    } else if (_refeicoes.isEmpty) {
      inicio = DateTime(hoje.year, hoje.month, hoje.day);
    } else {
      final primeira = _refeicoes
          .map((r) => r.data)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      inicio = DateTime(primeira.year, primeira.month, primeira.day);
    }
    final selecionadas = _refeicoes
        .where((r) => !r.data.isBefore(inicio) && r.data.isBefore(fimDoDia))
        .toList();
    gerandoRelatorio = true;
    _notificar();
    try {
      await servico.compartilhar(
        refeicoes: selecionadas,
        inicio: inicio,
        fim: hoje,
        incluirFotos: incluirFotos,
        incluirSemMalEstar: incluirSemMalEstar,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      gerandoRelatorio = false;
      _notificar();
    }
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
