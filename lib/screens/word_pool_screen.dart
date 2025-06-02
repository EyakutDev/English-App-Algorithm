// lib/screens/word_pool_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:algorithm_101/providers/firebase_providers.dart';
import 'package:algorithm_101/models/word_model.dart';
import 'package:algorithm_101/models/user_progress_model.dart';
//import 'package:firebase_auth/firebase_auth.dart'; // User ID için

class WordPoolScreen extends ConsumerWidget {
  const WordPoolScreen({super.key});

  Future<void> _markAsKnown(
    BuildContext context,
    WidgetRef ref,
    String wordId,
  ) async {
    final String? userId =
        ref.read(authStateChangesProvider).asData?.value?.uid;
    // En güncel UserProgress'i al
    final UserProgress? currentUserProgress =
        ref.read(userProgressProvider).asData?.value;

    if (userId == null || currentUserProgress == null) {
      print(
        "Kelime durumu güncellenemedi: Kullanıcı veya ilerleme verisi bulunamadı.",
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("İşlem başarısız: Kullanıcı verisi bulunamadı."),
        ),
      );
      return;
    }

    UserProgress updatedProgress = UserProgress(
      userId: userId,
      currentUnitOrderIndex: currentUserProgress.currentUnitOrderIndex,
      wordStatuses: Map.from(currentUserProgress.wordStatuses),
      difficultWordsIds: List.from(currentUserProgress.difficultWordsIds),
      dontKnowWordsIds: List.from(currentUserProgress.dontKnowWordsIds),
    );

    updatedProgress.wordStatuses[wordId] = WordStatus.known;
    updatedProgress.dontKnowWordsIds.remove(wordId);
    updatedProgress.difficultWordsIds.remove(
      wordId,
    ); // Eğer zor listesindeyse de çıkar

    await ref
        .read(firebaseServiceProvider)
        .updateUserProgress(userId, updatedProgress);

    ref.invalidate(wordPoolWordsProvider);
    ref.invalidate(userProgressProvider); // Genel ilerlemeyi de etkileyebilir.

    print(
      "$wordId ID'li kelime 'known' olarak işaretlendi ve depodan çıkarıldı.",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordPoolAsync = ref.watch(wordPoolWordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Depom (Bilmediklerim)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(wordPoolWordsProvider),
            tooltip: "Yenile",
          ),
        ],
      ),
      body: wordPoolAsync.when(
        data: (words) {
          if (words.isEmpty) {
            return const Center(
              /* ... Depo boş mesajı ... */
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Kelime deponuz şu anda boş. "Bilmiyorum" olarak işaretlediğiniz kelimeler burada görünecektir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return Card(
                /* ... Kelime kartı ve butonlar (önceki mesajdaki gibi) ... */
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  title: Text(
                    word.englishWord,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    word.turkishMeaning,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green[700],
                    ),
                    tooltip: "Öğrendim / Depodan Çıkar",
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (ctx) => AlertDialog(
                              title: const Text("Emin misin?"),
                              content: Text(
                                "'${word.englishWord}' kelimesini öğrendin mi?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text("İptal"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    _markAsKnown(
                                      context,
                                      ref,
                                      word.id,
                                    ); // context'i de gönder
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "'${word.englishWord}' depodan çıkarıldı.",
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text("Evet, Öğrendim"),
                                ),
                              ],
                            ),
                      );
                    },
                  ),
                  onTap: () {
                    /* ... Detay gösterme dialogu (önceki mesajdaki gibi) ... */
                    showDialog(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: Text(
                              word.englishWord,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            content: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Türkçe Anlamı: ${word.turkishMeaning}",
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if (word.example?.en.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      "Örnek (EN): ${word.example!.en}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  if (word.example?.tr.isNotEmpty ?? false) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      "Örnek (TR): ${word.example!.tr}",
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                child: const Text('Kapat'),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Hata: $error')),
      ),
    );
  }
}
