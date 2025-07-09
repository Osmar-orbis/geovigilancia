// lib/services/pdf_service.dart (ADAPTADO PARA GEOVIGILÂNCIA)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
// <<< MUDANÇA: Imports adaptados para os novos modelos >>>
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:geovigilancia/models/setor_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/services/analysis_service.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_android/path_provider_android.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import 'package:geovigilancia/models/analise_epidemiologica_result_model.dart';


class PdfService {

  // A lógica de permissão e salvamento permanece a mesma
  Future<bool> _requestPermission() async {
    Permission permission;
    if (Platform.isAndroid) {
      // Para Android 13+ pode ser necessário granular permissions
      permission = Permission.manageExternalStorage;
    } else {
      permission = Permission.storage;
    }
    if (await permission.isGranted) return true;
    var result = await permission.request();
    return result == PermissionStatus.granted;
  }
  
  Future<Directory?> getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Este plugin foi descontinuado, mas ainda funciona para muitas versões.
      // Para o futuro, pode ser necessário usar 'external_path'.
      return Directory('/storage/emulated/0/Download');
    }
    return await getApplicationDocumentsDirectory();
  }

  Future<void> _salvarEAbriPdf(BuildContext context, pw.Document pdf, String nomeArquivo) async {
    try {
      if (!await _requestPermission()) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissão de armazenamento negada.'), backgroundColor: Colors.red));
        return;
      }
      final downloadsDirectory = await getDownloadsDirectory();
      if (downloadsDirectory == null) {
         if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não foi possível encontrar a pasta de Downloads.'), backgroundColor: Colors.red));
         return;
      }
      
      final relatoriosDir = Directory('${downloadsDirectory.path}/GeoVigilancia/Relatorios');
      if (!await relatoriosDir.exists()) await relatoriosDir.create(recursive: true);
      
      final path = '${relatoriosDir.path}/$nomeArquivo';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: const Text('Exportação Concluída'),
            content: Text('O relatório foi salvo em: ${relatoriosDir.path}. Deseja abri-lo?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar')),
              FilledButton(onPressed: (){
                OpenFile.open(path);
                Navigator.of(ctx).pop();
              }, child: const Text('Abrir Arquivo')),
            ],
          )
        );
      }
    } catch (e) {
      debugPrint("Erro ao salvar/abrir PDF: $e");
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar o PDF: $e')));
    }
  }

  // --- FUNÇÕES PÚBLICAS DE GERAÇÃO DE PDF ---

  // <<< MUDANÇA: Nova função principal para gerar o relatório de vigilância >>>
  Future<void> gerarRelatorioDeVistoriasPdf({
    required BuildContext context,
    required String tituloRelatorio, // Ex: "Relatório do Setor 01"
    required List<Vistoria> vistorias,
    pw.ImageProvider? graficoImagem, // Opcional, para gráficos futuros
  }) async {
    if (vistorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nenhuma vistoria para gerar relatório.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Gerando relatório PDF...'),
      duration: Duration(seconds: 10),
    ));

    final dbHelper = DatabaseHelper.instance;
    final analysisService = AnalysisService();
    
    // Busca todos os focos associados às vistorias
    final allFocos = <Foco>[];
    for(final vistoria in vistorias) {
      if(vistoria.dbId != null) {
        allFocos.addAll(await dbHelper.getFocosDaVistoria(vistoria.dbId!));
      }
    }
    
    // Realiza a análise epidemiológica
    final analise = analysisService.getAnaliseEpidemiologica(vistorias, allFocos);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (pw.Context ctx) => _buildHeader('Relatório de Campo', tituloRelatorio),
        footer: (pw.Context ctx) => _buildFooter(),
        build: (pw.Context ctx) {
          return [
            pw.Text(
              'Resumo Epidemiológico',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
              textAlign: pw.TextAlign.center,
            ),
            pw.Divider(height: 20),
            _buildTabelaResumoEpidemiologico(analise),
            
            if (analise.distribuicaoCriadouros.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Distribuição de Criadouros',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              _buildTabelaCriadouros(analise),
            ],

             if (analise.warnings.isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Alertas Gerados',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.red),
              ),
              pw.SizedBox(height: 5),
              ...analise.warnings.map((w) => pw.Bullet(text: w)),
            ]
          ];
        },
      ),
    );
    
    final nomeArquivoSanitizado = tituloRelatorio.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final nomeArquivo = 'Relatorio_Vigilancia_$nomeArquivoSanitizado.pdf';
    await _salvarEAbriPdf(context, pdf, nomeArquivo);
  }


  // --- WIDGETS AUXILIARES PARA CONSTRUÇÃO DE PDF ---

  pw.Widget _buildHeader(String titulo, String subtitulo) {
    return pw.Container(
      alignment: pw.Alignment.centerLeft,
      margin: const pw.EdgeInsets.only(bottom: 20.0),
      padding: const pw.EdgeInsets.only(bottom: 8.0),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 2))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(titulo, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.SizedBox(height: 5),
              pw.Text(subtitulo),
            ],
          ),
          pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Center(
      child: pw.Text(
        'Documento gerado pelo GeoVigilância', // <<< MUDANÇA
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }
  
  // <<< MUDANÇA: Novo widget para a tabela de resumo epidemiológico >>>
  pw.Widget _buildTabelaResumoEpidemiologico(AnaliseEpidemiologicaResult analise) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
      children: [
        _buildTableRow('Total de Imóveis', analise.totalImoveis.toString()),
        _buildTableRow('Imóveis Trabalhados', analise.totalImoveisTrabalhados.toString()),
        _buildTableRow('Imóveis com Foco', analise.totalImoveisComFoco.toString()),
        _buildTableRow('Total de Focos Encontrados', analise.totalFocosEncontrados.toString()),
        _buildTableRow('Total de Focos Positivos', analise.totalFocosPositivos.toString()),
        _buildTableRow('Índice de Infestação Predial (IIP)', '${analise.indiceInfestacaoPredial.toStringAsFixed(2)}%'),
        _buildTableRow('Índice de Breteau (IB)', analise.indiceBreteau.toStringAsFixed(2)),
        _buildTableRow('Imóveis Fechados / Recusados', '${analise.totalFechados} / ${analise.totalRecusas}'),
        _buildTableRow('Índice de Pendência', '${analise.indicePendencia.toStringAsFixed(2)}%'),
      ]
    );
  }

  // <<< MUDANÇA: Novo widget para a tabela de criadouros >>>
  pw.Widget _buildTabelaCriadouros(AnaliseEpidemiologicaResult analise) {
    final headers = ['Tipo de Criadouro', 'Quantidade', '% do Total'];
    
    final data = analise.distribuicaoCriadouros.entries.map((entry) {
      final porcentagem = (entry.value / analise.totalFocosEncontrados) * 100;
      return [
        entry.key,
        entry.value.toString(),
        '${porcentagem.toStringAsFixed(1)}%',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
      },
    );
  }

  // Helper para criar linhas da tabela de resumo
  pw.TableRow _buildTableRow(String metrica, String valor) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(metrica, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(valor, textAlign: pw.TextAlign.right),
        ),
      ]
    );
  }
}