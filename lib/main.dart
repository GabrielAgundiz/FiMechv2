import 'package:fimech/screens/login.dart';
import 'package:fimech/screens/user/home.dart';
import 'package:fimech/services/reminder_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fimech/router.dart';


// Función principal que se ejecuta cuando se inicia la aplicación
Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final reminderService = ReminderService();
      await reminderService.init();
      await reminderService.scheduleReminders(user.uid);
    }
  } catch (_) {
    // Notification scheduling is non-critical; continue to launch the app.
  }
  runApp(MyApp());
}

// Clase que extiende StatelessWidget y representa la aplicación completa
class MyApp extends StatelessWidget {
  // Método build que devuelve el árbol de widgets que representa la aplicación
  @override
  Widget build(BuildContext context) => MaterialApp(
        // Oculta la etiqueta de depuración en la esquina superior derecha
        debugShowCheckedModeBanner: false,
        // Establece el título de la aplicación
        title: 'FiMech',
        // Establece el tema de la aplicación
        theme: ThemeData(
          // Establece el color principal de la aplicación
          primarySwatch: Colors.green,
          // Establece el color de fondo de la pantalla de la aplicación
          scaffoldBackgroundColor: Colors.white,
          // Establece la densidad visual de la aplicación
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        // Registrar observer para navegación
        navigatorObservers: [routeObserver],
        // Establece la página de inicio de sesión como la pantalla de inicio de la aplicación
        home: AuthenticationWrapper(),
      );
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      return HomePage();
    } else {
      return LoginPage();
    }
  }
}
