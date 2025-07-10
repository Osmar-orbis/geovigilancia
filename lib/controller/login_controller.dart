// lib/controller/login_controller.dart (VERSÃO CORRIGIDA PARA RODAR SEM FIREBASE)

import 'package:flutter/foundation.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // Comentado temporariamente
import 'package:geovigilancia/services/auth_service.dart';

// Classe vazia para substituir a do Firebase e evitar erros
class User {}

class LoginController with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoggedIn = false;
  User? _user;
  bool _isInitialized = false;

  bool get isLoggedIn => _isLoggedIn;
  User? get user => _user;
  bool get isInitialized => _isInitialized;

  LoginController() {
    // <<< MUDANÇA 1: CHAMADA REMOVIDA DO CONSTRUTOR >>>
    // checkLoginStatus(); 
    
    // <<< MUDANÇA 2: Definimos um estado inicial falso para rodar sem Firebase >>>
    // Isso garante que o Consumer no main.dart não fique em loop de loading.
    _isInitialized = true;
    _isLoggedIn = false;
    print('LoginController: Rodando em modo OFFLINE. Firebase bypassado.');
  }

  void checkLoginStatus() {
    // <<< MUDANÇA 3: A LÓGICA DO FIREBASE FOI COMENTADA >>>
    /*
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
      
      _isInitialized = true;
      notifyListeners();
    });
    */
  }

  Future<void> signOut() async {
    // A lógica de logout também é comentada, pois não há usuário para deslogar.
    // await _authService.signOut();
  }
}