// lib/models/setor_model.dart (NOVO ARQUIVO CORRIGIDO)

class Setor {
  final int? id;
  
  // Chaves estrangeiras que ligam este setor a um bairro específico de uma atividade
  final String bairroId; 
  final int bairroAtividadeId;
  
  // Propriedades do Setor
  final String nome; // Ex: "001", "15-A", "Q-27"
  final double? areaHa; // Área em hectares, pode ser útil para densidade
  
  // Campo para exibição na UI (ex: "Bairro Centro"), não salvo no banco
  final String? bairroNome; 

  Setor({
    this.id,
    required this.bairroId,
    required this.bairroAtividadeId,
    required this.nome,
    this.areaHa,
    this.bairroNome,
  });

  // copyWith é útil para criar cópias do objeto com pequenas alterações
  Setor copyWith({
    int? id,
    String? bairroId,
    int? bairroAtividadeId,
    String? nome,
    double? areaHa,
    String? bairroNome,
  }) {
    return Setor(
      id: id ?? this.id,
      bairroId: bairroId ?? this.bairroId,
      bairroAtividadeId: bairroAtividadeId ?? this.bairroAtividadeId,
      nome: nome ?? this.nome,
      areaHa: areaHa ?? this.areaHa,
      bairroNome: bairroNome ?? this.bairroNome,
    );
  }

  // Mapeia o objeto para um formato que o SQFlite entende
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bairroId': bairroId,
      'bairroAtividadeId': bairroAtividadeId,
      'nome': nome,
      'areaHa': areaHa,
    };
  }

  // Cria um objeto Setor a partir de um mapa vindo do SQFlite
  factory Setor.fromMap(Map<String, dynamic> map) {
    return Setor(
      id: map['id'],
      bairroId: map['bairroId'] ?? map['fazendaId'], // Mantém compatibilidade com nomes antigos
      bairroAtividadeId: map['bairroAtividadeId'] ?? map['fazendaAtividadeId'], // Mantém compatibilidade
      nome: map['nome'],
      areaHa: map['areaHa'],
      bairroNome: map['bairroNome'] ?? map['fazendaNome'], // Mantém compatibilidade
    );
  }
}