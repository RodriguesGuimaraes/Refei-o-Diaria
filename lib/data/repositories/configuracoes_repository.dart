import '../../models/configuracoes_lembretes.dart';
import '../services/hive_service.dart';

class ConfiguracoesRepository {
  ConfiguracoesRepository({required this.hiveService});

  static const _chaveLembretes = 'lembretes';

  final HiveService hiveService;

  ConfiguracoesLembretes carregarLembretes() => ConfiguracoesLembretes.fromMap(
    hiveService.configuracoes.get(_chaveLembretes),
  );

  Future<void> salvarLembretes(ConfiguracoesLembretes configuracoes) =>
      hiveService.configuracoes.put(_chaveLembretes, configuracoes.toMap());
}
