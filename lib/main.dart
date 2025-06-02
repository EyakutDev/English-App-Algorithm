// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:algorithm_101/firebase_options.dart';
import 'package:algorithm_101/providers/firebase_providers.dart';
import 'package:algorithm_101/screens/AuthScreen.dart';
import 'package:algorithm_101/screens/home_screen.dart'; // HomeScreen'i import et
// LearningScreen importu burada kalabilir, çünkü UnitSelectionScreen'den hala çağrılıyor.
//import 'package:algorithm_101/screens/learning_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);

    return MaterialApp(
      title: 'İngilizce Kelime Uygulaması algorithm_101',
      theme: ThemeData(
        primarySwatch: Colors.blue, // Ana renk
        // Material 3 temasını etkinleştirmek ve daha modern bir görünüm için:
        // useMaterial3: true,
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),

        // Buton stillerini merkezi olarak tanımlayabilirsiniz (opsiyonel)
        // elevatedButtonTheme: ElevatedButtonThemeData(
        //   style: ElevatedButton.styleFrom(
        //     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        //     textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        //   ),
        // ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: authState.when(
        data: (user) {
          if (user != null) {
            // Kullanıcı giriş yapmışsa HomeScreen'e yönlendir
            print(
              "Kullanıcı giriş yapmış: ${user.uid}. HomeScreen'e yönlendiriliyor.",
            );
            return const HomeScreen(); // <<< DEĞİŞİKLİK BURADA
          }
          // Kullanıcı giriş yapmamışsa AuthScreen'e yönlendir
          print("Kullanıcı giriş yapmamış. AuthScreen'e yönlendiriliyor.");
          return const AuthScreen();
        },
        loading: () {
          print("Auth durumu yükleniyor...");
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
        error: (error, stackTrace) {
          print("Auth durumu hatası: $error");
          return Scaffold(
            body: Center(child: Text('Kimlik doğrulama hatası: $error')),
          );
        },
      ),
      // Rotalar (isteğe bağlı, direkt MaterialPageRoute da kullanabilirsiniz)
      // routes: {
      //   '/home': (context) => const HomeScreen(),
      //   '/auth': (context) => const AuthScreen(),
      //   '/learning': (context) => const LearningScreen(),
      //   '/unitSelection': (context) => const UnitSelectionScreen(),
      //   '/wordPool': (context) => const WordPoolScreen(),
      // },
    );
  }
}
