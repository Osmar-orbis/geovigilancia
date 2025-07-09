// lib/pages/menu/home_page.dart (CORRIGIDO E ADAPTADO)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geovigilancia/pages/campanhas/lista_campanhas_page.dart';
import 'package:geovigilancia/pages/menu/configuracoes_page.dart';
import 'package:geovigilancia/providers/license_provider.dart';
import 'package:geovigilancia/widgets/menu_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});
  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  void _mostrarDialogoImportacao(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Text('O que você deseja importar?', style: Theme.of(context).textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.table_rows_outlined, color: Colors.green),
            title: const Text('Dados de Vistorias de Campo'),
            subtitle: const Text('Importa um arquivo CSV com dados de vistorias e focos.'),
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const ListaCampanhasPage(
                  title: 'Importar Vistorias para...',
                  isImporting: true,
                  importType: 'vistorias',
                ),
              ));
            },
          ),
          ListTile(
            leading: Icon(Icons.map_outlined, color: Colors.blue.shade700),
            title: const Text('Plano de Trabalho (GeoJSON)'),
            subtitle: const Text('Importa polígonos de setores ou pontos de imóveis.'),
            onTap: () {
               Navigator.of(ctx).pop();
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Função de planejamento em desenvolvimento.')));
            },
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoExportacao(BuildContext context) {
    // final exportService = ExportService(); // Crie esta instância quando o serviço for implementado
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
              child: Text('Escolha o que deseja exportar',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined, color: Colors.green),
              title: const Text('Dados de Vistoria (CSV)'),
              subtitle: const Text('Exporta os dados de vistorias e focos encontrados.'),
              onTap: () {
                Navigator.of(ctx).pop(); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Função de exportação em desenvolvimento.')));
              },
            ),
            const Divider(), 
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: Colors.purple),
              title: const Text('Relatório de Análise (PDF)'),
              subtitle: const Text('Gera um relatório consolidado em PDF.'),
              onTap: () {
                 Navigator.of(ctx).pop();
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Função de relatório em desenvolvimento.')));
              },
            ),
          ],
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final licenseProvider = context.watch<LicenseProvider>();
    
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          childAspectRatio: 1.0,
          children: [
            MenuCard(
              icon: Icons.biotech_outlined,
              label: 'Campanhas e Vistorias',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListaCampanhasPage(title: 'Minhas Campanhas'),
                ),
              ),
            ),
            MenuCard(
              icon: Icons.analytics_outlined,
              label: 'Análise de Dados',
              onTap: () {
                if (licenseProvider.licenseInfo?.canUseAnalysis ?? false) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Página de análise em desenvolvimento.')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Módulo de Análise não incluído no seu plano.'),
                      backgroundColor: Colors.orange,
                    )
                  );
                }
              },
            ),
            MenuCard(
              icon: Icons.file_download_outlined,
              label: 'Importar Dados',
              onTap: () => _mostrarDialogoImportacao(context),
            ),
            MenuCard(
              icon: Icons.upload_file_outlined,
              label: 'Exportar Dados',
              onTap: () => _mostrarDialogoExportacao(context),
            ),
            MenuCard(
              icon: Icons.settings_outlined,
              label: 'Configurações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConfiguracoesPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}