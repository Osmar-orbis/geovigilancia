// lib/pages/setor/detalhes_setor_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/pages/menu/home_page.dart';
import 'package:geovigilancia/pages/vistorias/form_vistoria_page.dart';

class DetalhesSetorPage extends StatefulWidget {
  final Setor setor;
  final Atividade atividade;

  const DetalhesSetorPage(
      {super.key, required this.setor, required this.atividade});

  @override
  State<DetalhesSetorPage> createState() => _DetalhesSetorPageState();
}

class _DetalhesSetorPageState extends State<DetalhesSetorPage> {
  late Future<List<Vistoria>> _vistoriasFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedItens = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  void _carregarDados() {
    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedItens.clear();
        _vistoriasFuture = dbHelper.getVistoriasDoSetor(widget.setor.id!);
      });
    }
  }

  Future<void> _navegarParaNovaVistoria() async {
    // Busca o objeto completo para ter o nome do bairro
    final setoresDoBairro = await dbHelper.getSetoresDoBairro(
        widget.setor.bairroId, widget.setor.bairroAtividadeId);
    final setorCompleto = setoresDoBairro.firstWhere(
      (q) => q.id == widget.setor.id,
      orElse: () => widget.setor,
    );

    final bool? recarregar = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => FormVistoriaPage(quarteirao: setorCompleto)),
    );

    if (recarregar == true && mounted) {
      _carregarDados();
    }
  }

  Future<void> _navegarParaDetalhesVistoria(Vistoria vistoria) async {
    final recarregar = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormVistoriaPage(vistoriaParaEditar: vistoria),
      ),
    );
    if (recarregar == true && mounted) {
      _carregarDados();
    }
  }

  void _toggleSelectionMode(int? itemId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItens.clear();
      if (_isSelectionMode && itemId != null) {
        _selectedItens.add(itemId);
      }
    });
  }

  void _onItemSelected(int itemId) {
    setState(() {
      if (_selectedItens.contains(itemId)) {
        _selectedItens.remove(itemId);
        if (_selectedItens.isEmpty) _isSelectionMode = false;
      } else {
        _selectedItens.add(itemId);
      }
    });
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItens.isEmpty || !mounted) return;

    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar as ${_selectedItens.length} vistorias selecionadas?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Apagar')),
        ],
      ),
    );

    if (confirmar == true) {
      for (var id in _selectedItens) {
        await dbHelper.deleteVistoria(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${_selectedItens.length} vistorias apagadas.'),
            backgroundColor: Colors.green));
      }
      _carregarDados();
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Setor: ${widget.setor.nome}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          tooltip: 'Ver Análise do Setor',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Página de análise em desenvolvimento.')));
          },
        ),
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) => const HomePage(title: 'GeoVigilância')),
            (Route<dynamic> route) => false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _toggleSelectionMode(null)),
              title: Text('${_selectedItens.length} selecionados'),
              actions: [
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _deleteSelectedItems,
                    tooltip: 'Apagar Selecionados')
              ],
            )
          : _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Detalhes do Setor/Quarteirão',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text(
                      "Atividade: ${widget.atividade.tipo}",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Bairro: ${widget.setor.bairroNome ?? 'Não informado'}",
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              "Vistorias do Setor",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Vistoria>>(
              future: _vistoriasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }

                final vistorias = snapshot.data ?? [];
                if (vistorias.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma vistoria registrada.\nClique no botão "+" para iniciar.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }
                return _buildListaDeVistorias(vistorias);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _navegarParaNovaVistoria,
              tooltip: 'Nova Vistoria',
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Nova Vistoria'),
            ),
    );
  }

  Widget _buildListaDeVistorias(List<Vistoria> vistorias) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: vistorias.length,
      itemBuilder: (context, index) {
        final vistoria = vistorias[index];
        final isSelected = _selectedItens.contains(vistoria.dbId!);
        final dataFormatada =
            DateFormat('dd/MM/yyyy HH:mm').format(vistoria.dataColeta!);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128)
              : null,
          child: ListTile(
            onTap: () => _isSelectionMode
                ? _onItemSelected(vistoria.dbId!)
                : _navegarParaDetalhesVistoria(vistoria),
            onLongPress: () => _toggleSelectionMode(vistoria.dbId!),
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : vistoria.status.cor,
              child: Icon(
                  isSelected ? Icons.check : vistoria.status.icone,
                  color: Colors.white),
            ),
            title: Text(vistoria.identificadorImovel ?? 'ID não informado',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                'Coletado em: $dataFormatada\nResultado: ${vistoria.resultado ?? vistoria.status.name}'),
            trailing: _isSelectionMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      _selectedItens.clear();
                      _selectedItens.add(vistoria.dbId!);
                      _deleteSelectedItems();
                    },
                  ),
            selected: isSelected,
          ),
        );
      },
    );
  }
}