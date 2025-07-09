// lib/pages/setor/form_setor_page.dart (ADAPTADO)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/setor_model.dart'; // Importa o modelo Setor

class FormSetorPage extends StatefulWidget {
  // Parâmetros adaptados para Bairro e Setor
  final String bairroId;
  final int bairroAtividadeId;
  final Setor? setorParaEditar;

  const FormSetorPage({
    super.key,
    required this.bairroId,
    required this.bairroAtividadeId,
    this.setorParaEditar,
  });

  bool get isEditing => setorParaEditar != null;

  @override
  State<FormSetorPage> createState() => _FormSetorPageState();
}

class _FormSetorPageState extends State<FormSetorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _areaController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Preenche o formulário se estiver editando um quarteirão existente
    if (widget.isEditing) {
      final setor = widget.setorParaEditar!;
      _nomeController.text = setor.nome;
      _areaController.text = setor.areaHa?.toString().replaceAll('.', ',') ?? '';
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  // Função de salvar adaptada para Setor
  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      final setor = Setor(
        id: widget.isEditing ? widget.setorParaEditar!.id : null,
        bairroId: widget.bairroId,
        bairroAtividadeId: widget.bairroAtividadeId,
        nome: _nomeController.text.trim(),
        areaHa: double.tryParse(_areaController.text.replaceAll(',', '.')),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        
        if (widget.isEditing) {
          await dbHelper.database.then((db) => db.update(
            'setores',
            setor.toMap(),
            where: 'id = ?',
            whereArgs: [setor.id],
          ));
        } else {
          await dbHelper.insertSetor(setor);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Setor/Quarteirão ${widget.isEditing ? 'atualizado' : 'criado'} com sucesso!'), 
              backgroundColor: Colors.green
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar setor: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Setor' : 'Novo Setor/Quarteirão'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome ou Código do Setor/Quarteirão',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do setor é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Campos de idade, espécie e espaçamento foram removidos
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                  labelText: 'Área (ha) - Opcional',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.area_chart_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[,.]?\d*')),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvar,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Setor'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}