// lib/pages/menu/map_import_page.dart (VERSÃO FINAL COM PROVIDER CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/providers/map_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geovigilancia/pages/vistorias/form_vistoria_page.dart';

class MapImportPage extends StatefulWidget {
  const MapImportPage({super.key});

  @override
  State<MapImportPage> createState() => _MapImportPageState();
}

class _MapImportPageState extends State<MapImportPage> with RouteAware {
  final _mapController = MapController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MapProvider.routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    super.didPopNext();
    debugPrint("Mapa visível novamente, recarregando os dados das vistorias...");
    // Aqui usamos context.read, pois está dentro de um método de ciclo de vida onde é seguro.
    context.read<MapProvider>().loadVistoriasParaAtividade();
  }

  @override
  void dispose() {
    MapProvider.routeObserver.unsubscribe(this);
    // Aqui usamos a sintaxe completa pois é mais seguro em `dispose`.
    final mapProvider = Provider.of<MapProvider>(context, listen: false);
    if (mapProvider.isFollowingUser) {
      mapProvider.toggleFollowingUser();
    }
    super.dispose();
  }

  Future<void> _handleImport() async {
    // <<< CORREÇÃO APLICADA AQUI >>>
    final provider = Provider.of<MapProvider>(context, listen: false);
    
    final bool? isPlano = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O que você quer importar?'),
        content: const Text('Escolha o tipo de arquivo para importar para esta atividade.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Carga de Setores (Polígonos)'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Plano de Vistoria (Pontos)'),
          ),
        ],
      ),
    );

    if (isPlano == null || !mounted) return;

    final resultMessage = await provider.processarImportacaoDeArquivo(isPlanoDeAmostragem: isPlano);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage), duration: const Duration(seconds: 5)));
    
    if (provider.polygons.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(provider.polygons.expand((p) => p.points).toList()),
          padding: const EdgeInsets.all(50.0)));
    } else if (provider.vistorias.isNotEmpty) {
      _mapController.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(provider.vistorias.map((v) => v.position).toList()),
          padding: const EdgeInsets.all(50.0)));
    }
  }
  
  Future<void> _handleGenerateSamples() async {
    // <<< CORREÇÃO APLICADA AQUI >>>
    final provider = Provider.of<MapProvider>(context, listen: false);
    if (provider.polygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importe ou desenhe os polígonos dos setores primeiro.')));
      return;
    }

    final density = await _showDensityDialog();
    if (density == null || !mounted) return;
    
    final resultMessage = await provider.gerarVistoriasParaAtividade(imoveisPorHectare: density);
    
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resultMessage), duration: const Duration(seconds: 4)));
    }
  }

  Future<double?> _showDensityDialog() {
    final densityController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Densidade da Vistoria'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: densityController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Imóveis por hectare', suffixText: 'imóveis/ha'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Campo obrigatório';
              if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Número inválido';
              return null;
            }
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, double.parse(densityController.text.replaceAll(',', '.')));
              }
            },
            child: const Text('Gerar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLocationButtonPressed() async {
    // <<< CORREÇÃO APLICADA AQUI >>>
    final provider = Provider.of<MapProvider>(context, listen: false);
    if (provider.isFollowingUser) {
      final currentPosition = provider.currentUserPosition;
      if (currentPosition != null) {
        _mapController.move(LatLng(currentPosition.latitude, currentPosition.longitude), 17.0);
      }
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço de GPS desabilitado.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de localização negada.')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão negada permanentemente.')));
      return;
    }
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando sua localização...')));
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      provider.updateUserPosition(position);
      provider.toggleFollowingUser();
      _mapController.move(LatLng(position.latitude, position.longitude), 17.0);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível obter a localização: $e')));
      }
    }
  }

  AppBar _buildAppBar(MapProvider mapProvider) {
    final atividadeTipo = mapProvider.currentAtividade?.tipo ?? 'Planejamento';

    return AppBar(
      title: Text('Planejamento: $atividadeTipo'),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: mapProvider.isLoading ? null : () => context.read<MapProvider>().exportarPlanoDeVistoria(context),
          tooltip: 'Exportar Plano de Trabalho',
        ),
        if(mapProvider.polygons.isNotEmpty)
          IconButton(
              icon: const Icon(Icons.grid_on_sharp),
              onPressed: mapProvider.isLoading ? null : _handleGenerateSamples,
              tooltip: 'Gerar Vistorias'),
        IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined),
            onPressed: () => mapProvider.startDrawing(),
            tooltip: 'Desenhar Área'),
        IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: mapProvider.isLoading ? null : _handleImport,
            tooltip: 'Importar Arquivo'),
      ],
    );
  }

  AppBar _buildDrawingAppBar(MapProvider mapProvider) {
    return AppBar(
      backgroundColor: Colors.grey.shade800,
      title: const Text('Desenhando a Área'),
      leading: IconButton(icon: const Icon(Icons.close), onPressed: () => mapProvider.cancelDrawing(), tooltip: 'Cancelar Desenho'),
      actions: [
        IconButton(icon: const Icon(Icons.undo), onPressed: () => mapProvider.undoLastDrawnPoint(), tooltip: 'Desfazer Último Ponto'),
        IconButton(icon: const Icon(Icons.check), onPressed: () => mapProvider.saveDrawnPolygon(), tooltip: 'Salvar Polígono'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aqui usamos context.watch, pois queremos que a UI se reconstrua quando os dados do mapa mudarem.
    final mapProvider = context.watch<MapProvider>();
    final currentUserPosition = mapProvider.currentUserPosition;
    final isDrawing = mapProvider.isDrawing;

    if (currentUserPosition != null && mapProvider.isFollowingUser) {
      _mapController.move(LatLng(currentUserPosition.latitude, currentUserPosition.longitude), _mapController.camera.zoom);
    }

    return Scaffold(
      appBar: isDrawing ? _buildDrawingAppBar(mapProvider) : _buildAppBar(mapProvider),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(-15.7, -47.8),
              initialZoom: 4,
              onPositionChanged: (position, hasGesture) {
                if(hasGesture && mapProvider.isFollowingUser) {
                  // Aqui usamos context.read, pois estamos dentro de um callback e não queremos reconstruir, apenas chamar um método.
                  context.read<MapProvider>().toggleFollowingUser();
                }
              },
              onTap: (tapPosition, point) { if (isDrawing) context.read<MapProvider>().addDrawnPoint(point); },
            ),
            children: [
              TileLayer(
                  urlTemplate: mapProvider.currentTileUrl,
                  userAgentPackageName: 'com.example.geovigilancia'),
              
              if (mapProvider.polygons.isNotEmpty)
                PolygonLayer(polygons: mapProvider.polygons),
              
              if (mapProvider.vistorias.isNotEmpty)
                MarkerLayer(
                  markers: mapProvider.vistorias.map((vistoria) {
                    return Marker(
                      width: 40.0,
                      height: 40.0,
                      point: vistoria.position,
                      child: GestureDetector(
                        onTap: () async {
                          if (!mounted) return;
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (context) => FormVistoriaPage(vistoriaParaEditar: vistoria))
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: vistoria.status.cor, 
                            shape: BoxShape.circle, 
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(1, 1))]
                          ),
                          child: Center(
                            child: Icon(
                              vistoria.status.icone,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              
              if (isDrawing && mapProvider.drawnPoints.isNotEmpty)
                PolylineLayer(polylines: [ Polyline(points: mapProvider.drawnPoints, strokeWidth: 2.0, color: Colors.red.withOpacity(0.8)), ]),
              if (isDrawing)
                MarkerLayer(
                  markers: mapProvider.drawnPoints.map((point) {
                    return Marker(
                      point: point,
                      width: 12,
                      height: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              if (currentUserPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: LatLng(currentUserPosition.latitude, currentUserPosition.longitude),
                      child: const LocationMarker(),
                    ),
                  ],
                ),
            ],
          ),
          if (mapProvider.isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Processando...", style: TextStyle(color: Colors.white, fontSize: 16))
                  ]
                )
              )
            ),
          if (!isDrawing)
            Positioned(
              top: 10,
              left: 10,
              child: Column(
                children: [
                   FloatingActionButton(
                     onPressed: _handleLocationButtonPressed,
                     tooltip: 'Minha Localização',
                     heroTag: 'centerLocationFab',
                     backgroundColor: mapProvider.isFollowingUser ? Colors.blue : Theme.of(context).colorScheme.primary,
                     foregroundColor: Colors.white,
                     child: Icon(mapProvider.isFollowingUser ? Icons.gps_fixed : Icons.gps_not_fixed),
                   ),
                   const SizedBox(height: 10),
                   FloatingActionButton(
                     onPressed: () => context.read<MapProvider>().switchMapLayer(),
                     tooltip: 'Mudar Camada do Mapa',
                     heroTag: 'switchLayerFab',
                     mini: true,
                     child: Icon(mapProvider.currentLayer == MapLayerType.ruas
                         ? Icons.satellite_outlined
                         : (mapProvider.currentLayer == MapLayerType.satelite
                             ? Icons.terrain
                             : Icons.map_outlined)),
                   ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// A classe LocationMarker não precisa de alterações.
class LocationMarker extends StatefulWidget {
  const LocationMarker({super.key});

  @override
  State<LocationMarker> createState() => _LocationMarkerState();
}

class _LocationMarkerState extends State<LocationMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_animation),
          child: ScaleTransition(
            scale: _animation,
            child: Container(
              width: 50.0,
              height: 50.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.4),
              ),
            ),
          ),
        ),
        Container(
          width: 20.0,
          height: 20.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.shade700,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}