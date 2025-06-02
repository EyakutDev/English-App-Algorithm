// lib/models/word_model.dart

class ExampleSentence {
  final String en;
  final String tr;

  ExampleSentence({required this.en, required this.tr});

  factory ExampleSentence.fromMap(Map<String, dynamic> map) {
    return ExampleSentence(en: map['en'] ?? '', tr: map['tr'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'en': en, 'tr': tr};
  }
}

class Word {
  final String id; // Firestore doküman ID'si
  final String englishWord;
  final String turkishMeaning;
  final int
  classLevel; // Sizin "classLevel" alanınız, bizim için ana ünite/seviye
  final String?
  unitName; // Sizin "unit" alanınız (örn: "Words"), opsiyonel olabilir
  final ExampleSentence? example;
  final String? imageUrl;
  final String? audioUrl;

  Word({
    required this.id,
    required this.englishWord,
    required this.turkishMeaning,
    required this.classLevel,
    this.unitName,
    this.example,
    this.imageUrl,
    this.audioUrl,
  });

  factory Word.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Word(
      id: documentId,
      englishWord:
          data['english'] ??
          data['englishWord'] ??
          '', // İki isimlendirmeyi de kontrol edelim
      turkishMeaning:
          data['turkish'] ??
          data['turkishMeaning'] ??
          '', // İki isimlendirmeyi de kontrol edelim
      classLevel: data['classLevel'] ?? 0,
      unitName: data['unit'] as String?, // Sizin "unit" alanınız (örn: "Words")
      example:
          data['example'] != null
              ? ExampleSentence.fromMap(data['example'] as Map<String, dynamic>)
              : null,
      imageUrl: data['imageUrl'] as String?,
      audioUrl: data['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'english': englishWord, // Veri setinizdeki isimlendirmeye uygun
      'turkish': turkishMeaning, // Veri setinizdeki isimlendirmeye uygun
      'classLevel': classLevel,
      if (unitName != null) 'unit': unitName,
      if (example != null) 'example': example!.toMap(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
    };
  }
}

// Kullanıcının kelimeyle ilişkisini belirtmek için enum (daha önce tanımlamıştık)
enum WordStatus { unknown, known, difficult, master }
