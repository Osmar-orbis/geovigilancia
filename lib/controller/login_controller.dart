// lib/controller/login_controller.dart (VERSÃO ROBUSTA E SEGURA)

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import do Firebase é reativado
import 'package:geovigilancia/services/auth_service.dart';

class LoginController with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoggedIn = false;
  User? _user; // Usamos o tipo real do Firebase, que pode ser nulo.
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  User? get user => _user;
  bool get isInitialized => _isInitialized;

  LoginController() {
    // A verificação é chamada sempre, mas se comporta de forma diferente
    // dependendo se o app está em modo de DEBUG ou RELEASE.
    checkLoginStatus(); 
  }

  void checkLoginStatus() {
    // A constante kDebugMode é true apenas em builds de depuração.
    // Em produção (release), este bloco 'if' será falso.
    if (kDebugMode) {
      // MODO DE DESENVOLVIMENTO (OFFLINE)
      print('LoginController: Rodando em modo DEBUG. Firebase bypassado.');
      _isInitialized = true;
      _isLoggedIn = false; // Começa como deslogado
      notifyListeners();
    } else {
      // MODO DE PRODUÇÃO (ONLINE COM FIREBASE)
      // Esta é a lógica original, que agora só roda em produção.
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        if (user == null) {
          _isLoggedIn = false;
          _user = null;
          print('LoginController: Nenhum usuário logado.');
        } else {
          _isLoggedIn = true;
          _user = user;
          print('LoginController: Usuário ${user.email} está logado.');
        }
        
        if (!_isInitialized) {
          _isInitialized = true;
        }
        notifyListeners();
      });
    }
  }

  // >>> NOVO MÉTODO PARA O MODO DE DESENVOLVIMENTO <<<
  /// Simula um login de desenvolvedor, acionando a mudança de estado.
  void signInAsDeveloper() {
    if (kDebugMode) {
      _isLoggedIn = true;
      _user = null; // Em modo dev, não precisamos de um objeto User.
      print('LoginController: Login de desenvolvedor realizado.');
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    // A lógica de logout também se adapta ao modo do app.
    if (kDebugMode) {
      _isLoggedIn = false;
      _user = null;
      print('LoginController: Logout de desenvolvedor realizado.');
      notifyListeners();
    } else {
      await _authService.signOut();
      // O listener do authStateChanges já vai atualizar o estado.
    }
  }
}