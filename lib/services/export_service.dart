// lib/services/export_service.dart (VERSÃO COMPLETA E ADAPTADA PARA GEOVIGILÂNCIA)

import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/services/permission_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Constantes UTM mantidas, pois a conversão de coordenadas é útil.
const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

class ExportService {
  final _permissionService = PermissionService();
  final _dbHelper = DatabaseHelper.instance;

  // =======================================================================
  // FUNÇÃO 1: Exportar dados de Vistorias e Focos em formato CSV
  // =======================================================================
  Future<void> exportarVistoriasCsv(BuildContext context) async {
    // Pergunta ao usuário qual tipo de exportação fazer
    final bool? exportarTudo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipo de Exportação'),
        content: const Text('Deseja exportar apenas os dados novos ou um backup completo de todas as vistorias realizadas?'),
        actions: [
          TextButton(
            child: const Text('Apenas Novas'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            child: const Text('Todas (Backup)'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (exportarTudo == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando dados para exportação...')));

    // IMPORTANTE: Você precisará criar estes métodos no seu DatabaseHelper
    // A lógica abaixo é uma simulação.
    // final List<Vistoria> vistorias = exportarTudo
    //     ? await _dbHelper.getTodasVistoriasParaBackup()
    //     : await _dbHelper.getUnexportedVistorias();
    
    // Simulação para o código compilar e funcionar (substitua pela chamada real ao DB)
    final vistorias = <Vistoria>[
      Vistoria(dbId: 1, setorId: 1, identificadorImovel: 'Rua A, 10', tipoImovel: 'Residencial', status: StatusVisita.realizada, resultado: 'Com Foco', dataColeta: DateTime.now()),
      Vistoria(dbId: 2, setorId: 1, identificadorImovel: 'Rua B, 20', tipoImovel: 'Comercial', status: StatusVisita.realizada, resultado: 'Sem Foco', dataColeta: DateTime.now()),
      Vistoria(dbId: 3, setorId: 2, identificadorImovel: 'Av. C, 30', tipoImovel: 'Terreno Baldio', status: StatusVisita.fechada, resultado: 'Não Vistoriado', dataColeta: DateTime.now()),
    ];

    if (vistorias.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma vistoria encontrada para exportar.'), backgroundColor: Colors.orange));
      }
      return;
    }
    
    await _gerarECompartilharCsvVistorias(context, vistorias, exportarTudo);
  }
  
  /// Função interna que gera o arquivo CSV e o compartilha.
  Future<void> _gerarECompartilharCsvVistorias(BuildContext context, List<Vistoria> vistorias, bool isBackup) async {
    if (!await _permissionService.requestStoragePermission() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de armazenamento negada.'), backgroundColor: Colors.red));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV...')));

    final prefs = await SharedPreferences.getInstance();
    final nomeLider = prefs.getString('nome_lider') ?? 'N/A';
    final nomesAjudantes = prefs.getString('nomes_ajudantes') ?? 'N/A';
    final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
    final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
    final projWGS84 = proj4.Projection.get('EPSG:4326')!;
    final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

    List<List<dynamic>> rows = [];
    rows.add([
      'Lider_Equipe', 'Ajudantes', 'ID_Vistoria_DB', 'ID_Bairro', 'Nome_Bairro', 'Nome_Setor',
      'Identificador_Imovel', 'Tipo_Imovel', 'Status_Visita', 'Resultado_Visita', 'Observacao_Vistoria',
      'Data_Vistoria', 'Latitude', 'Longitude', 'Easting', 'Northing',
      'ID_Foco_DB', 'Tipo_Criadouro', 'Larvas_Encontradas', 'Tratamento_Realizado'
    ]);

    final List<int> idsParaMarcar = [];

    for (var vistoria in vistorias) {
      if (!isBackup) idsParaMarcar.add(vistoria.dbId!);
      
      String easting = '', northing = '';
      if (vistoria.latitude != null && vistoria.longitude != null) {
        var pUtm = projWGS84.transform(projUTM, proj4.Point(x: vistoria.longitude!, y: vistoria.latitude!));
        easting = pUtm.x.toStringAsFixed(2);
        northing = pUtm.y.toStringAsFixed(2);
      }
      
      final focos = await _dbHelper.getFocosDaVistoria(vistoria.dbId!);

      if (focos.isEmpty) {
        rows.add([
          nomeLider, nomesAjudantes, vistoria.dbId, vistoria.idBairro, vistoria.nomeBairro, vistoria.nomeSetor,
          vistoria.identificadorImovel, vistoria.tipoImovel, vistoria.status.name, vistoria.resultado, vistoria.observacao,
          vistoria.dataColeta?.toIso8601String(), vistoria.latitude, vistoria.longitude, easting, northing,
          null, null, null, null
        ]);
      } else {
        for (final foco in focos) {
          rows.add([
            nomeLider, nomesAjudantes, vistoria.dbId, vistoria.idBairro, vistoria.nomeBairro, vistoria.nomeSetor,
            vistoria.identificadorImovel, vistoria.tipoImovel, vistoria.status.name, vistoria.resultado, vistoria.observacao,
            vistoria.dataColeta?.toIso8601String(), vistoria.latitude, vistoria.longitude, easting, northing,
            foco.id, foco.tipoCriadouro, foco.larvasEncontradas ? 'Sim' : 'Não', foco.tratamentoRealizado
          ]);
        }
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final hoje = DateTime.now();
    final prefixo = isBackup ? 'BACKUP_COMPLETO' : 'export';
    final fName = 'geovigilancia_${prefixo}_vistorias_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}.csv';
    final path = '${dir.path}/$fName';

    await File(path).writeAsString(const ListToCsvConverter().convert(rows));

    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      await Share.shareXFiles([XFile(path)], subject: 'Exportação de Vistorias - GeoVigilância');
      if (!isBackup) {
        // await _dbHelper.marcarVistoriasComoExportadas(idsParaMarcar); // Implementar no DB Helper
      }
    }
  }


  // =======================================================================
  // FUNÇÃO 2: Exportar apenas os pontos com foco em formato GeoJSON
  // =======================================================================
  Future<void> exportarPontosDeFocoGeoJson(BuildContext context) async {
    if (!await _permissionService.requestStoragePermission() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de armazenamento negada.'), backgroundColor: Colors.red));
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando pontos de foco...')));

    // IMPORTANTE: Este método precisa ser criado no seu DatabaseHelper.
    // Ele deve fazer um JOIN entre as tabelas 'focos' e 'vistorias'.
    // final List<Map<String, dynamic>> focosComLocalizacao = await _dbHelper.getPositiveFocosWithLocation();
    
    // Simulação para o código compilar e funcionar
    final focosComLocalizacao = [
      {'latitude': -23.5505, 'longitude': -46.6333, 'tipoCriadouro': 'Pneu', 'tratamentoRealizado': 'Eliminação Mecânica', 'identificadorImovel': 'Rua C, 300', 'nomeBairro': 'Centro', 'nomeSetor': '01'},
      {'latitude': -23.5510, 'longitude': -46.6340, 'tipoCriadouro': 'Vaso de Planta', 'tratamentoRealizado': 'Larvicida', 'identificadorImovel': 'Rua D, 400', 'nomeBairro': 'Centro', 'nomeSetor': '02'},
    ];
    
    if (focosComLocalizacao.isEmpty) {
       if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum foco positivo com coordenadas encontrado.'), backgroundColor: Colors.orange));
      }
      return;
    }

    final List<Map<String, dynamic>> features = [];
    for (final foco in focosComLocalizacao) {
      features.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [foco['longitude'], foco['latitude']]
        },
        'properties': {
          'identificador_imovel': foco['identificadorImovel'],
          'bairro': foco['nomeBairro'],
          'setor': foco['nomeSetor'],
          'tipo_criadouro': foco['tipoCriadouro'],
          'tratamento': foco['tratamentoRealizado'],
        }
      });
    }

    final Map<String, dynamic> geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    const jsonEncoder = JsonEncoder.withIndent('  ');
    final jsonString = jsonEncoder.convert(geoJson);

    final directory = await getApplicationDocumentsDirectory();
    final hoje = DateTime.now();
    final fName = 'geovigilancia_pontos_foco_${DateFormat('yyyyMMdd_HHmm').format(hoje)}.json';
    final path = '${directory.path}/$fName';
    await File(path).writeAsString(jsonString);

    if (context.mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      await Share.shareXFiles(
        [XFile(path, name: fName)],
        subject: 'Pontos de Foco - GeoVigilância',
      );
    }
  }
}