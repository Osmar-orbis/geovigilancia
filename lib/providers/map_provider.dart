// lib/providers/map_provider.dart (VERSÃO REATORADA SEM SAMPLEPOINT)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart'; // Mantido
import 'package:geovigilancia/models/imported_feature_model.dart';
// import 'package:geovigilancia/models/sample_point.dart'; // <<< MUDANÇA 1: REMOVIDO
import 'package:geovigilancia/services/geojson_service.dart';
import 'package:geovigilancia/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;
  final _samplingService = SamplingService();
  
  static final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

  List<ImportedPolygonFeature> _importedPolygons = [];
  // <<< MUDANÇA 2: _samplePoints trocado por _vistorias >>>
  List<Vistoria> _vistorias = [];
  
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
  // <<< MUDANÇA 3: Getter agora retorna a lista de vistorias >>>
  List<Vistoria> get vistorias => _vistorias;
  bool get isLoading => _isLoading;
  Atividade? get currentAtividade => _currentAtividade;
  MapLayerType get currentLayer => _currentLayer;
  Position? get currentUserPosition => _currentUserPosition;
  bool get isFollowingUser => _isFollowingUser;

  // O resto dos atributos (tileUrls, accessToken) permanece o mesmo...
  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };
  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  String get currentTileUrl { /* ... sem alteração ... */ return ""; }
  void switchMapLayer() { /* ... sem alteração ... */ }
  void startDrawing() { /* ... sem alteração ... */ }
  void cancelDrawing() { /* ... sem alteração ... */ }
  void addDrawnPoint(LatLng point) { /* ... sem alteração ... */ }
  void undoLastDrawnPoint() { /* ... sem alteração ... */ }
  void saveDrawnPolygon() { /* ... sem alteração ... */ }

  void clearAllMapData() {
    _importedPolygons = [];
    // <<< MUDANÇA 4: Limpa a lista de vistorias >>>
    _vistorias = [];
    _currentAtividade = null;
    if (_isFollowingUser) toggleFollowingUser();
    if (_isDrawing) cancelDrawing();
    notifyListeners();
  }

  void setCurrentAtividade(Atividade atividade) {
    _currentAtividade = atividade;
    // Ao definir uma nova atividade, carregamos os dados dela.
    loadVistoriasParaAtividade();
  }
  
  // O processamento de arquivos e geração de vistorias permanece o mesmo,
  // pois eles já trabalham com a criação de `Vistoria` no banco de dados.
  Future<String> processarImportacaoDeArquivo({required bool isPlanoDeAmostragem}) async { /* ... sem alteração ... */ return ""; }
  Future<String> _processarCargaDeSetoresImportada(List<ImportedPolygonFeature> features) async { /* ... sem alteração ... */ return ""; }
  Future<String> _processarPlanoDeVistoriaImportado(List<ImportedPointFeature> pontosImportados) async { /* ... sem alteração ... */ return ""; }
  Future<String> gerarVistoriasParaAtividade({required double imoveisPorHectare}) async { /* ... sem alteração ... */ return ""; }
  
  // <<< MUDANÇA 5: MÉTODO RENOMEADO E SIMPLIFICADO >>>
  /// Carrega todas as vistorias de uma atividade do banco de dados para o estado do provider.
  Future<void> loadVistoriasParaAtividade() async {
    if (_currentAtividade == null) return;
    
    _setLoading(true);
    _vistorias.clear();
    
    final bairros = await _dbHelper.getBairrosDaAtividade(_currentAtividade!.id!);
    for (final bairro in bairros) {
      final setores = await _dbHelper.getSetoresDoBairro(bairro.id, _currentAtividade!.id!);
      for (final setor in setores) {
        // Busca as vistorias do setor e as adiciona diretamente à lista
        final vistoriasDoSetor = await _dbHelper.getVistoriasDoSetor(setor.id!);
        _vistorias.addAll(vistoriasDoSetor);
      }
    }
    _setLoading(false); // Já notifica os listeners
  }

  // A lógica de localização e dispose permanece a mesma
  void toggleFollowingUser() { /* ... sem alteração ... */ }
  void updateUserPosition(Position position) { /* ... sem alteração ... */ }
  @override
  void dispose() { /* ... sem alteração ... */ }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // <<< MUDANÇA 6: MÉTODO REMOVIDO >>>
  // O método _getSampleStatus não é mais necessário, pois o status já está no objeto Vistoria.

  // <<< MUDANÇA 7: LÓGICA DE EXPORTAÇÃO AJUSTADA >>>
  Future<void> exportarPlanoDeVistoria(BuildContext context) async {
    // Agora mapeia diretamente da lista de vistorias
    final List<int> vistoriaIds = _vistorias
        .where((v) => v.dbId != null)
        .map((v) => v.dbId!)
        .toList();

    if (vistoriaIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum plano de vistoria para exportar.'),
          backgroundColor: Colors.orange,
        ));
        return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Função de exportação de plano em desenvolvimento.'),
    ));
  }
}