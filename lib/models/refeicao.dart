class Refeicao {
  const Refeicao({
    this.id,
    required this.data,
    required this.descricao,
    this.caminhoImagem,
    this.porcao = 1,
    this.passouMal,
    this.observacao,
  });

  /// Chave do registro no armazenamento; não é persistida dentro do mapa.
  final int? id;
  final DateTime data;
  final String descricao;
  final String? caminhoImagem;
  final int porcao;

  /// `null` indica que o usuário ainda não respondeu como se sentiu.
  final bool? passouMal;
  final String? observacao;

  bool get pendente => passouMal == null;

  Refeicao copyWith({
    int? id,
    DateTime? data,
    String? descricao,
    String? caminhoImagem,
    int? porcao,
  }) => Refeicao(
    id: id ?? this.id,
    data: data ?? this.data,
    descricao: descricao ?? this.descricao,
    caminhoImagem: caminhoImagem ?? this.caminhoImagem,
    porcao: porcao ?? this.porcao,
    passouMal: passouMal,
    observacao: observacao,
  );

  Refeicao comFeedback({required bool? passouMal, String? observacao}) {
    final nota = observacao?.trim();
    return Refeicao(
      id: id,
      data: data,
      descricao: descricao,
      caminhoImagem: caminhoImagem,
      porcao: porcao,
      passouMal: passouMal,
      observacao: passouMal == null || nota == null || nota.isEmpty
          ? null
          : nota,
    );
  }

  Map<String, dynamic> toMap() => {
    'data': data.toIso8601String(),
    'descricao': descricao,
    'caminhoImagem': caminhoImagem,
    'porcao': porcao,
    'passouMal': passouMal,
    'observacao': observacao,
  };

  factory Refeicao.fromMap(Map<dynamic, dynamic> map, {int? id}) => Refeicao(
    id: id,
    data: DateTime.parse(map['data'] as String),
    descricao: map['descricao'] as String,
    caminhoImagem: map['caminhoImagem'] as String?,
    porcao: (map['porcao'] as int?) ?? 1,
    passouMal: map['passouMal'] as bool?,
    observacao: map['observacao'] as String?,
  );
}
