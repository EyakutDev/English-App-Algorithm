// lib/services/firebase_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_model.dart'; // Word ve WordStatus enum'ı için
import '../models/user_progress_model.dart'; // UserProgress modeli için

// Firebase ile etkileşimleri yönetecek servis sınıfı
class FirebaseService {
  // Firebase Firestore'un ana örneğini alıyoruz (_db private demektir)
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 'words' koleksiyonuna erişim ve otomatik tip dönüşümü için referans.
  // .withConverter sayesinde Firestore'dan gelen Map'ler Word objesine,
  // Word objeleri de Firestore'a yazılırken Map'e dönüşür.
  CollectionReference<Word> get wordsCollection => _db
      .collection('words')
      .withConverter<Word>(
        // Firestore'dan veri okurken çalışacak fonksiyon
        fromFirestore:
            (snapshot, _) => Word.fromFirestore(snapshot.data()!, snapshot.id),
        // Firestore'a veri yazarken çalışacak fonksiyon
        toFirestore: (word, _) => word.toFirestore(),
      );

  // 'users' koleksiyonuna erişim ve UserProgress objelerine dönüşüm için referans.
  CollectionReference<UserProgress> get usersCollection => _db
      .collection('users')
      .withConverter<UserProgress>(
        fromFirestore:
            (snapshot, _) =>
                UserProgress.fromFirestore(snapshot.data()!, snapshot.id),
        toFirestore: (userProgress, _) => userProgress.toFirestore(),
      );

  /// Belirli bir ünite adına (`unitName`) ait tüm kelimeleri Firestore'dan getirir.
  Future<List<Word>> getWordsForUnitName(String unitName) async {
    try {
      print(
        "[FirebaseService] getWordsForUnitName çağrıldı - Ünite Adı: '$unitName'",
      );
      // 'words' koleksiyonunda, 'unit' alanı (Word modelindeki unitName'e karşılık gelir)
      // verilen unitName'e eşit olan dokümanları sorgula.
      final querySnapshot =
          await wordsCollection.where('unit', isEqualTo: unitName).get();
      // Sorgu sonucundaki dokümanları Word nesnelerine çevir ve liste olarak döndür.
      final words = querySnapshot.docs.map((doc) => doc.data()).toList();
      print(
        "[FirebaseService] '$unitName' için sorgu sonucu ${words.length} kelime bulundu.",
      );
      return words;
    } catch (e) {
      print("[FirebaseService] HATA - getWordsForUnitName ('$unitName'): $e");
      return []; // Hata durumunda boş bir liste döndür.
    }
  }

  /// Belirli bir `userId` için kullanıcının ilerleme verisini (`UserProgress`)
  /// Firestore'dan canlı olarak (stream) dinler. Verideki değişiklikler anında yansır.
  Stream<UserProgress?> getUserProgress(String userId) {
    print(
      "[FirebaseService] getUserProgress çağrıldı - Kullanıcı ID: '$userId'",
    );
    try {
      // Belirtilen userId'ye sahip dokümanı dinle.
      return usersCollection
          .doc(userId)
          .snapshots()
          .map((snapshot) {
            print(
              "[FirebaseService] getUserProgress: Snapshot alındı, Doküman Var mı: ${snapshot.exists}, Kullanıcı ID: '$userId'",
            );
            if (snapshot.exists) {
              // Doküman varsa ve veri içeriyorsa, UserProgress nesnesine çevir.
              try {
                final userProgress =
                    snapshot
                        .data(); // Converter sayesinde UserProgress objesi döner.
                print(
                  "[FirebaseService] getUserProgress: UserProgress başarıyla oluşturuldu, Mevcut Ünite İndeksi: ${userProgress?.currentUnitOrderIndex}",
                );
                return userProgress;
              } catch (e, s) {
                // UserProgress.fromFirestore içinde bir hata olursa (veri yapısı uyumsuzsa vb.)
                print(
                  "[FirebaseService] HATA UserProgress.fromFirestore içinde, Kullanıcı ID: '$userId' - Hata: $e",
                );
                print("[FirebaseService] StackTrace: $s");
                throw e; // Hatayı StreamProvider'ın yakalaması için tekrar fırlat.
              }
            } else {
              // Kullanıcı için henüz bir ilerleme dokümanı yoksa (yeni kullanıcı olabilir).
              print(
                "[FirebaseService] getUserProgress: '$userId' için doküman bulunamadı, null dönülüyor.",
              );
              return null;
            }
          })
          .handleError((error, stackTrace) {
            // Stream üzerinde oluşabilecek genel hataları yakala.
            print(
              "[FirebaseService] STREAM HATASI getUserProgress içinde, Kullanıcı ID: '$userId' - Hata: $error",
            );
            print("[FirebaseService] StackTrace: $stackTrace");
            throw error; // Hatayı StreamProvider'a ilet.
          });
    } catch (e) {
      // Stream başlatılırken bir hata oluşursa (çok nadir).
      print(
        "[FirebaseService] HATA getUserProgress başlatılırken, Kullanıcı ID: '$userId': $e",
      );
      return Stream.error(e);
    }
  }

  /// Kullanıcının ilerleme verisinin tamamını (`UserProgress` nesnesini)
  /// Firestore'a kaydeder veya günceller.
  /// `SetOptions(merge: true)` sayesinde, eğer doküman varsa sadece değişen alanlar güncellenir
  /// veya olmayan alanlar eklenir, diğerleri silinmez. Eğer merge:false (veya belirtilmezse)
  /// ve doküman varsa, tüm dokümanın üzerine yazar.
  Future<void> updateUserProgress(String userId, UserProgress progress) async {
    try {
      print(
        "[FirebaseService] updateUserProgress çağrıldı - Kullanıcı ID: '$userId', Yeni Ünite İndeksi: ${progress.currentUnitOrderIndex}, Bilinmeyen Kelime Sayısı: ${progress.dontKnowWordsIds.length}",
      );
      // usersCollection (withConverter ile tanımlı) doğrudan UserProgress nesnesini alıp Firestore'a yazar.
      await usersCollection.doc(userId).set(progress, SetOptions(merge: true));
      print(
        "[FirebaseService] updateUserProgress başarıyla tamamlandı - Kullanıcı ID: '$userId'",
      );
    } catch (e) {
      print("[FirebaseService] HATA - updateUserProgress ($userId): $e");
      throw e; // Hatayı çağıran yere bildir
    }
  }

  /// Bir kelimenin, belirli bir kullanıcının `wordStatuses` map'indeki öğrenilme durumunu günceller.
  /// Bu, tüm UserProgress nesnesini göndermek yerine sadece bir map alanını güncellemek için daha verimli olabilir.
  Future<void> updateWordStatusForUser(
    String userId,
    String wordId,
    WordStatus status,
  ) async {
    try {
      print(
        "[FirebaseService] updateWordStatusForUser çağrıldı - Kullanıcı ID: '$userId', Kelime ID: '$wordId', Durum: $status",
      );
      // `users` koleksiyonundaki `userId`'li dokümanın `wordStatuses` map'indeki
      // `wordId` key'ine sahip alanı yeni `status` ile güncelle.
      await _db.collection('users').doc(userId).update({
        'wordStatuses.$wordId':
            status.toString(), // Enum'ı string'e çevirerek kaydet
      });
      print(
        "[FirebaseService] updateWordStatusForUser başarıyla tamamlandı - Kullanıcı ID: '$userId', Kelime ID: '$wordId'",
      );
    } catch (e) {
      print(
        "[FirebaseService] HATA - updateWordStatusForUser (Kullanıcı: $userId, Kelime: $wordId): $e",
      );
      throw e; // Hatayı çağıran yere bildir
    }
  }

  /// Yeni kaydolan bir kullanıcı için Firestore'da başlangıç `UserProgress` dokümanını oluşturur.
  /// Eğer kullanıcı için zaten bir doküman varsa, tekrar oluşturmaz.
  Future<void> createInitialUserProgress(String userId) async {
    try {
      print(
        "[FirebaseService] createInitialUserProgress çağrıldı - Kullanıcı ID: '$userId'",
      );
      // Kullanıcı dokümanının var olup olmadığını kontrol et.
      final docSnapshot = await usersCollection.doc(userId).get();
      if (!docSnapshot.exists) {
        // Doküman yoksa, varsayılan değerlerle yeni bir UserProgress nesnesi oluştur.
        UserProgress initialProgress = UserProgress(
          userId: userId,
          currentUnitOrderIndex: 0, // İlk üniteden başlar (indeks 0)
          wordStatuses: {},
          dontKnowWordsIds: [],
          difficultWordsIds: [],
        );
        // Oluşturulan bu başlangıç ilerlemesini Firestore'a kaydet.
        await usersCollection.doc(userId).set(initialProgress);
        print(
          "[FirebaseService] İlk UserProgress başarıyla oluşturuldu - Kullanıcı ID: $userId",
        );
      } else {
        print(
          "[FirebaseService] UserProgress zaten mevcut, tekrar oluşturulmadı - Kullanıcı ID: $userId",
        );
      }
    } catch (e) {
      print("[FirebaseService] HATA - createInitialUserProgress ($userId): $e");
      throw e; // Hatayı çağıran yere bildir
    }
  }

  /// Verilen ID listesindeki (`wordIds`) kelimeleri Firestore'dan toplu olarak getirir.
  /// Firestore'un 'in' sorgu limitlerini (genellikle 30 ID) aşmamak için
  /// ID listesini 30'luk parçalara (chunks) böler.
  Future<List<Word>> getWordsByIds(List<String> wordIds) async {
    if (wordIds.isEmpty) {
      print(
        "[FirebaseService] getWordsByIds: ID listesi boş, boş liste dönülüyor.",
      );
      return [];
    }
    print(
      "[FirebaseService] getWordsByIds çağrıldı - Getirilecek ID sayısı: ${wordIds.length}",
    );
    List<Word> words = [];

    // ID listesini 30'luk parçalara böl
    List<List<String>> chunks = [];
    for (var i = 0; i < wordIds.length; i += 30) {
      // Firestore 'in' sorgusu için genellikle 30'luk parçalar kullanılır
      chunks.add(
        wordIds.sublist(i, i + 30 > wordIds.length ? wordIds.length : i + 30),
      );
    }

    // Her bir parça için ayrı sorgu yap
    for (var chunk in chunks) {
      if (chunk.isNotEmpty) {
        // Boş chunk için sorgu yapma
        try {
          print(
            "[FirebaseService] getWordsByIds: Chunk sorgulanıyor - ${chunk.length} ID: $chunk",
          );
          // 'words' koleksiyonunda, doküman ID'si (FieldPath.documentId) chunk listesindeki ID'lerden biri olanları getir.
          final querySnapshot =
              await wordsCollection
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
          // Gelen dokümanları Word nesnelerine çevir ve ana listeye ekle.
          words.addAll(querySnapshot.docs.map((doc) => doc.data()).toList());
        } catch (e) {
          print("[FirebaseService] HATA - getWordsByIds (chunk sorgusu): $e");
          // Bir chunk'ta hata olursa logla ama diğerlerine devam et (opsiyonel, isteğe bağlı olarak burada da throw e yapılabilir).
        }
      }
    }
    print(
      "[FirebaseService] getWordsByIds toplam ${words.length} kelime döndürdü.",
    );
    return words;
  }
}
