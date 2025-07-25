// lib/pages/vistorias/lista_focos_page.dart (VERSÃO CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/foco_model.dart';
import 'package:geovigilancia/models/vistoria_model.dart';
import 'package:geovigilancia/widgets/foco_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ListaFocosPage extends StatefulWidget {
  final Vistoria vistoria;
  const ListaFocosPage({super.key, required this.vistoria});

  @override
  State<ListaFocosPage> createState() => _ListaFocosPageState();
}

class _ListaFocosPageState extends State<ListaFocosPage> {
  final dbHelper = DatabaseHelper.instance;
  late Vistoria _vistoriaAtual;
  List<Foco> _focosColetados = [];
  late Future<bool> _dataLoadingFuture;
  bool _isSaving = false;
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    _vistoriaAtual = widget.vistoria;
    _dataLoadingFuture = _carregarDadosIniciais();
  }

  Future<bool> _carregarDadosIniciais() async {
    if (_vistoriaAtual.status != StatusVisita.realizada) {
      _isReadOnly = true;
    } else {
      _isReadOnly = false;
    }

    if (_vistoriaAtual.dbId != null) {
      _focosColetados = await dbHelper.getFocosDaVistoria(_vistoriaAtual.dbId!);
    }
    
    return true;
  }
  
  Future<void> _concluirVistoria() async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text('Concluir Vistoria'),
        content: const Text('Tem certeza que deseja marcar esta vistoria como concluída?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Concluir'))
        ]
      )
    ) ?? false;

    if (!confirm || !mounted) return;
    
    final resultadoFinal = _focosColetados.isEmpty ? 'Sem Foco' : 'Com Foco';
    _vistoriaAtual.resultado = resultadoFinal;
    await _salvarEstadoAtual(concluir: true, showSnackbar: false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Vistoria concluída com sucesso!'), 
        backgroundColor: Colors.green
      ));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _salvarEstadoAtual({bool showSnackbar = true, bool concluir = false}) async {
    if (_isSaving) return;
    if (mounted) setState(() => _isSaving = true);
    try {
      if (concluir) {
        _vistoriaAtual.status = StatusVisita.realizada;
        setState(() => _isReadOnly = true);
      }
      
      await dbHelper.saveFullVistoria(_vistoriaAtual, _focosColetados);
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progresso salvo!'), duration: Duration(seconds: 2), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deletarFoco(BuildContext context, Foco foco) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar o foco "${foco.tipoCriadouro}"?'),
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
      setState(() {
        _focosColetados.remove(foco);
      });
      await _salvarEstadoAtual(showSnackbar: false);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Foco removido com sucesso.'),
          backgroundColor: Colors.green,
        ));
    }
  }

  Future<void> _abrirDialogoFoco({Foco? focoParaEditar}) async {
    final result = await showDialog<Foco?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => FocoDialog(
        focoParaEditar: focoParaEditar,
        vistoriaId: _vistoriaAtual.dbId!,
      ),
    );

    if (result != null) {
      setState(() {
        if (focoParaEditar != null) {
          final index = _focosColetados.indexWhere((f) => f.id == focoParaEditar.id);
          if (index != -1) {
            _focosColetados[index] = result;
          } else {
             _focosColetados.add(result);
          }
        } else {
          _focosColetados.add(result);
        }
      });
      await _salvarEstadoAtual(showSnackbar: true);
    }
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // <<< CORREÇÃO APLICADA AQUI >>>
            Text('Vistoria: ${_vistoriaAtual.identificadorImovel ?? "ID não informado"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 20),
            _buildStatRow('Bairro:', _vistoriaAtual.nomeBairro ?? 'N/A'),
            _buildStatRow('Setor/', _vistoriaAtual.nomeSetor ?? 'N/A'),
            _buildStatRow('Tipo de Imóvel:', _vistoriaAtual.tipoImovel),
            _buildStatRow('Total de Focos:', '${_focosColetados.length}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeaderRow() {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        children: [
          Expanded(flex: 40, child: Text('TIPO DE CRIADOURO', style: headerStyle)),
          Expanded(flex: 25, child: Text('LARVAS?', style: headerStyle, textAlign: TextAlign.center)),
          Expanded(flex: 35, child: Text('TRATAMENTO', style: headerStyle, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Focos'),
        actions: _isReadOnly 
          ? []
          : [
              if (_isSaving)
                const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))))
              else ...[
                IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Salvar Progresso', onPressed: () => _salvarEstadoAtual()),
                IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Concluir Vistoria', onPressed: _concluirVistoria),
              ],
            ],
      ),
      body: FutureBuilder<bool>(
        future: _dataLoadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == false) {
            return Center(child: Text('Erro ao carregar dados da vistoria: ${snapshot.error}'));
          }
          
          return Column(
            children: [
              _buildSummaryCard(),
              _buildHeaderRow(),
              Expanded(
                child: _focosColetados.isEmpty
                  ? Center(child: Text(_isReadOnly ? 'Nenhum foco foi registrado nesta vistoria.' : 'Clique no botão "+" para adicionar o primeiro foco.', style: const TextStyle(color: Colors.grey, fontSize: 16)))
                  : SlidableAutoCloseBehavior(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _focosColetados.length,
                        itemBuilder: (context, index) {
                          final foco = _focosColetados[index];
                          return Slidable(
                            key: ValueKey(foco.id ?? foco.hashCode),
                            endActionPane: _isReadOnly ? null : ActionPane(
                              motion: const StretchMotion(),
                              extentRatio: 0.25,
                              children: [
                                SlidableAction(
                                  onPressed: (ctx) => _deletarFoco(ctx, foco),
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  icon: Icons.delete_outline,
                                  label: 'Excluir',
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: _isReadOnly ? null : () => _abrirDialogoFoco(focoParaEditar: foco),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                decoration: BoxDecoration(
                                  color: index.isOdd ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3) : Colors.transparent,
                                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.8)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 40, child: Text(foco.tipoCriadouro, style: const TextStyle(fontSize: 16))),
                                    Expanded(flex: 25, child: Icon(foco.larvasEncontradas ? Icons.check_circle : Icons.cancel, color: foco.larvasEncontradas ? Colors.green : Colors.red, size: 20)),
                                    Expanded(flex: 35, child: Text(foco.tratamentoRealizado ?? 'N/A', style: const TextStyle(fontSize: 14), textAlign: TextAlign.center)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isReadOnly ? null : FloatingActionButton.extended(
        onPressed: () => _abrirDialogoFoco(),
        tooltip: 'Adicionar Foco',
        icon: const Icon(Icons.add),
        label: const Text('Novo Foco'),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}