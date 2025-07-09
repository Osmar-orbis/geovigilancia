// lib/providers/map_provider.dart (VERSÃO ADAPTADA PARA GEOVIGILÂNCIA)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/models/imported_feature_model.dart';
import 'package:geovigilancia/models/sample_point.dart';
import 'package:geovigilancia/services/export_service.dart';
import 'package:geovigilancia/services/geojson_service.dart';
import 'package:geovigilancia/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;
  final _samplingService = SamplingService();
  final _exportService = ExportService();
  
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  List<ImportedPolygonFeature> _importedPolygons = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  Atividade? _currentAtividade;
  MapLayerType _currentLayer = MapLayerType.satelite;
  Position? _currentUserPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;
  bool _isDrawing = false;
  final List<LatLng> _drawnPoints = [];

  // Getters
  bool get isDrawing => _isDrawing;
  List<LatLng> get drawnPoints => _drawnPoints;
  List<Polygon> get polygons => _importedPolygons.map((f) => f.polygon).toList();
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  Atividade? get currentAtividade => _currentAtividade;
  MapLayerType get currentLayer => _currentLayer;
  Position? get currentUserPosition => _currentUserPosition;
  bool get isFollowingUser => _isFollowingUser;

  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };
  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  String get currentTileUrl {
    String url = _tileUrls[_currentLayer]!;
    if (url.contains('{accessToken}')) {
      if (_mapboxAccessToken.isEmpty) return _tileUrls[MapLayerType.satelite]!;
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  void switchMapLayer() {
    _currentLayer = MapLayerType.values[(_currentLayer.index + 1) % MapLayerType.values.length];
    notifyListeners();
  }

  void startDrawing() {
    if (!_isDrawing) {
      _isDrawing = true;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void cancelDrawing() {
    if (_isDrawing) {
      _isDrawing = false;
      _drawnPoints.clear();
      notifyListeners();
    }
  }

  void addDrawnPoint(LatLng point) {
    if (_isDrawing) {
      _drawnPoints.add(point);
      notifyListeners();
    }
  }

  void undoLastDrawnPoint() {
    if (_isDrawing && _drawnPoints.isNotEmpty) {
      _drawnPoints.removeLast();
      notifyListeners();
    }
  }
  
  void saveDrawnPolygon() {
    if (_drawnPoints.length < 3) {
      cancelDrawing();
      return;
    }
    _importedPolygons.add(ImportedPolygonFeature(
      polygon: Polygon(points: List.from(_drawnPoints), color: const Color(0xFF0D47A1).withAlpha(100), borderColor: const Color(0xFF0D47A1), borderStrokeWidth: 2, isFilled: true),
      properties: {},
    ));
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void clearAllMapData() {
    _importedPolygons = [];
    _samplePoints = [];
    _currentAtividade = null;
    if (_isFollowingUser) toggleFollowingUser();
    if (_isDrawing) cancelDrawing();
    notifyListeners();
  }

  void setCurrentAtividade(Atividade atividade) {
    _currentAtividade = atividade;
  }
  
  Future<String> processarImportacaoDeArquivo({required bool isPlanoDeAmostragem}) async {
    if (_currentAtividade == null) {
      return "Erro: Nenhuma atividade selecionada para o planejamento.";
    }
    _setLoading(true);

    try {
      if (isPlanoDeAmostragem) {
        final pontosImportados = await _geoJsonService.importPoints();
        if (pontosImportados.isNotEmpty) {
          return await _processarPlanoDeVistoriaImportado(pontosImportados);
        }
      } else {
        final poligonosImportados = await _geoJsonService.importPolygons();
        if (poligonosImportados.isNotEmpty) {
          return await _processarCargaDeSetoresImportada(poligonosImportados);
        }
      }
      
      return "Nenhum dado válido foi encontrado no arquivo selecionado.";
    
    } on GeoJsonParseException catch (e) {
      return e.toString();
    } catch (e) {
      return 'Ocorreu um erro inesperado: ${e.toString()}';
    } finally {
      _setLoading(false);
    }
  }

  Future<String> _processarCargaDeSetoresImportada(List<ImportedPolygonFeature> features) async {
    _importedPolygons = []; 
    _samplePoints = []; 
    notifyListeners();

    int bairrosCriados = 0;
    int setoresCriados = 0;
    
    await _dbHelper.database.then((db) async => await db.transaction((txn) async {
      for (final feature in features) {
        final props = feature.properties;
        final bairroId = (props['bairro_id'] ?? props['bairro_nome'] ?? props['bairro'])?.toString();
        final nomeSetor = (props['setor_nome'] ?? props['setor_id'] ?? props['setor'])?.toString();
        
        if (bairroId == null || nomeSetor == null) continue;

        Bairro? bairro = (await txn.query('bairros', where: 'id = ? AND atividadeId = ?', whereArgs: [bairroId, _currentAtividade!.id!])).map((e) => Bairro.fromMap(e)).firstOrNull;
        if (bairro == null) {
          bairro = Bairro(id: bairroId, atividadeId: _currentAtividade!.id!, nome: props['bairro_nome']?.toString() ?? bairroId, municipio: 'N/I', estado: 'N/I');
          await txn.insert('bairros', bairro.toMap());
          bairrosCriados++;
        }
        
        Setor? setor = (await txn.query('setores', where: 'nome = ? AND bairroId = ? AND bairroAtividadeId = ?', whereArgs: [nomeSetor, bairro.id, bairro.atividadeId])).map((e) => Setor.fromMap(e)).firstOrNull;
        if (setor == null) {
          setor = Setor(
            bairroId: bairro.id, bairroAtividadeId: bairro.atividadeId, nome: nomeSetor,
            areaHa: (props['area_ha'] as num?)?.toDouble(),
          );
          final setorId = await txn.insert('setores', setor.toMap());
          setor = setor.copyWith(id: setorId);
          setoresCriados++;
        }
        
        feature.properties['db_setor_id'] = setor.id;
        feature.properties['db_bairro_nome'] = bairro.nome;
      }
    }));
    
    _importedPolygons = features;
    notifyListeners();
    return "Carga concluída: ${features.length} polígonos, $bairrosCriados novos bairros e $setoresCriados novos setores criados.";
  }

  Future<String> _processarPlanoDeVistoriaImportado(List<ImportedPointFeature> pontosImportados) async {
    _importedPolygons = []; 
    _samplePoints = []; 
    notifyListeners();

    final db = await _dbHelper.database;
    final List<Vistoria> vistoriasParaSalvar = [];
    int novosBairros = 0;
    int novosSetores = 0;
    
    await db.transaction((txn) async {
      for (final ponto in pontosImportados) {
        final props = ponto.properties;
        final bairroId = (props['bairro_id'] ?? props['bairro'])?.toString();
        final nomeSetor = (props['setor'] ?? props['setor_nome'])?.toString();
        
        if (bairroId == null || nomeSetor == null) continue;

        Bairro? bairro = (await txn.query('bairros', where: 'id = ? AND atividadeId = ?', whereArgs: [bairroId, _currentAtividade!.id!])).map((e) => Bairro.fromMap(e)).firstOrNull;
        if (bairro == null) {
          bairro = Bairro(id: bairroId, atividadeId: _currentAtividade!.id!, nome: props['bairro']?.toString() ?? bairroId, municipio: 'N/I', estado: 'N/I');
          await txn.insert('bairros', bairro.toMap());
          novosBairros++;
        }

        Setor? setor = (await txn.query('setores', where: 'nome = ? AND bairroId = ? AND bairroAtividadeId = ?', whereArgs: [nomeSetor, bairro.id, bairro.atividadeId])).map((e) => Setor.fromMap(e)).firstOrNull;
        if (setor == null) {
          setor = Setor(bairroId: bairro.id, bairroAtividadeId: bairro.atividadeId, nome: nomeSetor);
          final setorId = await txn.insert('setores', setor.toMap());
          setor = setor.copyWith(id: setorId);
          novosSetores++;
        }
        
        vistoriasParaSalvar.add(Vistoria(
          setorId: setor.id,
          identificadorImovel: props['imovel_id']?.toString() ?? 'Imóvel ${DateTime.now().microsecondsSinceEpoch}',
          tipoImovel: props['tipo_imovel'] ?? 'Residencial',
          latitude: ponto.position.latitude, 
          longitude: ponto.position.longitude,
          status: StatusVisita.pendente,
          dataColeta: DateTime.now(),
          nomeBairro: bairro.nome, 
          idBairro: bairro.id, 
          nomeSetor: setor.nome,
        ));
      }
      
      for (var vistoria in vistoriasParaSalvar) {
        await txn.insert('vistorias', vistoria.toMap());
      }
    });
    
    await loadSamplesParaAtividade();
    return "Plano importado: ${vistoriasParaSalvar.length} vistorias salvas. Novos Bairros: $novosBairros, Novos Setores: $novosSetores.";
  }

  Future<String> gerarVistoriasParaAtividade({required double hectaresPerSample}) async {
    if (_importedPolygons.isEmpty) return "Nenhum polígono de setor carregado.";
    if (_currentAtividade == null) return "Erro: Atividade atual não definida.";

    _setLoading(true);

    final pontosGerados = _samplingService.generateMultiTalhaoSamplePoints(
      importedFeatures: _importedPolygons,
      hectaresPerSample: hectaresPerSample,
    );

    if (pontosGerados.isEmpty) {
      _setLoading(false);
      return "Nenhum ponto de vistoria pôde ser gerado.";
    }

    final List<Vistoria> vistoriasParaSalvar = [];
    int pointIdCounter = 1;

    for (final ponto in pontosGerados) {
      final props = ponto.properties;
      final setorIdSalvo = props['db_setor_id'] as int?;
      if (setorIdSalvo != null) {
         vistoriasParaSalvar.add(Vistoria(
          setorId: setorIdSalvo,
          identificadorImovel: 'Imóvel ${pointIdCounter.toString()}',
          tipoImovel: 'Residencial',
          latitude: ponto.position.latitude, 
          longitude: ponto.position.longitude,
          status: StatusVisita.pendente, 
          dataColeta: DateTime.now(),
          nomeBairro: props['db_bairro_nome']?.toString(),
          idBairro: props['bairro_id']?.toString(),
          nomeSetor: props['setor_nome']?.toString(),
        ));
        pointIdCounter++;
      }
    }

    final db = await _dbHelper.database;
    for (var vistoria in vistoriasParaSalvar) {
      await db.insert('vistorias', vistoria.toMap());
    }
    
    await loadSamplesParaAtividade();
    _setLoading(false);
    
    return "${vistoriasParaSalvar.length} vistorias foram geradas e salvas.";
  }
  
  Future<void> loadSamplesParaAtividade() async {
    if (_currentAtividade == null) return;
    
    _setLoading(true);
    _samplePoints.clear();
    final bairros = await _dbHelper.getBairrosDaAtividade(_currentAtividade!.id!);
    for (final bairro in bairros) {
      final setores = await _dbHelper.getSetoresDoBairro(bairro.id, _currentAtividade!.id!);
      for (final setor in setores) {
        final vistorias = await _dbHelper.getVistoriasDoSetor(setor.id!);
        
        final vistoriasComFoco = vistorias.where((v) => v.resultado == 'Com Foco').toList();

        for (final v in vistoriasComFoco) {
           _samplePoints.add(SamplePoint(
              id: v.dbId ?? 0,
              position: LatLng(v.latitude ?? 0, v.longitude ?? 0),
              status: _getSampleStatus(v),
              data: {'dbId': v.dbId}
          ));
        }
      }
    }
    _setLoading(false);
  }

  void toggleFollowingUser() {
    if (_isFollowingUser) {
      _positionStreamSubscription?.cancel();
      _isFollowingUser = false;
    } else {
      const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1);
      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
        _currentUserPosition = position;
        notifyListeners();
      });
      _isFollowingUser = true;
    }
    notifyListeners();
  }

  void updateUserPosition(Position position) {
    _currentUserPosition = position;
    notifyListeners();
  }
  
  @override
  void dispose() { 
    _positionStreamSubscription?.cancel(); 
    super.dispose(); 
  }
  
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  SampleStatus _getSampleStatus(Vistoria vistoria) {
    if (vistoria.exportada) {
      return SampleStatus.exported;
    }
    switch (vistoria.status) {
      case StatusVisita.realizada:
        return SampleStatus.completed;
      case StatusVisita.fechada:
      case StatusVisita.recusa:
        return SampleStatus.open;
      case StatusVisita.pendente:
        return SampleStatus.untouched;
    }
  }

  Future<void> exportarPlanoDeAmostragem(BuildContext context) async {
    final List<int> vistoriaIds = samplePoints.map((p) => p.data['dbId'] as int).toList();

    if (vistoriaIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum plano de vistoria para exportar.'),
          backgroundColor: Colors.orange,
        ));
        return;
    }
    // A chamada ao ExportService precisará ser adaptada para lidar com 'vistoriaIds'
    /*
    await _exportService.exportarPlanoDeVistoria(
      context: context,
      vistoriaIds: vistoriaIds,
    );
    */
  }
}