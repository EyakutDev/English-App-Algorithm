// lib/screens/unit_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Kullanıcı kontrolü için
import 'package:algorithm_101/providers/firebase_providers.dart'; // Provider'lar için
//import 'package:algorithm_101/models/user_progress_model.dart'; // UserProgress modeli için
import 'package:algorithm_101/utils/curriculum.dart'; // UNIT_ORDER listesi için
import 'package:algorithm_101/screens/learning_screen.dart'; // LearningScreen'e yönlendirme için

class UnitSelectionScreen extends ConsumerWidget {
  const UnitSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // FirebaseService'e doğrudan erişim (updateUserProgress artık burada çağrılmıyor ama kalsın)
    // final firebaseService = ref.read(firebaseServiceProvider);

    // 1. Kullanıcı Oturum Durumunu Al
    final authState = ref.watch(authStateChangesProvider);
    final User? currentUser = authState.asData?.value;

    // Oturum yükleniyorsa bekleme göstergesi
    if (authState.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Üniteler')),
        body: const Center(
          child: CircularProgressIndicator(
            key: ValueKey("auth_loading_unitselection"),
          ),
        ),
      );
    }

    // Kullanıcı giriş yapmamışsa bilgilendirme (Normalde buraya gelinmemeli)
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Üniteler')),
        body: const Center(
          child: Text("Üniteleri görmek için lütfen giriş yapın."),
        ),
      );
    }
    // final String userId = currentUser.uid; // userId'ye burada doğrudan ihtiyacımız kalmadı,
    // çünkü ilerlemeyi LearningScreen yönetecek.

    // 2. Kullanıcı İlerlemesini İzle
    final userProgressAsync = ref.watch(userProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Üniteler')),
      body: userProgressAsync.when(
        data: (userProgressData) {
          // Kullanıcı ilerleme verisi yoksa (yeni kullanıcı ve henüz veri oluşmamışsa)
          if (userProgressData == null) {
            // Bu durum AuthScreen'deki createInitialUserProgress ile ele alınmış olmalı.
            // Buraya düşerse, bir sorun veya gecikme var demektir.
            print(
              "UnitSelectionScreen: UserProgressData null (userId: ${currentUser.uid}). createInitialUserProgress çağrılmış olmalı.",
            );
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Kullanıcı ilerleme verisi yükleniyor/bulunamadı.",
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      // İlerlemeyi manuel başlatma (AuthScreen'dekinin yedeği gibi)
                      await ref
                          .read(firebaseServiceProvider)
                          .createInitialUserProgress(currentUser.uid);
                    },
                    child: const Text("İlerlemeyi Başlat/Yenile"),
                  ),
                ],
              ),
            );
          }

          // Mevcut kullanıcının en son ulaştığı (kilidini açtığı) ünite indeksi
          final int highestUnlockedUnitIndex =
              userProgressData.currentUnitOrderIndex;

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount:
                UNIT_ORDER.length, // curriculum.dart'taki toplam ünite sayısı
            itemBuilder: (context, index) {
              final String unitName =
                  UNIT_ORDER[index]; // Mevcut listedeki ünite adı
              // Bir ünite, kullanıcının en son ulaştığı indekse eşit veya küçükse kilidi açıktır.
              final bool isUnlocked = index <= highestUnlockedUnitIndex;
              // Bir ünite, kullanıcının en son ulaştığı indekse eşitse mevcut aktif ünitedir (öğrenmeye devam edeceği).
              final bool isCurrentlyLearning =
                  index == highestUnlockedUnitIndex;

              // İkon ve renkleri belirleme
              IconData lockIcon = Icons.lock_outline_rounded;
              Color iconColor = Colors.grey.shade400;
              String subtitleText = "Kilitli";
              Color tileBackgroundColor = Colors.grey.shade200;
              Color titleColor = Colors.grey.shade700;
              FontWeight titleFontWeight = FontWeight.normal;

              if (isUnlocked) {
                lockIcon = Icons.lock_open_rounded;
                iconColor = Colors.green.shade600;
                subtitleText =
                    "Tekrar Et veya Çalış"; // Kilidi açık tüm üniteler için
                tileBackgroundColor = Colors.white;
                titleColor = Colors.black87;
              }

              if (isCurrentlyLearning) {
                iconColor = Theme.of(context).primaryColor;
                subtitleText = "Devam Et"; // Öğrenmeye devam edeceği ünite
                tileBackgroundColor = Theme.of(
                  context,
                ).primaryColor.withOpacity(0.1);
                titleColor = Theme.of(context).primaryColor;
                titleFontWeight = FontWeight.bold;
              }

              // Gelecekteki kilitli üniteler için stil (yukarıdaki isUnlocked zaten bunu kapsıyor ama netleştirelim)
              if (index > highestUnlockedUnitIndex) {
                subtitleText = "Kilitli";
                iconColor = Colors.grey.shade400;
                tileBackgroundColor = Colors.grey.shade200;
                titleColor = Colors.grey.shade700;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                elevation: isUnlocked ? 3 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(lockIcon, color: iconColor, size: 30),
                  title: Text(
                    "${index + 1}. $unitName", // Ünite sırası ve adı
                    style: TextStyle(
                      fontWeight: titleFontWeight,
                      color: titleColor,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: Text(
                    subtitleText,
                    style: TextStyle(color: iconColor.withOpacity(0.9)),
                  ),
                  trailing:
                      isUnlocked
                          ? Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                            color: iconColor,
                          )
                          : null,
                  tileColor: tileBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  onTap:
                      isUnlocked
                          ? () {
                            // Kullanıcının UserProgress'indeki currentUnitOrderIndex'i DEĞİŞTİRMİYORUZ.
                            // Sadece LearningScreen'e hangi üniteyi (tekrar/çalışma için)
                            // yüklemesi gerektiğini parametre olarak gönderiyoruz.
                            print(
                              "UnitSelectionScreen: '$unitName' ünitesi seçildi. LearningScreen'e targetUnitName ile yönlendiriliyor.",
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => LearningScreen(
                                      targetUnitName: unitName,
                                    ),
                              ),
                            ).then((_) {
                              // LearningScreen'den geri dönüldüğünde, eğer orada bir ünite tamamlanıp
                              // currentUnitOrderIndex değiştiyse, bu ekranın güncellenmesi için
                              // userProgressProvider'ı yenileyebiliriz.
                              // Bu, ünite kilitlerinin anında güncellenmesini sağlar.
                              print(
                                "UnitSelectionScreen: LearningScreen'den geri dönüldü, userProgressProvider yenileniyor.",
                              );
                              ref.invalidate(userProgressProvider);
                            });
                          }
                          : null, // Kilitli ise tıklanamaz
                ),
              );
            },
          );
        },
        loading:
            () => const Center(
              child: CircularProgressIndicator(
                key: ValueKey("progress_loading_unitselection"),
              ),
            ),
        error: (error, stackTrace) {
          print(
            "UnitSelectionScreen HATA userProgressAsync: $error \n$stackTrace",
          );
          return Center(
            child: Text(
              'Kullanıcı ilerlemesi yüklenirken bir hata oluştu: $error',
            ),
          );
        },
      ),
    );
  }
}
