// lib/pages/menu/configuracoes_page.dart (VERSÃO CORRIGIDA PARA RODAR OFFLINE)

import 'package:flutter/foundation.dart'; // <<< IMPORT NECESSÁRIO ADICIONADO AQUI
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports que dependem do Firebase são comentados ou não utilizados no modo offline
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:geovigilancia/controller/login_controller.dart';

import 'package:geovigilancia/data/datasources/local/database_helper.dart';
import 'package:geovigilancia/providers/license_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Constantes UTM mantidas
const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

class ConfiguracoesPage extends StatefulWidget {
  const ConfiguracoesPage({super.key});

  @override
  State<ConfiguracoesPage> createState() => _ConfiguracoesPageState();
}

class _ConfiguracoesPageState extends State<ConfiguracoesPage> {
  String? _zonaSelecionada;
  final dbHelper = DatabaseHelper.instance;
  
  @override
  void initState() {
    super.initState();
    _carregarConfiguracoes();
  }

  Future<void> _carregarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _zonaSelecionada = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      });
    }
  }

  Future<void> _salvarConfiguracoes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zona_utm_selecionada', _zonaSelecionada!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurações salvas!'), backgroundColor: Colors.green),
      );
    }
  }
  
  Future<void> _mostrarDialogoLimpeza({
    required String titulo,
    required String conteudo,
    required VoidCallback onConfirmar,
    bool isDestructive = true,
  }) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(conteudo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red.shade700 : Theme.of(context).colorScheme.primary,
            ),
            child: Text(isDestructive ? 'CONFIRMAR' : 'SAIR'),
          ),
        ],
      ),
    );

    if (confirmado == true && mounted) {
      onConfirmar();
    }
  }

  Future<void> _handleLogout() async {
    // Como estamos em modo offline, apenas mostramos uma mensagem.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logout não aplicável em modo offline.'))
    );
  }

  Future<void> _limparTodasAsVistorias() async {
    await _mostrarDialogoLimpeza(
      titulo: 'Limpar Todas as Vistorias',
      conteudo: 'Tem certeza? TODOS os dados de vistorias e focos serão apagados permanentemente do dispositivo.',
      onConfirmar: () async {
        // A lógica de exclusão real deve estar no DatabaseHelper.
        // Por enquanto, apenas exibimos a mensagem.
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Função de apagar vistorias a ser implementada.', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ));
        }
      },
    );
  }
  
  Future<void> _arquivarColetasExportadas() async {
     await _mostrarDialogoLimpeza(
      titulo: 'Arquivar Coletas',
      conteudo: 'Isso removerá do dispositivo todas as vistorias já marcadas como exportadas. Deseja continuar?',
      onConfirmar: () async {
        if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Função de arquivar coletas a ser implementada.'),
            backgroundColor: Colors.blueAccent,
          ));
        }
      },
    );
  }

  Future<void> _diagnosticarPermissoes() async {
    await openAppSettings(); 
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LicenseProvider>(
      builder: (context, licenseProvider, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações e Gerenciamento')),
          body: _zonaSelecionada == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Conta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 2,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // <<< CORREÇÃO APLICADA AQUI (Text e kDebugMode) >>>
                                  // O kDebugMode verifica se estamos no modo de desenvolvimento.
                                  Text(kDebugMode
                                      ? 'Usuário: Modo Desenvolvedor'
                                      : 'Usuário: Não conectado'),
                                  const SizedBox(height: 8),
                                  const Text('Plano: Básico (Offline)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.logout, color: Colors.red),
                              title: const Text('Sair da Conta', style: TextStyle(color: Colors.red)),
                              onTap: _handleLogout, // A função já está segura para o modo offline.
                            ),
                          ],
                        ),
                      ),

                      const Divider(thickness: 1, height: 48),

                      const Text('Zona UTM de Exportação', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Text('Define o sistema de coordenadas para os arquivos CSV.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _zonaSelecionada,
                        isExpanded: true,
                        items: zonasUtmSirgas2000.keys.map((String zona) => DropdownMenuItem<String>(value: zona, child: Text(zona, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (String? novoValor) => setState(() => _zonaSelecionada = novoValor),
                        decoration: const InputDecoration(labelText: 'Sistema de Coordenadas', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Salvar Configuração da Zona'),
                          onPressed: _salvarConfiguracoes,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      
                      const Divider(thickness: 1, height: 48),

                      const Text('Gerenciamento de Dados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: const Text('Arquivar Vistorias Exportadas'),
                        subtitle: const Text('Apaga do dispositivo apenas as vistorias que já foram exportadas.'),
                        onTap: _arquivarColetasExportadas,
                      ),

                      const Divider(thickness: 1, height: 24),

                      const Text('Ações Perigosas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
                        title: const Text('Limpar TODAS as Vistorias'),
                        subtitle: const Text('Apaga TODAS as vistorias e focos salvos.'),
                        onTap: _limparTodasAsVistorias,
                      ),
                      
                      const Divider(thickness: 1, height: 48),
                      
                      Center(
                        child: ElevatedButton(
                          onPressed: _diagnosticarPermissoes,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[600]),
                          child: const Text('Gerenciar Permissões', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }
}