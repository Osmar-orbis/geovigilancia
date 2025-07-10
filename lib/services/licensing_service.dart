// lib/services/licensing_service.dart (VERSÃO FINAL CORRIGIDA COM IMPORT)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart'; // <<< IMPORT ADICIONADO AQUI

class LicenseException implements Exception {
  final String message;
  LicenseException(this.message);
  @override
  String toString() => message;
}

class LicensingService {
  final FirebaseFirestore? _firestore;

  LicensingService() : _firestore = _getFirestoreInstance();

  static FirebaseFirestore? _getFirestoreInstance() {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseFirestore.instance;
      }
    } catch (e) {
      print("LicensingService: Firebase não inicializado, rodando em modo offline. Erro: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>> getLicenseDetailsForUser(User user) async {
    if (_firestore == null) {
      throw LicenseException('Modo offline: Verificação de licença desabilitada.');
    }
    
    final clienteDocRef = _firestore!.collection('clientes').doc(user.uid);
    final clienteSnapshot = await clienteDocRef.get();

    if (!clienteSnapshot.exists) {
      throw LicenseException('Não foi encontrada uma licença para sua conta. Tente criar a conta novamente ou contate o suporte.');
    }

    final clienteData = clienteSnapshot.data()!;
    final planoId = clienteData['planoId'] as String?;

    if (planoId == null || planoId.isEmpty) {
      throw LicenseException('Sua conta não está associada a um plano de licença. Contate o suporte.');
    }

    final planoDoc = await _firestore!.collection('planosDeLicenca').doc(planoId).get();

    if (!planoDoc.exists) {
      throw LicenseException('O plano de licença ($planoId) configurado para sua empresa não foi encontrado.');
    }
    
    return {
      'clienteRef': clienteSnapshot.reference,
      'planoData': planoDoc.data(),
      'clienteData': clienteData,
    };
  }

  Future<void> checkAndRegisterDevice(User user) async {
    if (_firestore == null) {
      print("LicensingService: Bypass de checkAndRegisterDevice em modo offline.");
      return; 
    }
    
    final licenseDetails = await getLicenseDetailsForUser(user);
    final DocumentReference clienteRef = licenseDetails['clienteRef'];
    final Map<String, dynamic> planoData = licenseDetails['planoData'] as Map<String, dynamic>;
    final Map<String, dynamic> clienteData = licenseDetails['clienteData'] as Map<String, dynamic>;

    final statusAssinatura = clienteData['statusAssinatura'];
    bool acessoPermitido = false;

    if (statusAssinatura == 'ativa') {
      acessoPermitido = true;
    } else if (statusAssinatura == 'trial') {
      final trialData = clienteData['trial'] as Map<String, dynamic>?;
      if (trialData != null && trialData['ativo'] == true) {
        final dataFimTimestamp = trialData['dataFim'] as Timestamp?;
        if (dataFimTimestamp != null) {
          if (DateTime.now().isBefore(dataFimTimestamp.toDate())) {
            acessoPermitido = true;
          } else {
            throw LicenseException('Seu período de teste expirou. Contate o suporte para contratar um plano.');
          }
        }
      }
    }

    if (!acessoPermitido) {
      throw LicenseException('A assinatura da sua empresa está inativa ou expirou.');
    }

    final limites = planoData['limites'] as Map<String, dynamic>?;
    if (limites == null) {
        throw LicenseException('Os limites do seu plano não estão configurados corretamente.');
    }

    final tipoDispositivo = kIsWeb ? 'desktop' : 'smartphone';
    final deviceId = await _getDeviceId();

    if (deviceId == null) {
      throw LicenseException('Não foi possível identificar seu dispositivo.');
    }
    
    final dispositivosAtivosRef = clienteRef.collection('dispositivosAtivos');
    final dispositivoExistente = await dispositivosAtivosRef.doc(deviceId).get();

    if (dispositivoExistente.exists) {
      return;
    }
    
    final contagemAtual = (await dispositivosAtivosRef.where('tipo', isEqualTo: tipoDispositivo).count().get()).count ?? 0;
    final limiteAtual = limites[tipoDispositivo] as int? ?? 0;

    if (limiteAtual >= 0 && contagemAtual >= limiteAtual) {
      throw LicenseException('O limite de dispositivos do tipo "$tipoDispositivo" foi atingido para sua empresa.');
    }
    
    await dispositivosAtivosRef.doc(deviceId).set({
      'uidUsuario': user.uid,
      'emailUsuario': user.email,
      'tipo': tipoDispositivo,
      'registradoEm': FieldValue.serverTimestamp(),
      'nomeDispositivo': await _getDeviceName(),
    });
  }
  
  Future<Map<String, int>> getDeviceUsage(String userEmail) async {
     if (_firestore == null) {
      print("LicensingService: Bypass de getDeviceUsage em modo offline.");
      return {'smartphone': 0, 'desktop': 0};
    }

    final clienteSnapshot = await _firestore!
        .collection('clientes')
        .where('usuariosPermitidos', arrayContains: userEmail)
        .limit(1)
        .get();

    if (clienteSnapshot.docs.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final clienteDoc = await _firestore!.collection('clientes').doc(user.uid).get();
        if (clienteDoc.exists) {
           return _getDeviceCountFromDoc(clienteDoc.reference);
        }
      }
      return {'smartphone': 0, 'desktop': 0};
    }

    final clienteDoc = clienteSnapshot.docs.first;
    return await _getDeviceCountFromDoc(clienteDoc.reference);
  }

  Future<Map<String, int>> _getDeviceCountFromDoc(DocumentReference docRef) async {
      final dispositivosAtivosRef = docRef.collection('dispositivosAtivos');

      final smartphoneCountSnapshot = await dispositivosAtivosRef
          .where('tipo', isEqualTo: 'smartphone')
          .count()
          .get();
      final smartphoneCount = smartphoneCountSnapshot.count ?? 0;

      final desktopCountSnapshot = await dispositivosAtivosRef
          .where('tipo', isEqualTo: 'desktop')
          .count()
          .get();
      final desktopCount = desktopCountSnapshot.count ?? 0;

      return {
        'smartphone': smartphoneCount,
        'desktop': desktopCount,
      };
  }

  Future<String?> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final webInfo = await deviceInfo.webBrowserInfo;
      return 'web_${webInfo.vendor}_${webInfo.userAgent}';
    }
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    }
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    }
    if (Platform.isWindows) {
      final windowsInfo = await deviceInfo.windowsInfo;
      return windowsInfo.deviceId;
    }
    return null;
  }

  Future<String> _getDeviceName() async {
     final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) return 'Navegador Web';
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.name;
      }
      if (Platform.isWindows) {
        final info = await deviceInfo.windowsInfo;
        return info.computerName;
      }
    return 'Dispositivo Desconhecido';
  }
}