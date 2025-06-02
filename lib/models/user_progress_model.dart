// lib/models/user_progress_model.dart

import 'word_model.dart'; // WordStatus enum'ı için (eğer word_model.dart içindeyse)
// veya import '../utils/enums.dart'; // (eğer enums.dart içindeyse)

class UserProgress {
  final String userId; // Firebase Authentication'dan gelecek kullanıcı kimliği
  int
  currentUnitOrderIndex; // UNIT_ORDER listesindeki mevcut ünite indeksi (0'dan başlar)
  Map<String, WordStatus>
  wordStatuses; // Kelime ID'lerini öğrenme durumlarına eşler

  // İsteğe bağlı: Hızlı erişim için zorlanılan ve bilinmeyen kelime ID'leri listesi.
  // Bunlar wordStatuses'tan da türetilebilir ama kolaylık sağlayabilir.
  List<String> difficultWordsIds;
  List<String> dontKnowWordsIds;

  UserProgress({
    required this.userId,
    this.currentUnitOrderIndex = 0, // Varsayılan olarak ilk ünite (indeks 0)
    Map<String, WordStatus>?
    wordStatuses, // Null olabilir, constructor'da ele alınacak
    List<String>? difficultWordsIds,
    List<String>? dontKnowWordsIds,
  }) : this.wordStatuses =
           wordStatuses ?? {}, // Eğer null gelirse boş bir Map ata
       this.difficultWordsIds =
           difficultWordsIds ?? [], // Null ise boş liste ata
       this.dontKnowWordsIds = dontKnowWordsIds ?? []; // Null ise boş liste ata

  // Firestore'dan veri okurken bu factory constructor kullanılacak
  factory UserProgress.fromFirestore(
    Map<String, dynamic> data,
    String documentId,
  ) {
    // wordStatuses'ı Firestore'dan okurken String'den WordStatus enum'ına çevirme
    Map<String, WordStatus> statuses = {};
    if (data['wordStatuses'] != null) {
      (data['wordStatuses'] as Map<String, dynamic>).forEach((key, value) {
        // value (String) -> WordStatus (enum) dönüşümü
        // Örnek: "WordStatus.known" string'ini WordStatus.known enum değerine çevirir
        statuses[key] = WordStatus.values.firstWhere(
          (e) => e.toString() == value,
          orElse: () => WordStatus.unknown, // Eşleşme bulunamazsa varsayılan
        );
      });
    }

    return UserProgress(
      userId:
          documentId, // Firestore doküman ID'sini userId olarak kullanıyoruz
      currentUnitOrderIndex: data['currentUnitOrderIndex'] ?? 0,
      wordStatuses: statuses,
      difficultWordsIds: List<String>.from(data['difficultWordsIds'] ?? []),
      dontKnowWordsIds: List<String>.from(data['dontKnowWordsIds'] ?? []),
    );
  }

  // Firestore'a veri yazarken bu metot kullanılacak
  Map<String, dynamic> toFirestore() {
    // wordStatuses'ı Firestore'a yazarken WordStatus enum'ından String'e çevirme
    Map<String, String> statusesForFirestore = {};
    this.wordStatuses.forEach((key, value) {
      statusesForFirestore[key] =
          value.toString(); // WordStatus.known -> "WordStatus.known"
    });

    return {
      'currentUnitOrderIndex': currentUnitOrderIndex,
      'wordStatuses': statusesForFirestore,
      'difficultWordsIds': difficultWordsIds,
      'dontKnowWordsIds': dontKnowWordsIds,
    };
  }
}
