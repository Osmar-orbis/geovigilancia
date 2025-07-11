// lib/pages/bairro/form_bairro_page.dart (VERSÃO CORRIGIDA E SEGURA)

import 'package:flutter/material.dart';
import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/models/bairro_model.dart';
import 'package:sqflite/sqflite.dart';

class FormBairroPage extends StatefulWidget {
  final int atividadeId;
  final Bairro? bairroParaEditar; 

  const FormBairroPage({
    super.key,
    required this.atividadeId,
    this.bairroParaEditar, 
  });

  bool get isEditing => bairroParaEditar != null;

  @override
  State<FormBairroPage> createState() => _FormBairroPageState();
}

class _FormBairroPageState extends State<FormBairroPage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nomeController = TextEditingController();
  final _municipioController = TextEditingController();
  final _estadoController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final bairro = widget.bairroParaEditar!;
      _idController.text = bairro.id;
      _nomeController.text = bairro.nome;
      _municipioController.text = bairro.municipio;
      _estadoController.text = bairro.estado;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nomeController.dispose();
    _municipioController.dispose();
    _estadoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSaving = true);

      // O ID do bairro não pode ser alterado na edição,
      // então usamos o ID original.
      final bairroId = widget.isEditing ? widget.bairroParaEditar!.id : _idController.text.trim();
      
      final bairro = Bairro(
        id: bairroId,
        atividadeId: widget.atividadeId,
        nome: _nomeController.text.trim(),
        municipio: _municipioController.text.trim(),
        estado: _estadoController.text.trim().toUpperCase(),
      );

      try {
        final dbHelper = DatabaseHelper.instance;
        
        // <<< CORREÇÃO PRINCIPAL AQUI >>>
        if (widget.isEditing) {
          // Em vez de deletar e inserir, usamos o método de atualização.
          // Você precisará adicionar este método ao seu DatabaseHelper.
          // Ex: Future<void> updateBairro(Bairro b) async => await (await database).update(...);
          await dbHelper.database.then((db) => db.update(
            'bairros', 
            bairro.toMap(),
            where: 'id = ? AND atividadeId = ?',
            whereArgs: [bairro.id, bairro.atividadeId]
          ));
        } else {
          await dbHelper.insertBairro(bairro);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bairro ${widget.isEditing ? 'atualizado' : 'criado'} com sucesso!'),
              backgroundColor: Colors.green
            ),
          );
          Navigator.of(context).pop(true);
        }
      } on DatabaseException catch (e) {
        if (e.isUniqueConstraintError() && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: O ID "${bairro.id}" já existe para esta atividade.'), backgroundColor: Colors.red),
          );
        } else if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro de banco de dados ao salvar: $e'), backgroundColor: Colors.red),
          );
        }
      } 
      catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ocorreu um erro inesperado: $e'), backgroundColor: Colors.red),
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
        title: Text(widget.isEditing ? 'Editar Bairro' : 'Novo Bairro'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _idController,
                // O ID não pode ser editado, pois é parte da chave primária.
                enabled: !widget.isEditing,
                decoration: InputDecoration(
                  labelText: 'ID do Bairro (Código Oficial)',
                  helperText: widget.isEditing ? 'O ID não pode ser alterado.' : null,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  // Estilo visual para indicar que o campo está desabilitado.
                  filled: widget.isEditing,
                  fillColor: Colors.grey.shade200,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O ID do bairro é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Bairro',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome do bairro é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _municipioController,
                decoration: const InputDecoration(
                  labelText: 'Município',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O município é obrigatório.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estadoController,
                maxLength: 2,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Estado (UF)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public_outlined),
                  counterText: "",
                ),
                 validator: (value) {
                  if (value == null || value.trim().length != 2) {
                    return 'Informe a sigla do estado (ex: SP).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvar,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Bairro'),
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