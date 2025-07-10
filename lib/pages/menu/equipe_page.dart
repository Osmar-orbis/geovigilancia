// lib/pages/menu/equipe_page.dart (VERSÃO CORRIGIDA PARA O BYPASS)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geovigilancia/providers/team_provider.dart';
import 'package:geovigilancia/providers/license_provider.dart';
import 'package:geovigilancia/controller/login_controller.dart';

class EquipePage extends StatefulWidget {
  const EquipePage({super.key});

  @override
  State<EquipePage> createState() => _EquipePageState();
}

class _EquipePageState extends State<EquipePage> {
  final _formKey = GlobalKey<FormState>();
  final _liderController = TextEditingController();
  final _ajudantesController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      _liderController.text = teamProvider.lider ?? '';
      _ajudantesController.text = teamProvider.ajudantes ?? '';

      // <<< MUDANÇA PRINCIPAL AQUI >>>
      // Comentamos a chamada ao loadLicense, pois ela espera o User do Firebase
      // que não está disponível no modo de bypass.
      /*
      final user = context.read<LoginController>().user;
      if (user != null) {
        context.read<LicenseProvider>().loadLicense(user);
      }
      */
    });
  }

  @override
  void dispose() {
    _liderController.dispose();
    _ajudantesController.dispose();
    super.dispose();
  }

  void _continuar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      await teamProvider.setTeam(
        _liderController.text.trim(),
        _ajudantesController.text.trim(),
      );

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // A tela não precisa mais ser um Consumer do LicenseProvider,
    // pois não estamos mais observando o estado de carregamento da licença.
    return Scaffold(
      appBar: AppBar(title: const Text('Identificação da Equipe')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.groups_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                'Antes de começar, por favor, identifique a equipe de hoje.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _liderController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Líder da Equipe',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'O nome do líder é obrigatório'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ajudantesController,
                decoration: const InputDecoration(
                  labelText: 'Nomes dos Ajudantes',
                  hintText: 'Ex: João, Maria, Pedro',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _continuar,
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Continuar para o Menu'),
              )
            ],
          ),
        ),
      ),
    );
  }
}