// lib/providers/firebase_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Gerçek Auth için
import '../services/firebase_service.dart';
import '../models/word_model.dart';
import '../models/user_progress_model.dart';
import '../utils/curriculum.dart'; // UNIT_ORDER listeniz için

// 1. FirebaseService Provider'ı
// FirebaseService sınıfının tek bir örneğini (singleton) sağlar.
// Diğer provider'lar veya widget'lar bu servis üzerinden Firestore işlemlerini yapar.
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// 2. FirebaseAuth Instance Provider'ı
// Firebase Authentication işlemlerini yapmak için FirebaseAuth'ın bir örneğini sağlar.
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

// 3. Auth State Changes Provider'ı
// Kullanıcının giriş/çıkış yapma durumunu canlı olarak (stream) dinler.
// User? döndürür: Giriş yapılmışsa User objesi, yapılmamışsa null.
final authStateChangesProvider = StreamProvider<User?>((ref) {
  // authProvider'ı izleyerek FirebaseAuth instance'ını alır.
  return ref.watch(authProvider).authStateChanges();
});

// 4. Ünite Kelimeleri Provider'ı (Family)
// Dışarıdan bir 'unitName' (String) parametresi alarak, o üniteye ait
// kelimelerin listesini (List<Word>) asenkron (Future) olarak getirir.
final unitWordsProvider = FutureProvider.family<List<Word>, String>((
  ref,
  unitName,
) async {
  if (unitName.isEmpty) {
    print("[Provider] unitWordsProvider: unitName boş, boş liste dönülüyor.");
    return [];
  }
  // firebaseServiceProvider'ı izleyerek FirebaseService örneğini alır.
  final firebaseService = ref.watch(firebaseServiceProvider);
  print(
    "[Provider] unitWordsProvider: '$unitName' için kelimeler çekiliyor...",
  );
  final words = await firebaseService.getWordsForUnitName(unitName);
  print(
    "[Provider] unitWordsProvider: '$unitName' için ${words.length} kelime çekildi.",
  );
  return words;
});

// 5. Kullanıcı İlerleme Provider'ı
// O an giriş yapmış olan kullanıcının UserProgress verisini Firestore'dan
// canlı olarak (stream) dinler.
final userProgressProvider = StreamProvider<UserProgress?>((ref) {
  // authStateChangesProvider'ı izleyerek mevcut oturum durumunu alır.
  final authState = ref.watch(authStateChangesProvider);
  final firebaseService = ref.watch(firebaseServiceProvider);

  // Oturum durumundan User objesini alır.
  final firebaseUser = authState.asData?.value;

  // Eğer bir kullanıcı giriş yapmışsa:
  if (firebaseUser != null) {
    final userId = firebaseUser.uid;
    print(
      "[Provider] userProgressProvider: Giriş yapan kullanıcı '$userId' için ilerleme stream'i başlatılıyor...",
    );
    // FirebaseService üzerinden o kullanıcıya ait ilerleme verisini dinle.
    return firebaseService
        .getUserProgress(userId)
        .map((progress) {
          if (progress == null) {
            print(
              "[Provider] userProgressProvider: '$userId' için ilerleme verisi (henüz) bulunamadı. Kayıt sırasında AuthScreen'de oluşturulması bekleniyor.",
            );
          } else {
            print(
              "[Provider] userProgressProvider: '$userId' için ilerleme verisi güncellendi. Mevcut ünite indeksi: ${progress.currentUnitOrderIndex}",
            );
          }
          return progress;
        })
        .handleError((error, stackTrace) {
          print(
            "[Provider] userProgressProvider STREAM HATASI, userId: '$userId' - Hata: $error",
          );
          print("StackTrace: $stackTrace");
          throw error;
        });
  } else {
    // Hiçbir kullanıcı giriş yapmamışsa, null içeren bir stream döndür.
    print(
      "[Provider] userProgressProvider: Kullanıcı giriş yapmamış, null stream dönülüyor.",
    );
    return Stream.value(null);
  }
});

// 6. Aktif Ünite Adı Provider'ı
// userProgressProvider'dan gelen kullanıcının mevcut ünite indeksini ve
// curriculum.dart'taki UNIT_ORDER listesini kullanarak o an çalışılması gereken
// ünitenin adını (String) belirler.
final activeUnitNameProvider = Provider<String?>((ref) {
  final userProgressSnapshot = ref.watch(userProgressProvider);

  if (userProgressSnapshot.hasValue && userProgressSnapshot.value != null) {
    final userProgress = userProgressSnapshot.value!;
    final currentIndex = userProgress.currentUnitOrderIndex;

    if (currentIndex >= 0 && currentIndex < UNIT_ORDER.length) {
      final unitName = UNIT_ORDER[currentIndex];
      // print("[Provider] activeUnitNameProvider: Aktif ünite adı '$unitName' (indeks: $currentIndex).");
      return unitName;
    } else {
      // print("[Provider] activeUnitNameProvider: Geçersiz indeks ($currentIndex) veya tüm üniteler tamamlanmış.");
      return null;
    }
  }
  // print("[Provider] activeUnitNameProvider: UserProgress yükleniyor, hata var veya değeri null.");
  return null;
});

// 7. Kelime Deposu Kelimeleri Provider'ı
// Kullanıcının UserProgress'indeki 'dontKnowWordsIds' (ve/veya 'difficultWordsIds')
// listesini kullanarak depodaki kelimeleri (List<Word>) asenkron olarak getirir.
final wordPoolWordsProvider = FutureProvider<List<Word>>((ref) async {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final userProgressSnapshot = ref.watch(userProgressProvider);

  if (!userProgressSnapshot.hasValue || userProgressSnapshot.value == null) {
    print(
      "[Provider] wordPoolWordsProvider: UserProgress yükleniyor veya null, boş liste dönülüyor.",
    );
    return [];
  }
  final userProgress = userProgressSnapshot.value!;

  // "Bilmiyorum" ve "Zorlanıyorum" listelerini birleştirerek çekilecek ID'leri oluştur.
  // Tekrarları önlemek için Set kullanabiliriz.
  Set<String> idsToFetchSet = {};
  idsToFetchSet.addAll(userProgress.dontKnowWordsIds);
  idsToFetchSet.addAll(
    userProgress.difficultWordsIds,
  ); // Zorlanılanları da ekle

  List<String> idsToFetchList = idsToFetchSet.toList();

  if (idsToFetchList.isEmpty) {
    print(
      "[Provider] wordPoolWordsProvider: Kelime deposu için çekilecek ID listesi boş.",
    );
    return [];
  }

  print(
    "[Provider] wordPoolWordsProvider: ${idsToFetchList.length} ID için kelimeler çekiliyor: $idsToFetchList",
  );
  return firebaseService.getWordsByIds(idsToFetchList);
});
