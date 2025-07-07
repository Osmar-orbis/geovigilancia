// lib/pages/campanhas/detalhes_campanha_page.dart (NOVO ARQUIVO)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/campanha_model.dart';
import 'package:geovigilancia/models/atividade_model.dart';
import 'package:geovigilancia/pages/atividades/form_atividade_page.dart';
import 'package:geovigilancia/pages/atividades/detalhes_atividade_page.dart';
import 'package:geovigilancia/pages/menu/home_page.dart';

class DetalhesCampanhaPage extends StatefulWidget {
  final Campanha campanha;
  const DetalhesCampanhaPage({super.key, required this.campanha});

  @override
  State<DetalhesCampanhaPage> createState() => _DetalhesCampanhaPageState();
}

class _DetalhesCampanhaPageState extends State<DetalhesCampanhaPage> {
  late Future<List<Atividade>> _atividadesFuture;
  final dbHelper = DatabaseHelper.instance;
  
  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

  void _carregarAtividades() {
    if (mounted) {
      setState(() {
        _atividadesFuture = dbHelper.getAtividadesDaCampanha(widget.campanha.id!);
      });
    }
  }

  void _navegarParaNovaAtividade() async {
    final bool? atividadeCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormAtividadePage(campanhaId: widget.campanha.id!),
      ),
    );
    if (atividadeCriada == true) {
      _carregarAtividades();
    }
  }

  void _navegarParaDetalhesAtividade(Atividade atividade) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesAtividadePage(atividade: atividade)),
    ).then((_) => _carregarAtividades());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.campanha.nome),
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
      ),
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
                   Text('Detalhes da Campanha', style: Theme.of(context).textTheme.titleLarge),
                   const Divider(height: 20),
                  Text("Órgão: ${widget.campanha.orgao}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Responsável: ${widget.campanha.responsavel}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                   Text('Data de Criação: ${DateFormat('dd/MM/yyyy').format(widget.campanha.dataCriacao)}', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Atividades da Campanha",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Atividade>>(
              future: _atividadesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar atividades: ${snapshot.error}'));
                }

                final atividades = snapshot.data ?? [];

                if (atividades.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma atividade encontrada.\nClique no botão "+" para adicionar a primeira.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: atividades.length,
                  itemBuilder: (context, index) {
                    final atividade = atividades[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        onTap: () => _navegarParaDetalhesAtividade(atividade),
                        leading: const CircleAvatar(child: Icon(Icons.biotech_outlined)),
                        title: Text(atividade.tipo, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarParaNovaAtividade,
        tooltip: 'Nova Atividade',
        icon: const Icon(Icons.add_task),
        label: const Text('Nova Atividade'),
      ),
    );
  }
}