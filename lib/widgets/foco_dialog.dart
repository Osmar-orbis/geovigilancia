// lib/widgets/foco_dialog.dart (VERSÃO ATUALIZADA COM FOTO)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/tipo_criadouro_model.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:image_picker/image_picker.dart';

class FocoDialog extends StatefulWidget {
  final Foco? focoParaEditar;
  final int vistoriaId;

  const FocoDialog({
    super.key,
    this.focoParaEditar,
    required this.vistoriaId,
  });

  bool get isEditing => focoParaEditar != null;

  @override
  State<FocoDialog> createState() => _FocoDialogState();
}

class _FocoDialogState extends State<FocoDialog> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;

  String? _tipoCriadouroSelecionado;
  bool _larvasEncontradas = false;
  String? _tratamentoRealizado;

  // --- Estados para a nova funcionalidade de foto ---
  String? _caminhoFoto;
  final ImagePicker _picker = ImagePicker();
  // ---

  late Future<List<TipoCriadouro>> _tiposCriadouroFuture;
  final List<String> _opcoesTratamento = ['Eliminação Mecânica', 'Larvicida', 'Orientação', 'Não Tratado'];

  @override
  void initState() {
    super.initState();
    _tiposCriadouroFuture = dbHelper.getTodosTiposCriadouro();

    if (widget.isEditing) {
      final foco = widget.focoParaEditar!;
      _tipoCriadouroSelecionado = foco.tipoCriadouro;
      _larvasEncontradas = foco.larvasEncontradas;
      _tratamentoRealizado = foco.tratamentoRealizado;
      _caminhoFoto = foco.fotoUrl; // Carrega o caminho da foto, se houver
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Função para capturar imagem da câmera ou galeria
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Comprime a imagem para economizar espaço
        maxWidth: 1024,   // Redimensiona para uma largura máxima
      );
      if (pickedFile != null) {
        setState(() {
          _caminhoFoto = pickedFile.path;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // Função de submissão do formulário
  void _submit() {
    if (_formKey.currentState!.validate()) {
      final foco = Foco(
        id: widget.focoParaEditar?.id,
        vistoriaId: widget.vistoriaId,
        tipoCriadouro: _tipoCriadouroSelecionado!,
        larvasEncontradas: _larvasEncontradas,
        tratamentoRealizado: _tratamentoRealizado,
        fotoUrl: _caminhoFoto, // Passa o caminho da foto para o objeto Foco
      );
      // Retorna o objeto Foco (novo ou editado) para a tela anterior
      Navigator.of(context).pop(foco);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isEditing ? 'Editar Foco' : 'Adicionar Novo Foco',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown para Tipos de Criadouro
                    FutureBuilder<List<TipoCriadouro>>(
                      future: _tiposCriadouroFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Text('Erro ao carregar tipos de criadouro.');
                        }
                        final tipos = snapshot.data!;
                        if (_tipoCriadouroSelecionado != null && !tipos.any((t) => t.nome == _tipoCriadouroSelecionado)) {
                          _tipoCriadouroSelecionado = null;
                        }
                        return DropdownButtonFormField<String>(
                          value: _tipoCriadouroSelecionado,
                          decoration: const InputDecoration(labelText: 'Tipo de Criadouro', border: OutlineInputBorder()),
                          items: tipos.map((tc) => DropdownMenuItem(value: tc.nome, child: Text(tc.nome))).toList(),
                          onChanged: (value) => setState(() => _tipoCriadouroSelecionado = value),
                          validator: (v) => v == null ? 'Campo obrigatório' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Switch para Larvas Encontradas
                    SwitchListTile(
                      title: const Text('Larvas Encontradas?'),
                      value: _larvasEncontradas,
                      onChanged: (value) => setState(() => _larvasEncontradas = value),
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 16),

                    // Dropdown para Tratamento Realizado
                    DropdownButtonFormField<String>(
                      value: _tratamentoRealizado,
                      decoration: const InputDecoration(labelText: 'Tratamento Realizado', border: OutlineInputBorder()),
                      items: _opcoesTratamento.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (value) => setState(() => _tratamentoRealizado = value),
                       validator: (v) => v == null ? 'Campo obrigatório' : null,
                    ),
                    
                    const SizedBox(height: 24),

                    // --- NOVA SEÇÃO DE FOTO ADICIONADA AQUI ---
                    Text('Foto do Foco (Opcional)', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildPhotoSection(),
                    // --- FIM DA SEÇÃO DE FOTO ---
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Botões de ação
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                    ),
                    child: Text(widget.isEditing ? 'Atualizar' : 'Salvar Foco'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Widget separado para a lógica da foto, deixando o build principal mais limpo
  Widget _buildPhotoSection() {
    return Column(
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: _caminhoFoto != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(_caminhoFoto!), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => setState(() => _caminhoFoto = null),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.close, color: Colors.red, size: 18),
                      ),
                    ),
                  )
                ],
              )
            : const Center(
                child: Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
              ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Câmera'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'))),
          ],
        )
      ],
    );
  }
}