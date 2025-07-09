// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// Imports dos seus providers e controllers
import 'package:geovigilancia/controller/login_controller.dart';
import 'package:geovigilancia/providers/map_provider.dart';
import 'package:geovigilancia/providers/team_provider.dart';
import 'package:geovigilancia/providers/license_provider.dart';

// Import da página que você quer testar
import 'package:geovigilancia/pages/menu/login_page.dart';

// Um Mock do LoginController para evitar dependências de Firebase nos testes de widget.
class MockLoginController extends LoginController {
  bool _isLoggedIn = false;
  bool _isInitialized = true;

  @override
  bool get isLoggedIn => _isLoggedIn;

  @override
  bool get isInitialized => _isInitialized;
  
  void setLoginStatus(bool loggedIn) {
    _isLoggedIn = loggedIn;
    notifyListeners();
  }
}

void main() {
  // Teste de widget para a tela de Login
  testWidgets('LoginPage renders correctly', (WidgetTester tester) async {
    // Envolve o LoginPage com os providers necessários para o teste.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          // Use o MockController para testes
          ChangeNotifierProvider<LoginController>(create: (_) => MockLoginController()),
          ChangeNotifierProvider(create: (_) => MapProvider()),
          ChangeNotifierProvider(create: (_) => TeamProvider()),
          ChangeNotifierProvider(create: (_) => LicenseProvider()),
        ],
        child: const MaterialApp(
          home: LoginPage(),
        ),
      ),
    );

    // Verifica se os campos de texto para email e senha estão presentes.
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);

    // Verifica se o botão "Entrar" está presente.
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);

    // Verifica se o botão "Criar nova conta" está presente.
    expect(find.widgetWithText(OutlinedButton, 'Criar nova conta'), findsOneWidget);
    
    // Verifica se o texto de boas-vindas é exibido.
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
  });
}