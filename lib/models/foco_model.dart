// lib/models/foco_model.dart (VERSÃO ATUALIZADA)

class Foco {
  int? id;
  int vistoriaId;

  final String tipoCriadouro;
  final bool larvasEncontradas;
  final String? tratamentoRealizado;
  
  // <<< NOVO CAMPO ADICIONADO AQUI >>>
  final String? fotoUrl;             // Caminho para a foto específica do foco

  Foco({
    this.id,
    required this.vistoriaId,
    required this.tipoCriadouro,
    required this.larvasEncontradas,
    this.tratamentoRealizado,
    this.fotoUrl, // <<< ADICIONADO AO CONSTRUTOR >>>
  });

  Foco copyWith({
    int? id,
    int? vistoriaId,
    String? tipoCriadouro,
    bool? larvasEncontradas,
    String? tratamentoRealizado,
    String? fotoUrl, // <<< ADICIONADO AO COPYWITH >>>
  }) {
    return Foco(
      id: id ?? this.id,
      vistoriaId: vistoriaId ?? this.vistoriaId,
      tipoCriadouro: tipoCriadouro ?? this.tipoCriadouro,
      larvasEncontradas: larvasEncontradas ?? this.larvasEncontradas,
      tratamentoRealizado: tratamentoRealizado ?? this.tratamentoRealizado,
      fotoUrl: fotoUrl ?? this.fotoUrl, // <<< ADICIONADO AO COPYWITH >>>
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vistoriaId': vistoriaId,
      'tipoCriadouro': tipoCriadouro,
      'larvasEncontradas': larvasEncontradas ? 1 : 0,
      'tratamentoRealizado': tratamentoRealizado,
      'fotoUrl': fotoUrl, // <<< ADICIONADO AO MAPA >>>
    };
  }

  factory Foco.fromMap(Map<String, dynamic> map) {
    return Foco(
      id: map['id'],
      vistoriaId: map['vistoriaId'],
      tipoCriadouro: map['tipoCriadouro'] ?? '',
      larvasEncontradas: map['larvasEncontradas'] == 1,
      tratamentoRealizado: map['tratamentoRealizado'],
      fotoUrl: map['fotoUrl'], // <<< ADICIONADO AO FACTORY >>>
    );
  }
}