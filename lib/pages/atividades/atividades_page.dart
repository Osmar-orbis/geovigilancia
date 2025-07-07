// lib/pages/atividades/atividades_page.dart (VERSÃO CORRIGIDA E ADAPTADA PARA GEOVIGILÂNCIA)

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

// Importações dos seus arquivos
import '../../data/datasources/local/database_helper.dart';
import '../../models/atividade_model.dart';
import '../../models/campanha_model.dart';
import 'form_atividade_page.dart';

// Import temporariamente comentado para simplificar e garantir a compilação.
// Será necessário criar a página 'detalhes_bairro_page' para reativá-lo.
// import 'detalhes_atividade_page.dart';

class AtividadesPage extends StatefulWidget {
  // <<< CORREÇÃO 1: Recebe um objeto Campanha >>>
  final Campanha campanha;

  const AtividadesPage({
    super.key,
    required this.campanha,
  });

  @override
  State<AtividadesPage> createState() => _AtividadesPageState();
}

class _AtividadesPageState extends State<AtividadesPage> {
  final dbHelper = DatabaseHelper.instance;
  late Future<List<Atividade>> _atividadesFuture;

  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

  void _carregarAtividades() {
    setState(() {
      // <<< CORREÇÃO 2: Chama o método correto do DB Helper >>>
      _atividadesFuture = dbHelper.getAtividadesDaCampanha(widget.campanha.id!);
    });
  }

  Future<void> _mostrarDialogoDeConfirmacao(Atividade atividade) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja excluir a atividade "${atividade.tipo}" e todos os seus dados?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Excluir'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    
    if (confirmar == true && mounted) {
      await dbHelper.deleteAtividade(atividade.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atividade excluída com sucesso!'), backgroundColor: Colors.red),
      );
      _carregarAtividades();
    }
  }

  void _navegarParaFormularioAtividade() async {
    final bool? atividadeCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        // <<< CORREÇÃO 3: Passa 'campanhaId' em vez de 'projetoId' >>>
        builder: (context) => FormAtividadePage(campanhaId: widget.campanha.id!),
      ),
    );
    if (atividadeCriada == true && mounted) {
      _carregarAtividades();
    }
  }
  
  void _navegarParaEdicao(Atividade atividade) async {
    final bool? atividadeEditada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormAtividadePage(
          // <<< CORREÇÃO 4: Usa 'campanhaId' do objeto 'atividade' >>>
          campanhaId: atividade.campanhaId,
          atividadeParaEditar: atividade,
        ),
      ),
    );
    if (atividadeEditada == true && mounted) {
      _carregarAtividades();
    }
  }
  
  // A navegação para detalhes da atividade foi comentada para evitar erros,
  // pois a página de detalhes ainda não foi criada/adaptada.
  void _navegarParaDetalhes(Atividade atividade) {
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => DetalhesAtividadePage(atividade: atividade),
    //   ),
    // );
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navegação para detalhes da atividade em desenvolvimento.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // <<< CORREÇÃO 5: Usa o nome da campanha no título >>>
        title: Text('Atividades de ${widget.campanha.nome}'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Atividade>>(
        future: _atividadesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar atividades: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma atividade encontrada.\nToque no botão + para adicionar a primeira!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          final atividades = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: atividades.length,
            itemBuilder: (context, index) {
              final atividade = atividades[index];
              
              return Slidable(
                key: ValueKey(atividade.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (_) => _navegarParaEdicao(atividade),
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const StretchMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => _mostrarDialogoDeConfirmacao(atividade),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete_outline,
                      label: 'Excluir',
                    ),
                  ],
                ),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text((index + 1).toString())),
                    title: Text(
                      atividade.tipo,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'}\nCriado em: ${DateFormat('dd/MM/yyyy HH:mm').format(atividade.dataCriacao)}',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _navegarParaDetalhes(atividade),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarParaFormularioAtividade,
        icon: const Icon(Icons.add),
        label: const Text('Nova Atividade'),
        tooltip: 'Adicionar Nova Atividade',
      ),
    );
  }
}