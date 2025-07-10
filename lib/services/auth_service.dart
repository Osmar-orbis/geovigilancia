// lib/services/auth_service.dart (VERSÃO FINAL COM IMPORT CORRETO)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // <<< CORREÇÃO APLICADA AQUI
import 'package:geovigilancia/services/licensing_service.dart';

class AuthService {
  final LicensingService _licensingService = LicensingService();

  FirebaseAuth get _firebaseAuth {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase não inicializado. Não é possível usar a autenticação.');
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get _firestore {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase não inicializado. Não é possível usar o Firestore.');
    }
    return FirebaseFirestore.instance;
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    
    if (credential.user != null) {
      await _criarLicencaTrialParaNovoUsuario(credential.user!);
    }
    
    return credential;
  }
  
  Future<void> _criarLicencaTrialParaNovoUsuario(User user) async {
    final clienteRef = _firestore.collection('clientes').doc(user.uid); 
    final docSnapshot = await clienteRef.get();
    if (docSnapshot.exists) {
      print("Documento de cliente já existe para o usuário ${user.uid}. Pulando criação do trial.");
      return;
    }

    final dataFimTrial = DateTime.now().add(const Duration(days: 7));

    await clienteRef.set({
      'nomeCliente': user.displayName ?? user.email,
      'usuariosPermitidos': [user.email],
      'planoId': 'basico',
      'statusAssinatura': 'trial',
      'trial': {
        'ativo': true,
        'dataInicio': Timestamp.now(),
        'dataFim': Timestamp.fromDate(dataFimTrial),
      }
    });

    print("Licença trial criada com sucesso para o usuário ${user.email}");
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  User? get currentUser {
    // Adiciona uma verificação segura aqui também
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser;
      }
    } catch (e) {
      // Ignora o erro se o Firebase não estiver inicializado
    }
    return null;
  }
}