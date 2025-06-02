// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Kullanıcı bilgilerini almak için (opsiyonel)
import 'package:firebase_auth/firebase_auth.dart'; // Kullanıcı bilgilerini almak için (opsiyonel)
import 'package:algorithm_101/providers/firebase_providers.dart'; // authStateChangesProvider için (opsiyonel)
import 'package:algorithm_101/screens/unit_selection_screen.dart';
import 'package:algorithm_101/screens/word_pool_screen.dart'; // Birazdan oluşturacağız

class HomeScreen extends ConsumerWidget {
  // Riverpod kullanıyorsak ConsumerWidget
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Opsiyonel: Giriş yapmış kullanıcının e-postasını almak için
    final User? currentUser = ref.watch(authStateChangesProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ana Sayfa'),
        actions: [
          // Opsiyonel: Çıkış yapma butonu
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış Yap',
            onPressed: () async {
              await ref.read(authProvider).signOut();
              // main.dart'taki authStateChangesProvider değişikliği algılayıp
              // AuthScreen'e yönlendirecektir.
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Opsiyonel: Hoşgeldin mesajı
            if (currentUser?.email != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Text(
                  'Hoş geldin, ${currentUser!.email}!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColorDark,
                  ),
                ),
              ),

            // Üniteler Butonu
            ElevatedButton.icon(
              icon: const Icon(Icons.list_alt_rounded, size: 28),
              label: const Text('ÜNİTELER', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UnitSelectionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 25), // Butonlar arasında boşluk
            // Kelime Deposu Butonu
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined, size: 28),
              label: const Text(
                'KELİME DEPOSU',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, // Farklı bir renk
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 5,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WordPoolScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
