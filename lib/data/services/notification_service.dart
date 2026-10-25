import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_dados;
import 'package:timezone/timezone.dart' as tz;

import '../../models/configuracoes_lembretes.dart';

/// Conteúdo enviado junto com a notificação para decidir qual tela abrir.
const aberturaFeedback = 'feedback';
const aberturaRegistro = 'registrar';

abstract class NotificationService {
  /// Emite o payload quando o usuário toca em uma notificação com o app aberto.
  Stream<String> get aberturas;

  Future<void> inicializar();

  /// Payload da notificação que abriu o app, entregue apenas uma vez.
  String? consumirAberturaInicial();

  Future<bool> permissaoConcedida();

  Future<bool> solicitarPermissao();

  Future<void> agendar(ConfiguracoesLembretes configuracoes);

  Future<void> abrirConfiguracoesNotificacao();

  Future<void> abrirConfiguracoesBateria();
}

/// Implementação vazia usada quando as notificações não estão disponíveis.
class NotificacoesDesativadas implements NotificationService {
  const NotificacoesDesativadas();

  @override
  Stream<String> get aberturas => const Stream.empty();

  @override
  Future<void> inicializar() async {}

  @override
  String? consumirAberturaInicial() => null;

  @override
  Future<bool> permissaoConcedida() async => true;

  @override
  Future<bool> solicitarPermissao() async => true;

  @override
  Future<void> agendar(ConfiguracoesLembretes configuracoes) async {}

  @override
  Future<void> abrirConfiguracoesNotificacao() async {}

  @override
  Future<void> abrirConfiguracoesBateria() async {}
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _sistema = MethodChannel('meu_almoco/sistema');
  static const _ids = {
    TipoLembrete.noite: 1,
    TipoLembrete.almoco: 2,
    TipoLembrete.jantar: 3,
  };

  final FlutterLocalNotificationsPlugin _plugin;
  final _aberturas = StreamController<String>.broadcast();
  Future<void>? _inicializacao;
  String? _aberturaInicial;

  @override
  Stream<String> get aberturas => _aberturas.stream;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> inicializar() => _inicializacao ??= _iniciar();

  Future<void> _iniciar() async {
    tz_dados.initializeTimeZones();
    try {
      final fuso = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(fuso.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notificacao'),
      ),
      onDidReceiveNotificationResponse: (resposta) {
        final payload = resposta.payload;
        if (payload != null) _aberturas.add(payload);
      },
    );
    final detalhes = await _plugin.getNotificationAppLaunchDetails();
    if (detalhes?.didNotificationLaunchApp ?? false) {
      _aberturaInicial = detalhes!.notificationResponse?.payload;
    }
  }

  @override
  String? consumirAberturaInicial() {
    final payload = _aberturaInicial;
    _aberturaInicial = null;
    return payload;
  }

  @override
  Future<bool> permissaoConcedida() async =>
      await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> solicitarPermissao() async {
    if (await permissaoConcedida()) return true;
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> agendar(ConfiguracoesLembretes configuracoes) async {
    await inicializar();
    for (final tipo in TipoLembrete.values) {
      final id = _ids[tipo]!;
      await _plugin.cancel(id: id);
      final lembrete = configuracoes.obter(tipo);
      if (!lembrete.ativo) continue;
      final (titulo, texto, payload) = switch (tipo) {
        TipoLembrete.noite => (
          'Como foi seu dia?',
          'Conte se passou mal depois de alguma refeição de hoje.',
          aberturaFeedback,
        ),
        TipoLembrete.almoco => (
          'Hora do almoço',
          'Não esqueça de fotografar e registrar o que vai comer.',
          aberturaRegistro,
        ),
        TipoLembrete.jantar => (
          'Hora do jantar',
          'Não esqueça de fotografar e registrar o que vai comer.',
          aberturaRegistro,
        ),
      };
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: _proximo(lembrete),
        title: titulo,
        body: texto,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            tipo == TipoLembrete.noite ? 'como_foi_o_dia' : 'registrar',
            tipo == TipoLembrete.noite
                ? 'Como foi seu dia'
                : 'Lembrete de refeição',
            channelDescription: tipo == TipoLembrete.noite
                ? 'Pergunta diária se passou mal após as refeições'
                : 'Lembra de registrar o almoço e o jantar',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  tz.TZDateTime _proximo(Lembrete lembrete) {
    final agora = tz.TZDateTime.now(tz.local);
    var data = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      lembrete.hora,
      lembrete.minuto,
    );
    if (!data.isAfter(agora)) {
      data = tz.TZDateTime(
        tz.local,
        agora.year,
        agora.month,
        agora.day + 1,
        lembrete.hora,
        lembrete.minuto,
      );
    }
    return data;
  }

  @override
  Future<void> abrirConfiguracoesNotificacao() =>
      _sistema.invokeMethod<void>('abrirConfiguracoesNotificacao');

  @override
  Future<void> abrirConfiguracoesBateria() =>
      _sistema.invokeMethod<void>('abrirConfiguracoesBateria');
}
