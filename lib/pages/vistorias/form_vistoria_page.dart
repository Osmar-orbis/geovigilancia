// lib/pages/vistorias/form_vistoria_page.dart (VERSÃO 100% COMPLETA E CORRIGIDA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/pages/vistorias/lista_focos_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FormVistoriaPage extends StatefulWidget {
  final Vistoria? vistoriaParaEditar;
  final Setor? setor;

  const FormVistoriaPage({super.key, this.vistoriaParaEditar, this.setor})
      : assert(vistoriaParaEditar != null || setor != null, 'É necessário fornecer uma vistoria para editar ou um setor para criar uma nova vistoria.');

  @override
  State<FormVistoriaPage> createState() => _FormVistoriaPageState();
}

class _FormVistoriaPageState extends State<FormVistoriaPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;
  
  late Vistoria _vistoriaAtual;
  
  final List<String> _opcoesTipoImovel = ['Residencial', 'Comercial', 'Terreno Baldio', 'Ponto Estratégico', 'Outro'];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isReadOnly = false;
  bool get _isModoEdicao => widget.vistoriaParaEditar != null;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }

  Future<void> _setupInitialData() async {
    Vistoria vistoriaBase;
    if (_isModoEdicao) {
      vistoriaBase = (await dbHelper.getVistoriaById(widget.vistoriaParaEditar!.dbId!)) ?? widget.vistoriaParaEditar!;
      if (vistoriaBase.dbId != null) {
        vistoriaBase.focos = await dbHelper.getFocosDaVistoria(vistoriaBase.dbId!);
      }
    } else {
      vistoriaBase = Vistoria(
        setorId: widget.setor!.id,
        tipoImovel: 'Residencial',
        dataColeta: DateTime.now(),
        status: StatusVisita.pendente,
        nomeBairro: widget.setor!.bairroNome,
        nomeSetor: widget.setor!.nome,
        idBairro: widget.setor!.bairroId,
      );
    }

    setState(() {
      _vistoriaAtual = vistoriaBase;
      _isReadOnly = _vistoriaAtual.status != StatusVisita.pendente;
      _isLoading = false;
    });
  }
  
  Future<void> _salvarVistoria({
    required StatusVisita novoStatus, 
    bool navegarParaFocos = false,
    bool mostrarSnackbar = true,
  }) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos obrigatórios.'), backgroundColor: Colors.orange)
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vistoriaParaSalvar = _vistoriaAtual.copyWith(
        status: novoStatus,
        resultado: novoStatus == StatusVisita.realizada 
          ? (_vistoriaAtual.focos.isNotEmpty ? 'Com Foco' : 'Sem Foco')
          : 'Não Vistoriado',
      );
      
      final vistoriaSalva = await dbHelper.saveFullVistoria(vistoriaParaSalvar, _vistoriaAtual.focos);
      
      setState(() {
        _vistoriaAtual = vistoriaSalva;
      });

      if (!mounted) return;
      if (mostrarSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vistoria salva com sucesso!'), backgroundColor: Colors.green, duration: Duration(seconds: 2))
        );
      }
      
      if (navegarParaFocos) {
        await Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ListaFocosPage(vistoria: _vistoriaAtual)
        ));
      } else if (!_isModoEdicao && !navegarParaFocos) {
        Navigator.of(context).pop(true);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _copiarERenomearImagem(XFile imagemOriginal) async {
    if (_vistoriaAtual.dbId == null) return null;
    try {
      final diretorioApp = await getApplicationDocumentsDirectory();
      final pastaImagens = Directory(p.join(diretorioApp.path, 'imagens_vistorias'));
      if (!await pastaImagens.exists()) {
        await pastaImagens.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final novoNome = 'V${_vistoriaAtual.dbId}_GERAL_$timestamp.jpg';
      final novoCaminho = p.join(pastaImagens.path, novoNome);

      final arquivoOriginal = File(imagemOriginal.path);
      await arquivoOriginal.copy(novoCaminho);
      return novoCaminho;
    } catch (e) {
      debugPrint("Erro ao copiar imagem: $e");
      return null;
    }
  }
  
  Future<void> _pickImage(ImageSource source) async {
    if (_isSaving) return;

    if (_vistoriaAtual.dbId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salvando vistoria para habilitar fotos...'), duration: Duration(seconds: 2)));
      await _salvarVistoria(novoStatus: _vistoriaAtual.status, mostrarSnackbar: false);
      if (_vistoriaAtual.dbId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível salvar. Tente novamente.'), backgroundColor: Colors.red));
        return;
      }
    }

    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1024);
    
    if (pickedFile != null) {
      setState(() => _isSaving = true);
      final caminhoSalvo = await _copiarERenomearImagem(pickedFile);
      if (caminhoSalvo != null) {
        setState(() => _vistoriaAtual.photoPaths.add(caminhoSalvo));
        await _salvarVistoria(novoStatus: _vistoriaAtual.status, mostrarSnackbar: false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao processar a imagem.'), backgroundColor: Colors.red));
      }
      setState(() => _isSaving = false);
    }
  }
  
  Future<void> _obterLocalizacaoAtual() async {
    if (_isReadOnly || _isSaving) return;
    setState(() { _isSaving = true; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Serviço de GPS desabilitado.';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão negada.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Permissão negada permanentemente.';
      
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      
      setState(() {
        _vistoriaAtual = _vistoriaAtual.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      });

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao obter localização: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: Text(_isModoEdicao ? 'Editar Vistoria' : 'Nova Vistoria')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isModoEdicao ? 'Editar Vistoria' : 'Nova Vistoria'),
        backgroundColor: const Color(0xFF617359),
        foregroundColor: Colors.white,
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isReadOnly)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: _vistoriaAtual.status.cor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Icon(_vistoriaAtual.status.icone, size: 18, color: _vistoriaAtual.status.cor),
                          const SizedBox(width: 8),
                          Expanded(child: Text("Visita já finalizada como '${_vistoriaAtual.status.name}'. Não pode ser editada.", style: TextStyle(color: _vistoriaAtual.status.cor))),
                        ],
                      ),
                    ),
                  TextFormField(
                    initialValue: _vistoriaAtual.nomeBairro,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Nome do Bairro', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _vistoriaAtual.nomeSetor,
                    enabled: false,
                    decoration: const InputDecoration(labelText: 'Setor / Quarteirão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_on)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _vistoriaAtual.identificadorImovel,
                    readOnly: _isReadOnly,
                    decoration: const InputDecoration(labelText: 'Identificação do Imóvel (Rua, Nº)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home_work_outlined)),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    onChanged: (value) => _vistoriaAtual.identificadorImovel = value,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _opcoesTipoImovel.contains(_vistoriaAtual.tipoImovel) ? _vistoriaAtual.tipoImovel : null,
                    items: _opcoesTipoImovel.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: _isReadOnly ? null : (value) => setState(() => _vistoriaAtual.tipoImovel = value ?? ''),
                    decoration: const InputDecoration(labelText: 'Tipo do Imóvel', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category_outlined)),
                    validator: (v) => v == null || v.isEmpty ? 'Selecione um tipo' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildColetorCoordenadas(),
                  const SizedBox(height: 24),
                  _buildPhotoSection(),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _vistoriaAtual.observacao,
                    readOnly: _isReadOnly,
                    decoration: const InputDecoration(labelText: 'Observações da Vistoria', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'),
                    maxLines: 3,
                    onChanged: (value) => _vistoriaAtual.observacao = value,
                  ),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
      ),
    );
  }

  Widget _buildColetorCoordenadas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordenadas do Imóvel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Expanded(
              child: (_vistoriaAtual.latitude == null)
                  ? const Text('Nenhuma localização obtida.')
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Lat: ${_vistoriaAtual.latitude!.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Lon: ${_vistoriaAtual.longitude!.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
            ),
            IconButton(icon: const Icon(Icons.my_location, color: Color(0xFF1D4433)), onPressed: _isSaving || _isReadOnly ? null : _obterLocalizacaoAtual, tooltip: 'Obter localização'),
          ]),
        ),
      ],
    );
  }
  
  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos Gerais do Imóvel', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              _vistoriaAtual.photoPaths.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0), 
                      child: Text(
                        _vistoriaAtual.dbId != null ? 'Nenhuma foto adicionada.' : 'Salve a vistoria para adicionar fotos.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      )
                    ))
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                      itemCount: _vistoriaAtual.photoPaths.length,
                      itemBuilder: (context, index) {
                        final path = _vistoriaAtual.photoPaths[index];
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover)),
                            if (!_isReadOnly)
                              Positioned(
                                top: -8, right: -8,
                                child: IconButton(
                                  icon: const CircleAvatar(backgroundColor: Colors.white, radius: 12, child: Icon(Icons.close, color: Colors.red, size: 16)),
                                  onPressed: () async {
                                    setState(() => _vistoriaAtual.photoPaths.removeAt(index));
                                    await _salvarVistoria(novoStatus: _vistoriaAtual.status, mostrarSnackbar: false);
                                  },
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              if (!_isReadOnly) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: _isSaving ? null : () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Câmera'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: _isSaving ? null : () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
                  ],
                ),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_isReadOnly) {
      return SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListaFocosPage(vistoria: _vistoriaAtual))),
          icon: const Icon(Icons.bug_report_outlined),
          label: const Text('Ver Focos Registrados', style: TextStyle(fontSize: 16)),
        ),
      );
    }
    
    if (!_isModoEdicao) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _salvarVistoria(novoStatus: StatusVisita.realizada, navegarParaFocos: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.bug_report_outlined),
              label: const Text('Vistoriar e Registrar Focos', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _salvarVistoria(novoStatus: StatusVisita.fechada),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange.shade800, side: BorderSide(color: Colors.orange.shade800)),
                    icon: const Icon(Icons.lock_outline, size: 20),
                    label: const Text('Fechado'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _salvarVistoria(novoStatus: StatusVisita.recusa),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade800, side: BorderSide(color: Colors.red.shade800)),
                    icon: const Icon(Icons.do_not_disturb_on_outlined, size: 20),
                    label: const Text('Recusa'),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } 
    else {
      return SizedBox(
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : () => _salvarVistoria(novoStatus: _vistoriaAtual.status),
          icon: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Icon(Icons.save_outlined),
          label: const Text('Salvar Alterações', style: TextStyle(fontSize: 16)),
        ),
      );
    }
  }
}