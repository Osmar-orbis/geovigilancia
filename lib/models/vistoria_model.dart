// lib/models/vistoria_model.dart (VERSÃO CORRIGIDA)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geovigilancia/models/foco_model.dart'; 

enum StatusVisita {
  realizada(Icons.check_circle_outline, Colors.green),
  fechada(Icons.lock_outline, Colors.orange),
  recusa(Icons.do_not_disturb_on_outlined, Colors.red),
  pendente(Icons.pending_outlined, Colors.grey);

  final IconData icone;
  final Color cor;
  
  const StatusVisita(this.icone, this.cor);
}

class Vistoria {
  int? dbId;
  int? setorId;
  DateTime? dataColeta;
  
  final String? idBairro;
  final String? nomeBairro;
  final String? nomeSetor;

  final String? identificadorImovel;
  final String tipoImovel;
  
  // <<< MUDANÇA PRINCIPAL AQUI: 'final' removido de 'resultado' >>>
  String? resultado; 
  
  final String? observacao;
  final double? latitude;
  final double? longitude;
  StatusVisita status;
  bool exportada;
  bool isSynced;
  List<String> photoPaths;
  List<Foco> focos;

  Vistoria({
    this.dbId,
    this.setorId,
    this.identificadorImovel,
    required this.tipoImovel,
    this.resultado,
    this.idBairro,
    this.nomeBairro,
    this.nomeSetor,
    this.observacao,
    this.latitude,
    this.longitude,
    this.dataColeta,
    this.status = StatusVisita.pendente,
    this.exportada = false,
    this.isSynced = false,
    this.photoPaths = const [],
    this.focos = const [],
  });

  // O método copyWith já lida com a alteração do 'resultado' corretamente.
  Vistoria copyWith({
    int? dbId,
    int? setorId,
    String? idBairro,
    String? nomeBairro,
    String? nomeSetor,
    String? identificadorImovel,
    String? tipoImovel,
    String? resultado,
    String? observacao,
    double? latitude,
    double? longitude,
    DateTime? dataColeta,
    StatusVisita? status,
    bool? exportada,
    bool? isSynced,
    List<String>? photoPaths,
    List<Foco>? focos,
  }) {
    return Vistoria(
      dbId: dbId ?? this.dbId,
      setorId: setorId ?? this.setorId,
      idBairro: idBairro ?? this.idBairro,
      nomeBairro: nomeBairro ?? this.nomeBairro,
      nomeSetor: nomeSetor ?? this.nomeSetor,
      identificadorImovel: identificadorImovel ?? this.identificadorImovel,
      tipoImovel: tipoImovel ?? this.tipoImovel,
      resultado: resultado ?? this.resultado, // Esta linha agora funciona sem problemas
      observacao: observacao ?? this.observacao,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataColeta: dataColeta ?? this.dataColeta,
      status: status ?? this.status,
      exportada: exportada ?? this.exportada,
      isSynced: isSynced ?? this.isSynced,
      photoPaths: photoPaths ?? this.photoPaths,
      focos: focos ?? this.focos,
    );
  }

  // O resto do arquivo (toMap, fromMap) não precisa de alterações.
  Map<String, dynamic> toMap() {
    return {
      'id': dbId,
      'setorId': setorId,
      'idBairro': idBairro,
      'nomeBairro': nomeBairro,
      'nomeSetor': nomeSetor,
      'identificadorImovel': identificadorImovel,
      'tipoImovel': tipoImovel,
      'resultado': resultado,
      'observacao': observacao,
      'latitude': latitude,
      'longitude': longitude,
      'dataColeta': dataColeta?.toIso8601String(),
      'statusVisita': status.name, 
      'exportada': exportada ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'photoPaths': jsonEncode(photoPaths),
    };
  }

  factory Vistoria.fromMap(Map<String, dynamic> map) {
    List<String> paths = [];
    if (map['photoPaths'] != null) {
      try {
        paths = List<String>.from(jsonDecode(map['photoPaths']));
      } catch (e) {
        debugPrint("Erro ao decodificar photoPaths: $e");
      }
    }

    return Vistoria(
      dbId: map['id'],
      setorId: map['setorId'],
      idBairro: map['idBairro'],
      nomeBairro: map['nomeBairro'],
      nomeSetor: map['nomeSetor'],
      identificadorImovel: map['identificadorImovel'],
      tipoImovel: map['tipoImovel'] ?? '',
      resultado: map['resultado'],
      observacao: map['observacao'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      dataColeta: map['dataColeta'] != null ? DateTime.parse(map['dataColeta']) : null,
      status: StatusVisita.values.firstWhere(
            (e) => e.name == (map['statusVisita'] ?? map['status']),
        orElse: () => StatusVisita.pendente,
      ),
      exportada: map['exportada'] == 1,
      isSynced: map['isSynced'] == 1,
      photoPaths: paths,
    );
  }
}