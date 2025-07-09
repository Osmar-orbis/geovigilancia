// lib/pages/bairro/detalhes_bairro_page.dart (CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/pages/menu/home_page.dart';
import 'package:geovigilancia/pages/setor/form_setor_page.dart';
import 'package:geovigilancia/pages/setor/detalhes_setor_page.dart';

class DetalhesBairroPage extends StatefulWidget {
  final Bairro bairro;
  final Atividade atividade;

  const DetalhesBairroPage(
      {super.key, required this.bairro, required this.atividade});

  @override
  State<DetalhesBairroPage> createState() => _DetalhesBairroPageState();
}

class _DetalhesBairroPageState extends State<DetalhesBairroPage> {
  late Future<List<Setor>> _setoresFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedSetores = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarSetores();
  }

  void _carregarSetores() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isSelectionMode = false;
        _selectedSetores.clear();
        _setoresFuture = dbHelper.getSetoresDoBairro(
            widget.bairro.id, widget.bairro.atividadeId);
        _isLoading = false;
      });
    }
  }

  void _toggleSelectionMode(int? setorId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedSetores.clear();
      if (_isSelectionMode && setorId != null) {
        _selectedSetores.add(setorId);
      }
    });
  }

  void _onItemSelected(int setorId) {
    setState(() {
      if (_selectedSetores.contains(setorId)) {
        _selectedSetores.remove(setorId);
        if (_selectedSetores.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedSetores.add(setorId);
      }
    });
  }

  Future<void> _deleteSetor(Setor setor) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar o setor "${setor.nome}" e todos os seus dados (vistorias, focos)? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await dbHelper.deleteSetor(setor.id!);
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Setor apagado.'), backgroundColor: Colors.red));
        _carregarSetores();
      }
    }
  }

  void _navegarParaNovoSetor() async {
    final bool? setorCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // Instancia a classe corretamente
        builder: (context) => FormSetorPage(
          bairroId: widget.bairro.id,
          bairroAtividadeId: widget.bairro.atividadeId,
        ),
      ),
    );
    if (setorCriado == true && mounted) {
      _carregarSetores();
    }
  }

  void _navegarParaEdicaoSetor(Setor setor) async {
    final bool? setorEditado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // Instancia a classe corretamente
        builder: (context) => FormSetorPage(
          bairroId: setor.bairroId,
          bairroAtividadeId: setor.bairroAtividadeId,
          quarteiraoParaEditar: setor,
        ),
      ),
    );
    if (setorEditado == true && mounted) {
      _carregarSetores();
    }
  }

  void _navegarParaDetalhesSetor(Setor setor) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => DetalhesSetorPage(
                setor: setor,
                atividade: widget.atividade,
              )),
    ).then((_) => _carregarSetores());
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedSetores.length} selecionado(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionados',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Use o deslize para apagar individualmente.')));
          },
        ),
      ],
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.bairro.nome),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (context) =>
                    const HomePage(title: 'GeoVigilância')),
            (Route<dynamic> route) => false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
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
                  Text('Detalhes do Bairro',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("ID: ${widget.bairro.id}",
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Text(
                      "Local: ${widget.bairro.municipio} - ${widget.bairro.estado.toUpperCase()}",
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Setores / Quarteirões",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FutureBuilder<List<Setor>>(
                  future: _setoresFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                       return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Erro ao carregar setores: ${snapshot.error}'));
                    }
                    final setores = snapshot.data ?? [];
                    if (setores.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Nenhum setor encontrado.\nClique no botão "+" para adicionar o primeiro.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade600),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: setores.length,
                        itemBuilder: (context, index) {
                          final setor = setores[index];
                          final isSelected =
                              _selectedSetores.contains(setor.id!);
                          return Slidable(
                            key: ValueKey(setor.id),
                            startActionPane: ActionPane(
                              motion: const DrawerMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) =>
                                      _navegarParaEdicaoSetor(setor),
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit_outlined,
                                  label: 'Editar',
                                ),
                              ],
                            ),
                            endActionPane: ActionPane(
                              motion: const BehindMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) => _deleteSetor(setor),
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline,
                                  label: 'Excluir',
                                ),
                              ],
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withAlpha(128)
                                  : null,
                              child: ListTile(
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _onItemSelected(setor.id!);
                                  } else {
                                    _navegarParaDetalhesSetor(setor);
                                  }
                                },
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode(setor.id!);
                                  }
                                },
                                leading: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  child: Icon(isSelected
                                      ? Icons.check
                                      : Icons.grid_on_outlined),
                                ),
                                title: Text("Setor: ${setor.nome}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Área: ${setor.areaHa?.toStringAsFixed(2) ?? 'N/A'} ha'),
                                trailing: const Icon(Icons.arrow_forward_ios_outlined,
                                    color: Colors.grey, size: 16,),
                                selected: isSelected,
                              ),
                            ),
                          );
                        },
                      );
                  }
                ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _navegarParaNovoSetor,
              tooltip: 'Novo Setor',
              icon: const Icon(Icons.add_road_outlined),
              label: const Text('Novo Setor'),
            ),
    );
  }
}