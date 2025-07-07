// lib/pages/campanhas/lista_campanhas_page.dart (CÓDIGO COMPLETO E CORRIGIDO)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/campanha_model.dart';
import 'package:geovigilancia/pages/campanhas/detalhes_campanha_page.dart';
import 'package:geovigilancia/pages/campanhas/form_campanha_page.dart';

// <<< AQUI ESTÁ A DEFINIÇÃO DA CLASSE QUE ESTAVA FALTANDO >>>
class ListaCampanhasPage extends StatefulWidget {
  final String title;
  final bool isImporting;
  final String? importType;

  const ListaCampanhasPage({
    super.key,
    required this.title,
    this.isImporting = false,
    this.importType,
  });

  @override
  State<ListaCampanhasPage> createState() => _ListaCampanhasPageState();
}

class _ListaCampanhasPageState extends State<ListaCampanhasPage> {
  final dbHelper = DatabaseHelper.instance;
  List<Campanha> campanhas = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedCampanhas = {};

  final Map<int, List<Atividade>> _atividadesPorCampanha = {};
  bool _isLoadingAtividades = false;

  @override
  void initState() {
    super.initState();
    _carregarCampanhas();
  }

  Future<void> _carregarCampanhas() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getTodasCampanhas();
    if (mounted) {
      setState(() {
        campanhas = data;
        _isLoading = false;
      });
    }
  }
  
  void _clearSelection() {
    if (mounted) {
      setState(() {
        _selectedCampanhas.clear();
        _isSelectionMode = false;
      });
    }
  }

  void _toggleSelection(int campanhaId) {
    if (mounted) {
      setState(() {
        if (_selectedCampanhas.contains(campanhaId)) {
          _selectedCampanhas.remove(campanhaId);
        } else {
          _selectedCampanhas.add(campanhaId);
        }
        _isSelectionMode = _selectedCampanhas.isNotEmpty;
      });
    }
  }

  Future<void> _deletarCampanhasSelecionadas() async {
    if (_selectedCampanhas.isEmpty || !mounted) return;

    final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: Text('Tem certeza que deseja apagar as ${_selectedCampanhas.length} campanhas selecionadas e TODOS os seus dados? Esta ação é PERMANENTE.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Apagar')),
              ],
            ));
    if (confirmar == true && mounted) {
      for (final id in _selectedCampanhas) {
        await dbHelper.deleteCampanha(id);
      }
      _clearSelection();
      await _carregarCampanhas();
    }
  }

  void _navegarParaEdicao(Campanha campanha) async {
    final bool? campanhaEditada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormCampanhaPage(
          campanhaParaEditar: campanha,
        ),
      ),
    );
    if (campanhaEditada == true && mounted) {
      _carregarCampanhas();
    }
  }
  
  void _navegarParaDetalhes(Campanha campanha) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => DetalhesCampanhaPage(campanha: campanha)))
      .then((_) => _carregarCampanhas());
  }
  
  Future<void> _carregarAtividadesDaCampanha(int campanhaId) async {
    if (_atividadesPorCampanha.containsKey(campanhaId)) return;
    if (mounted) setState(() => _isLoadingAtividades = true);
    final atividades = await dbHelper.getAtividadesDaCampanha(campanhaId);
    if (mounted) {
      setState(() {
        _atividadesPorCampanha[campanhaId] = atividades;
        _isLoadingAtividades = false;
      });
    }
  }
  
  Future<void> _iniciarImportacao(Atividade atividade) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Importação cancelada.')));
      return;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Processando arquivo..."),
          ],
        ),
      ),
    );

    try {
      final file = File(result.files.single.path!);
      final csvContent = await file.readAsString();
      
      final message = await dbHelper.importarVistoriasDeEquipe(csvContent, atividade.id!);
      
      if (mounted) {
        Navigator.of(context).pop();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Resultado da Importação'),
            content: Text(message),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
          ),
        );
        Navigator.of(context).pop(); 
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao importar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : campanhas.isEmpty
              ? _buildEmptyState()
              : widget.isImporting ? _buildImportListView() : _buildNormalListView(),
      floatingActionButton: widget.isImporting ? null : _buildAddButton(),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.title),
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection),
      title: Text('${_selectedCampanhas.length} selecionada(s)'),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: _deletarCampanhasSelecionadas,
          tooltip: 'Apagar Selecionadas',
        ),
      ],
    );
  }

  Widget _buildNormalListView() {
    return ListView.builder(
      itemCount: campanhas.length,
      itemBuilder: (context, index) {
        final campanha = campanhas[index];
        final isSelected = _selectedCampanhas.contains(campanha.id!);

        return Slidable(
          key: ValueKey(campanha.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) => _navegarParaEdicao(campanha),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                icon: Icons.edit_outlined,
                label: 'Editar',
              ),
            ],
          ),
          child: Card(
            color: isSelected ? Theme.of(context).colorScheme.secondary.withOpacity(0.2) : null,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              onTap: () => _isSelectionMode ? _toggleSelection(campanha.id!) : _navegarParaDetalhes(campanha),
              onLongPress: () => _toggleSelection(campanha.id!),
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.campaign_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(campanha.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Responsável: ${campanha.responsavel}'),
              trailing: Text(DateFormat('dd/MM/yy').format(campanha.dataCriacao)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImportListView() {
    return ListView.builder(
      itemCount: campanhas.length,
      itemBuilder: (context, index) {
        final campanha = campanhas[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExpansionTile(
            leading: Icon(Icons.campaign_outlined, color: Theme.of(context).colorScheme.primary),
            title: Text(campanha.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(campanha.responsavel),
            onExpansionChanged: (isExpanding) {
              if (isExpanding) _carregarAtividadesDaCampanha(campanha.id!);
            },
            children: [
              if (_isLoadingAtividades && !_atividadesPorCampanha.containsKey(campanha.id))
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_atividadesPorCampanha[campanha.id]?.isEmpty ?? true)
                const ListTile(
                  title: Text('Nenhuma atividade nesta campanha.'),
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                )
              else
                ..._atividadesPorCampanha[campanha.id]!.map((atividade) {
                  return ListTile(
                    title: Text(atividade.tipo),
                    subtitle: Text(atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'),
                    leading: const Icon(Icons.file_download_outlined, color: Colors.green),
                    onTap: () => _iniciarImportacao(atividade),
                  );
                })
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Nenhuma campanha encontrada.', style: Theme.of(context).textTheme.titleLarge),
          if (!widget.isImporting)
            Text('Use o botão "+" para adicionar uma nova.', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FormCampanhaPage()))
          .then((criado) {
            if (criado == true) _carregarCampanhas();
          });
      },
      tooltip: 'Adicionar Campanha',
      child: const Icon(Icons.add),
    );
  }
}