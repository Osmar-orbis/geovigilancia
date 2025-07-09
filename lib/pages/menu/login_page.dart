// lib/pages/menu/login_page.dart (COM BOTÃO DE DESENVOLVEDOR)

// <<< PASSO 1: IMPORTAR A BIBLIOTECA foundation >>>
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geovigilancia/services/auth_service.dart';
import 'package:geovigilancia/pages/menu/register_page.dart';
import 'package:geovigilancia/pages/menu/forgot_password_page.dart';

// As constantes de cores permanecem as mesmas
const Color primaryColor = Color(0xFF1D4433);
const Color secondaryTextColor = Color(0xFF617359);
const Color backgroundColor = Color(0xFFF3F3F4);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // A lógica de login normal permanece a mesma
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // A navegação é controlada pelo Consumer no main.dart
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocorreu um erro. Tente novamente.';
      if (e.code == 'user-not-found' || e.code == 'invalid-email' || e.code == 'invalid-credential') {
        errorMessage = 'Email ou senha inválidos.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Senha incorreta. Por favor, tente novamente.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao fazer login: ${e.toString()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // ... (Logo e textos de boas-vindas - sem alterações)
              const SizedBox(height: 40),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/logo_2.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Bem-vindo de volta!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 8),
              const Text('Faça login para continuar', style: TextStyle(fontSize: 16, color: secondaryTextColor)),
              const SizedBox(height: 40),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ... (Campos de email e senha - sem alterações)
                    TextFormField(
                      controller: _emailController,
                      // ...
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      // ...
                    ),
                    
                    // ... (Botão "Esqueci minha senha" - sem alterações)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordPage()));
                        },
                        child: const Text('Esqueci minha senha', style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // ... (Botão "Entrar" - sem alterações)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        // ...
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    
                    // <<< PASSO 2: ADICIONAR O BOTÃO DE DESENVOLVEDOR >>>
                    // A constante kDebugMode garante que este botão só apareça em builds de depuração.
                    if (kDebugMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () {
                            // <<< PASSO 3: NAVEGAÇÃO DIRETA >>>
                            // Navega para a tela de equipe, substituindo a pilha de navegação
                            Navigator.pushReplacementNamed(context, '/equipe');
                          },
                          child: const Text(
                            'Pular Login (Modo DEV)',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    
                    // ... (Divisor "ou" e botão "Criar nova conta" - sem alterações)
                    const SizedBox(height: 16), // Ajuste de espaçamento
                    Row(
                      // ...
                    ),
                    const SizedBox(height: 16), // Ajuste de espaçamento
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
                        },
                        // ...
                        child: const Text('Criar nova conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}