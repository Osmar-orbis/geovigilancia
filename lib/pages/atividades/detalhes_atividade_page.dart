// lib/pages/atividades/detalhes_atividade_page.dart (VERSÃO CORRIGIDA E ADAPTADA PARA GEOVIGILÂNCIA)

// lib/pages/atividades/detalhes_atividade_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

// Importações de modelos e páginas
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/pages/menu/home_page.dart';
import 'package:geovigilancia/pages/bairro/form_bairro_page.dart';

// <<< ADICIONE ESTA LINHA ABAIXO >>>
import 'package:geovigilancia/pages/bairro/detalhes_bairro_page.dart'; 


class DetalhesAtividadePage extends StatefulWidget {
  final Atividade atividade;
  const DetalhesAtividadePage({super.key, required this.atividade});

  @override
  State<DetalhesAtividadePage> createState() => _DetalhesAtividadePageState();
}

class _DetalhesAtividadePageState extends State<DetalhesAtividadePage> {
  // <<< CORREÇÃO 1: O Future agora busca uma lista de Bairro >>>
  late Future<List<Bairro>> _bairrosFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  // O Set agora guarda o ID do bairro (que é uma String)
  final Set<String> _selectedBairros = {};

  @override
  void initState() {
    super.initState();
    _carregarBairros();
  }

  void _carregarBairros() {
    if (mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedBairros.clear();
        // <<< CORREÇÃO 2: Chama o método correto do DB Helper >>>
        _bairrosFuture = dbHelper.getBairrosDaAtividade(widget.atividade.id!);
      });
    }
  }

  void _toggleSelectionMode(String? bairroId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedBairros.clear();
      if (_isSelectionMode && bairroId != null) {
        _selectedBairros.add(bairroId);
      }
    });
  }

  void _onItemSelected(String bairroId) {
    setState(() {
      if (_selectedBairros.contains(bairroId)) {
        _selectedBairros.remove(bairroId);
        if (_selectedBairros.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedBairros.add(bairroId);
      }
    });
  }
  
  // <<< CORREÇÃO 3: Lógica de exclusão adaptada para Bairro >>>
  Future<void> _deleteBairro(Bairro bairro) async {
     final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar o bairro "${bairro.nome}" e todos os seus dados? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await dbHelper.deleteBairro(bairro.id, bairro.atividadeId);
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bairro apagado.'),
          backgroundColor: Colors.red));
      _carregarBairros();
    }
  }

  // <<< CORREÇÃO 4: Navegação adaptada para Bairro >>>
  void _navegarParaNovoBairro() async {
    final bool? bairroCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormBairroPage(atividadeId: widget.atividade.id!),
      ),
    );
    if (bairroCriado == true && mounted) {
      _carregarBairros();
    }
  }

  void _navegarParaEdicaoBairro(Bairro bairro) async {
    final bool? bairroEditado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormBairroPage(
          atividadeId: bairro.atividadeId,
          bairroParaEditar: bairro,
        ),
      ),
    );
    if (bairroEditado == true && mounted) {
      _carregarBairros();
    }
  }

  void _navegarParaDetalhesBairro(Bairro bairro) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesBairroPage(
        bairro: bairro,
        atividade: widget.atividade,
      )),
    ).then((_) => _carregarBairros());
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedBairros.length} selecionado(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionados',
          onPressed: () { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use o deslize para apagar individualmente.')));
           },
        ),
      ],
    );
  }
  
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.atividade.tipo),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage(title: 'GeoVigilância')),
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
                  Text('Detalhes da Atividade', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("Descrição: ${widget.atividade.descricao.isNotEmpty ? widget.atividade.descricao : 'N/A'}",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Data de Criação: ${DateFormat('dd/MM/yyyy').format(widget.atividade.dataCriacao)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Bairros da Atividade", // Título adaptado
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Bairro>>( // <<< CORREÇÃO: Tipagem para Bairro >>>
              future: _bairrosFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar bairros: ${snapshot.error}'));
                }

                final bairros = snapshot.data ?? [];

                if (bairros.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum bairro encontrado.\nClique no botão "+" para adicionar o primeiro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: bairros.length,
                  itemBuilder: (context, index) {
                    final bairro = bairros[index];
                    final isSelected = _selectedBairros.contains(bairro.id);
                    return Slidable(
                      key: ValueKey(bairro.id),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) => _navegarParaEdicaoBairro(bairro),
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
                            onPressed: (context) => _deleteBairro(bairro),
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline,
                            label: 'Excluir',
                          ),
                        ],
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(128) : null,
                        child: ListTile(
                          onTap: () {
                            if (_isSelectionMode) {
                              _onItemSelected(bairro.id);
                            } else {
                              _navegarParaDetalhesBairro(bairro);
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              _toggleSelectionMode(bairro.id);
                            }
                          },
                          leading: CircleAvatar(
                            backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                            // Ícone adaptado para bairro/localidade
                            child: Icon(isSelected ? Icons.check : Icons.location_city_outlined),
                          ),
                          title: Text(bairro.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${bairro.id}\n${bairro.municipio} - ${bairro.estado}'),
                          trailing: const Icon(Icons.swap_horiz_outlined, color: Colors.grey),
                          selected: isSelected,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // SpeedDial removido, pois a única ação agora é adicionar bairro
      floatingActionButton: _isSelectionMode 
        ? null 
        : FloatingActionButton.extended(
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Novo Bairro'),
            onPressed: _navegarParaNovoBairro,
          ),
    );
  }
}