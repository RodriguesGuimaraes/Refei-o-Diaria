class Lembrete {
  const Lembrete({
    required this.ativo,
    required this.hora,
    required this.minuto,
  });

  final bool ativo;
  final int hora;
  final int minuto;

  Lembrete copyWith({bool? ativo, int? hora, int? minuto}) => Lembrete(
    ativo: ativo ?? this.ativo,
    hora: hora ?? this.hora,
    minuto: minuto ?? this.minuto,
  );

  String get horario =>
      '${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
    'ativo': ativo,
    'hora': hora,
    'minuto': minuto,
  };

  static Lembrete fromMap(Object? map, Lembrete padrao) {
    if (map is! Map) return padrao;
    final hora = map['hora'];
    final minuto = map['minuto'];
    final ativo = map['ativo'];
    return Lembrete(
      ativo: ativo is bool ? ativo : padrao.ativo,
      hora: hora is int && hora >= 0 && hora < 24 ? hora : padrao.hora,
      minuto: minuto is int && minuto >= 0 && minuto < 60
          ? minuto
          : padrao.minuto,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Lembrete &&
      other.ativo == ativo &&
      other.hora == hora &&
      other.minuto == minuto;

  @override
  int get hashCode => Object.hash(ativo, hora, minuto);
}

enum TipoLembrete { noite, almoco, jantar }

class ConfiguracoesLembretes {
  const ConfiguracoesLembretes({
    this.noite = noitePadrao,
    this.almoco = almocoPadrao,
    this.jantar = jantarPadrao,
  });

  static const noitePadrao = Lembrete(ativo: true, hora: 20, minuto: 0);
  static const almocoPadrao = Lembrete(ativo: true, hora: 12, minuto: 30);
  static const jantarPadrao = Lembrete(ativo: false, hora: 19, minuto: 0);

  /// Pergunta "Como foi seu dia?".
  final Lembrete noite;

  /// Lembretes para registrar a refeição.
  final Lembrete almoco;
  final Lembrete jantar;

  Lembrete obter(TipoLembrete tipo) => switch (tipo) {
    TipoLembrete.noite => noite,
    TipoLembrete.almoco => almoco,
    TipoLembrete.jantar => jantar,
  };

  ConfiguracoesLembretes alterar(TipoLembrete tipo, Lembrete lembrete) =>
      ConfiguracoesLembretes(
        noite: tipo == TipoLembrete.noite ? lembrete : noite,
        almoco: tipo == TipoLembrete.almoco ? lembrete : almoco,
        jantar: tipo == TipoLembrete.jantar ? lembrete : jantar,
      );

  Map<String, dynamic> toMap() => {
    'noite': noite.toMap(),
    'almoco': almoco.toMap(),
    'jantar': jantar.toMap(),
  };

  factory ConfiguracoesLembretes.fromMap(Object? map) {
    if (map is! Map) return const ConfiguracoesLembretes();
    return ConfiguracoesLembretes(
      noite: Lembrete.fromMap(map['noite'], noitePadrao),
      almoco: Lembrete.fromMap(map['almoco'], almocoPadrao),
      jantar: Lembrete.fromMap(map['jantar'], jantarPadrao),
    );
  }
}
