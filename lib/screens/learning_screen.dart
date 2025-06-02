// lib/screens/learning_screen.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:algorithm_101/providers/firebase_providers.dart';
import 'package:algorithm_101/models/user_progress_model.dart';
import 'package:algorithm_101/models/word_model.dart'; // WordStatus ve Word modeli için
import 'package:algorithm_101/utils/curriculum.dart'; // UNIT_ORDER listeniz için

class LearningScreen extends ConsumerStatefulWidget {
  // UnitSelectionScreen'den belirli bir üniteyi incelemek/tekrar etmek için
  // bir hedef ünite adı alabilir. Eğer null ise, kullanıcının normal ilerlemesindeki
  // mevcut ünite yüklenir.
  final String? targetUnitName;

  const LearningScreen({super.key, this.targetUnitName});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  // --- State Değişkenleri ---
  List<Word> _currentUnitWordsSession =
      []; // Mevcut öğrenme oturumundaki kelimeler (karıştırılmış)
  int _currentWordSessionIndex = 0; // Oturumdaki mevcut kelimenin indeksi
  Word? _activeWordSession; // Oturumdaki o an gösterilen aktif kelime
  bool _showMeaningSession =
      false; // Kelimenin anlamının gösterilip gösterilmediği

  String? _unitNameToLoadOnScreen; // Bu ekranda o an yüklenen ünitenin adı
  bool _isReviewModeSession =
      false; // Eğer targetUnitName ile gelindiyse bu true olur

  @override
  void initState() {
    super.initState();
    // Widget ilk oluşturulduğunda, eğer bir hedef ünite adı varsa onu yükle
    // Yoksa, bu bilgi build metodunda UserProgress'ten alınacak.
    if (widget.targetUnitName != null) {
      _unitNameToLoadOnScreen = widget.targetUnitName;
      // _isReviewModeSession'ı burada set etmek için UserProgress'e de ihtiyacımız var,
      // bu yüzden bu kontrolü build metodunda yapmak daha uygun.
    }
    print("LearningScreen initState: targetUnitName: ${widget.targetUnitName}");
  }

  @override
  void didUpdateWidget(covariant LearningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer widget dışarıdan yeni bir targetUnitName ile güncellenirse
    // (örneğin, UnitSelectionScreen'den farklı bir ünite seçilirse ve aynı LearningScreen instance'ı kullanılıyorsa - nadir bir durum)
    // state'i sıfırlayıp yeni üniteyi yüklemeye hazırlanmalıyız.
    if (widget.targetUnitName != null &&
        widget.targetUnitName != _unitNameToLoadOnScreen) {
      print(
        "LearningScreen didUpdateWidget: targetUnitName değişti. Eski: $_unitNameToLoadOnScreen, Yeni: ${widget.targetUnitName}",
      );
      _resetLocalSessionState(); // Lokal oturum state'ini sıfırla
      _unitNameToLoadOnScreen =
          widget.targetUnitName; // Yüklenecek ünite adını güncelle
    }
  }

  // Lokal oturum değişkenlerini sıfırlayan yardımcı metot
  void _resetLocalSessionState() {
    if (mounted) {
      setState(() {
        _currentUnitWordsSession = [];
        _currentWordSessionIndex = 0;
        _activeWordSession = null;
        _showMeaningSession = false;
        // _unitNameToLoadOnScreen ve _isReviewModeSession build'de tekrar belirlenecek
      });
    }
    print("LearningScreen: Lokal oturum state'i sıfırlandı.");
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = ref.read(firebaseServiceProvider);
    final authState = ref.watch(authStateChangesProvider);
    final User? currentUser = authState.asData?.value;

    // 1. Oturum Kontrolü
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: ValueKey("auth_loading_ls")),
        ),
      );
    }
    if (currentUser == null) {
      // main.dart bu durumu ele alıp AuthScreen'e yönlendirmeli.
      return const Scaffold(
        body: Center(
          child: Text("Oturum bulunamadı. Lütfen tekrar giriş yapın."),
        ),
      );
    }
    final String userId = currentUser.uid;

    // 2. UserProgress Yükleme
    final userProgressAsync = ref.watch(userProgressProvider);

    return userProgressAsync.when(
      data: (userProgressData) {
        // 3. Yeni Kullanıcı mı? (UserProgress henüz oluşmamışsa)
        if (userProgressData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Hoş Geldin!")),
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  await firebaseService.createInitialUserProgress(userId);
                },
                child: const Text("Öğrenmeye Başla!"),
              ),
            ),
          );
        }

        // 4. Hangi Ünitenin Yükleneceğini Belirle
        // Eğer widget.targetUnitName (constructor'dan gelen) varsa, onu kullan (inceleme/tekrar modu).
        // Yoksa, kullanıcının normal ilerlemesindeki üniteyi (activeUnitNameProvider'dan) kullan.
        if (widget.targetUnitName != null) {
          _unitNameToLoadOnScreen = widget.targetUnitName;
          // İnceleme modunda olup olmadığımızı belirle:
          // Eğer hedeflenen ünite, kullanıcının normalde olması gereken üniteden farklıysa, inceleme modudur.
          _isReviewModeSession =
              (userProgressData.currentUnitOrderIndex < UNIT_ORDER.length &&
                  UNIT_ORDER[userProgressData.currentUnitOrderIndex] !=
                      _unitNameToLoadOnScreen);
        } else {
          // Normal ilerleme için activeUnitNameProvider'ı kullan
          final String? defaultActiveUnitName = ref.watch(
            activeUnitNameProvider,
          );
          _unitNameToLoadOnScreen = defaultActiveUnitName;
          _isReviewModeSession = false; // Normal öğrenme modu
        }

        print(
          "[DEBUG] LearningScreen build: Yüklenecek Ünite: $_unitNameToLoadOnScreen, İnceleme Modu: $_isReviewModeSession",
        );

        // Eğer yüklenecek bir ünite adı belirlenemediyse (tüm üniteler bitti vs.)
        if (_unitNameToLoadOnScreen == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Tebrikler!")),
            body: Center(
              /* ... (Tüm üniteler tamamlandı mesajı ve Baştan Başla butonu) ... */
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Tüm öğrenme ünitelerini tamamladınız!"),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      UserProgress freshProgress = UserProgress(userId: userId);
                      firebaseService.updateUserProgress(userId, freshProgress);
                      _resetLocalSessionState(); // Ekranı yenilemek için
                    },
                    child: const Text("Baştan Başla"),
                  ),
                ],
              ),
            ),
          );
        }

        // 5. Belirlenen Ünitenin Kelimelerini Yükleme
        final wordsAsync = ref.watch(
          unitWordsProvider(_unitNameToLoadOnScreen!),
        ); // _unitNameToLoadOnScreen burada null olmamalı.

        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Ünite: $_unitNameToLoadOnScreen (${_isReviewModeSession ? "Tekrar Ediliyor" : userProgressData.currentUnitOrderIndex + 1}/${UNIT_ORDER.length})",
            ),
            bottom: PreferredSize(
              /* ... (İlerleme Çubuğu Kodu - Değişiklik yok) ... */
              preferredSize: const Size.fromHeight(8.0),
              child: wordsAsync.when(
                data: (words) {
                  if (words.isEmpty || _currentUnitWordsSession.isEmpty) {
                    return Container(height: 8.0);
                  }
                  final totalWordsForProgress = _currentUnitWordsSession.length;
                  if (totalWordsForProgress == 0) return Container(height: 8.0);
                  final progress =
                      (_currentWordSessionIndex) /
                      (totalWordsForProgress > 1
                          ? totalWordsForProgress - 1
                          : 1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(minHeight: 6),
                error: (err, stack) => Container(height: 8.0),
              ),
            ),
          ),
          body: wordsAsync.when(
            data: (wordsFromProvider) {
              if (wordsFromProvider.isEmpty) {
                return Center(
                  child: Text(
                    "Bu ünite ($_unitNameToLoadOnScreen) için henüz kelime eklenmemiş.",
                  ),
                );
              }

              // Kelime listesi (oturum için) veya aktif ünite değiştiyse (yani _unitNameToLoadOnScreen değiştiyse) state'i güncelle
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted &&
                    (_currentUnitWordsSession.isEmpty ||
                        (_currentUnitWordsSession.isNotEmpty &&
                            _currentUnitWordsSession.first.unitName !=
                                _unitNameToLoadOnScreen) ||
                        // Aynı ünitede kelime sayısı değiştiyse (normalde olmaz ama bir güvenlik önlemi)
                        (_currentUnitWordsSession.isNotEmpty &&
                            _currentUnitWordsSession.first.unitName ==
                                _unitNameToLoadOnScreen &&
                            _currentUnitWordsSession.length !=
                                wordsFromProvider.length))) {
                  setState(() {
                    _currentUnitWordsSession = List.from(wordsFromProvider)
                      ..shuffle();
                    _currentWordSessionIndex = 0;
                    _activeWordSession =
                        _currentUnitWordsSession.isNotEmpty
                            ? _currentUnitWordsSession[_currentWordSessionIndex]
                            : null;
                    _showMeaningSession = false;
                    print(
                      "[DEBUG] LearningScreen: Yeni ünite kelimeleri yüklendi ve karıştırıldı: $_unitNameToLoadOnScreen, Kelime Sayısı: ${_currentUnitWordsSession.length}",
                    );
                  });
                }
              });

              // _activeWordSession null ise ve oturum kelimeleri varsa ilk kelimeyi ata
              if (_activeWordSession == null &&
                  _currentUnitWordsSession.isNotEmpty &&
                  _currentWordSessionIndex < _currentUnitWordsSession.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _currentUnitWordsSession.isNotEmpty) {
                    setState(() {
                      _activeWordSession =
                          _currentUnitWordsSession[_currentWordSessionIndex];
                    });
                  }
                });
              }

              if (_activeWordSession == null) {
                return const Center(
                  child: CircularProgressIndicator(
                    key: ValueKey("active_word_loading_ls_v3"),
                  ),
                );
              }

              // 6. KELİMELERİ GÖSTERME VE ETKİLEŞİM BUTONLARI
              return Padding(
                /* ... (Kelime Kartı ve Butonların UI kısmı - Değişiklik yok) ... */
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _activeWordSession!.englishWord,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            _showMeaningSession
                                ? Text(
                                  _activeWordSession!.turkishMeaning,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.blueAccent,
                                  ),
                                  textAlign: TextAlign.center,
                                )
                                : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 10,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() => _showMeaningSession = true);
                                  },
                                  child: const Text(
                                    "Anlamı Göster",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_showMeaningSession) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed:
                            () => _handleWordAction(
                              userId,
                              _activeWordSession!,
                              WordStatus.known,
                            ),
                        child: const Text(
                          "Biliyorum",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed:
                            () => _handleWordAction(
                              userId,
                              _activeWordSession!,
                              WordStatus.difficult,
                            ),
                        child: const Text(
                          "Zorlanıyorum",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed:
                            () => _handleWordAction(
                              userId,
                              _activeWordSession!,
                              WordStatus.unknown,
                            ),
                        child: const Text(
                          "Bilmiyorum",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // "Üniteyi Bitir" butonu artık yok, _handleWordAction içinden tetikleniyor.
                  ],
                ),
              );
            },
            loading:
                () => const Center(
                  child: CircularProgressIndicator(
                    key: ValueKey("words_loading_ls_body_v3"),
                  ),
                ),
            error:
                (err, stack) =>
                    Center(child: Text('Kelimeler yüklenirken hata: $err')),
          ),
        );
      },
      loading:
          () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                key: ValueKey("progress_loading_ls_v3"),
              ),
            ),
          ),
      error:
          (err, stack) => Scaffold(
            body: Center(
              child: Text('Kullanıcı ilerlemesi yüklenirken hata: $err'),
            ),
          ),
    );
  }

  // KELİME AKSİYONLARINI YÖNETME METODU
  void _handleWordAction(
    String userId,
    Word activeWord,
    WordStatus newStatus,
  ) async {
    // ... (Bu metot mesaj #61'deki gibi, Firestore'a kayıt yapar ve son kelimeyse
    //      _checkAndFinalizeUnitCompletion'ı çağırır. _unitNameToLoadOnScreen'i kullanır.) ...
    if (!mounted) return;
    print(
      "[DEBUG] _handleWordAction: userId: $userId, wordId: ${activeWord.id}, newStatus: $newStatus",
    );

    final currentUserProgressSnapshot = ref.read(userProgressProvider);
    UserProgress? latestUserProgress =
        currentUserProgressSnapshot.asData?.value;

    if (latestUserProgress == null) {
      print("[DEBUG] _handleWordAction: Güncel UserProgress alınamadı.");
      return;
    }

    Map<String, WordStatus> updatedWordStatuses = Map.from(
      latestUserProgress.wordStatuses,
    );
    List<String> updatedDontKnowWordsIds = List.from(
      latestUserProgress.dontKnowWordsIds,
    );
    List<String> updatedDifficultWordsIds = List.from(
      latestUserProgress.difficultWordsIds,
    );

    updatedWordStatuses[activeWord.id] = newStatus;

    updatedDontKnowWordsIds.remove(activeWord.id);
    updatedDifficultWordsIds.remove(activeWord.id);

    if (newStatus == WordStatus.unknown) {
      if (!updatedDontKnowWordsIds.contains(activeWord.id)) {
        updatedDontKnowWordsIds.add(activeWord.id);
      }
    } else if (newStatus == WordStatus.difficult) {
      if (!updatedDifficultWordsIds.contains(activeWord.id)) {
        updatedDifficultWordsIds.add(activeWord.id);
      }
    }

    UserProgress progressToSave = UserProgress(
      userId: userId,
      currentUnitOrderIndex: latestUserProgress.currentUnitOrderIndex,
      wordStatuses: updatedWordStatuses,
      dontKnowWordsIds: updatedDontKnowWordsIds,
      difficultWordsIds: updatedDifficultWordsIds,
    );

    try {
      await ref
          .read(firebaseServiceProvider)
          .updateUserProgress(userId, progressToSave);
      print(
        "[DEBUG] _handleWordAction: UserProgress güncellendi (wordId: ${activeWord.id}, newStatus: $newStatus).",
      );
    } catch (e) {
      /* ... hata yönetimi ... */
      print("[DEBUG] _handleWordAction: UserProgress güncellenirken HATA: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kelime durumu kaydedilemedi: $e")),
        );
      }
    }

    // Bir sonraki kelimeye geç veya üniteyi bitirme kontrolü yap
    if (_currentWordSessionIndex < _currentUnitWordsSession.length - 1) {
      if (mounted) {
        setState(() {
          _showMeaningSession = false;
          _currentWordSessionIndex++;
          _activeWordSession =
              _currentUnitWordsSession[_currentWordSessionIndex];
        });
      }
    } else {
      // Bu ünitedeki son kelimeydi. Ünite tamamlama kontrolünü yap.
      print(
        "[DEBUG] _handleWordAction: Son kelime işlendi. Ünite tamamlama kontrolü yapılacak. Çalışılan ünite: $_unitNameToLoadOnScreen",
      );
      if (mounted && _unitNameToLoadOnScreen != null) {
        setState(() {
          _showMeaningSession = false;
        }); // Önce anlamı gizle
        // Kullanıcının son aksiyonunun UI'da yansıması için küçük bir gecikme
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // _checkAndFinalizeUnitCompletion'a o an çalışılan ünitenin kelimelerini (_currentUnitWordsSession)
            // ve o ünitenin adını (_unitNameToLoadOnScreen) veriyoruz.
            _checkAndFinalizeUnitCompletion(
              userId,
              _currentUnitWordsSession,
              _unitNameToLoadOnScreen!,
            );
          }
        });
      }
    }
  }

  // ÜNİTE TAMAMLAMA KONTROLÜ VE KİLİT AÇMA METODU
  void _checkAndFinalizeUnitCompletion(
    String userId,
    List<Word> wordsInSessionJustCompleted,
    String completedUnitName,
  ) async {
    // ... (Bu metot mesaj #61'deki gibi, _isReviewModeSession değişkenini kullanarak
    //      normal ilerleme mi yoksa tekrar mı yapıldığını anlar ve ona göre davranır.) ...
    if (!mounted || wordsInSessionJustCompleted.isEmpty) return;

    final latestUserProgressSnapshot = ref.read(userProgressProvider);
    UserProgress? latestUserProgress = latestUserProgressSnapshot.asData?.value;

    if (latestUserProgress == null) {
      print(
        "_checkAndFinalizeUnitCompletion: En güncel UserProgress alınamadı.",
      );
      return;
    }

    int knownWordsInThisUnit = 0;
    for (Word wordInUnit in wordsInSessionJustCompleted) {
      if (latestUserProgress.wordStatuses[wordInUnit.id] == WordStatus.known) {
        knownWordsInThisUnit++;
      }
    }
    double successRate =
        (wordsInSessionJustCompleted.isNotEmpty)
            ? (knownWordsInThisUnit / wordsInSessionJustCompleted.length) * 100
            : 0.0;
    print(
      "Ünite tamamlama kontrolü: $completedUnitName. Başarı: %${successRate.toStringAsFixed(1)} ($knownWordsInThisUnit/${wordsInSessionJustCompleted.length})",
    );

    UserProgress progressToUpdate = UserProgress(
      userId: userId,
      currentUnitOrderIndex: latestUserProgress.currentUnitOrderIndex,
      wordStatuses: Map.from(latestUserProgress.wordStatuses),
      difficultWordsIds: List.from(latestUserProgress.difficultWordsIds),
      dontKnowWordsIds: List.from(latestUserProgress.dontKnowWordsIds),
    );

    bool unitAdvancedInThisSession =
        false; // Bu oturumda bir sonraki üniteye geçilip geçilmediğini takip eder
    String completionMessage = "";
    bool shouldResetForNextUiState =
        false; // UI'ı bir sonraki duruma hazırlamak için

    // SADECE mevcut ilerleme ünitesi oynanıyorsa (_isReviewModeSession == false)
    // VE %70 başarı varsa bir sonraki ünite kilidi açılır.
    if (!_isReviewModeSession &&
        UNIT_ORDER[latestUserProgress.currentUnitOrderIndex] ==
            completedUnitName) {
      if (successRate >= 70.0) {
        if (latestUserProgress.currentUnitOrderIndex < UNIT_ORDER.length - 1) {
          progressToUpdate.currentUnitOrderIndex =
              latestUserProgress.currentUnitOrderIndex + 1;
          unitAdvancedInThisSession = true;
          completionMessage =
              "Tebrikler! '$completedUnitName' ünitesini %${successRate.toStringAsFixed(0)} başarı ile tamamladınız. '${UNIT_ORDER[progressToUpdate.currentUnitOrderIndex]}' ünitesi açıldı!";
        } else {
          // Son ünite de başarıyla tamamlandı.
          completionMessage =
              "Tebrikler! Tüm tanımlı üniteleri başarıyla tamamladınız.";
        }
        shouldResetForNextUiState = true;
      } else {
        // Başarı oranı %70'in altında (ve normal ilerleme ünitesiydi)
        completionMessage =
            "'$completedUnitName' ünitesini tamamlamak için en az %70 başarı gerekli. Mevcut başarınız: %${successRate.toStringAsFixed(0)}. Lütfen üniteyi tekrar çalışın.";
        shouldResetForNextUiState = true; // Aynı üniteyi tekrar yüklemek için.
      }
    } else if (_isReviewModeSession) {
      // İnceleme modundaydı, başarıya bakılmaksızın ilerleme indeksi (currentUnitOrderIndex) değişmez.
      // Sadece kelime durumları (wordStatuses) ve depolama listeleri güncellenir.
      completionMessage =
          "'$completedUnitName' ünitesini tekrar ettiniz. Başarınız: %${successRate.toStringAsFixed(0)}.";
      // İnceleme bittiğinde UnitSelectionScreen'e geri dönmek iyi bir seçenek olabilir.
      // Veya kullanıcıyı normal ilerleme ünitesine döndürebiliriz.
      shouldResetForNextUiState =
          true; // Bu, build'in widget.targetUnitName'i null ise normal üniteyi yüklemesini sağlar
      // veya UnitSelectionScreen'e pop() ile dönülür.
    } else {
      // Bu durum, _unitNameToLoadOnScreen ve userProgress.currentUnitOrderIndex senkronizasyonunda
      // beklenmedik bir durum olursa (örneğin, kullanıcı zaten daha ilerideki bir ünitedeyken,
      // LearningScreen'e targetUnitName olmadan gelinirse ama userProgress.currentUnitOrderIndex
      // tamamlanan üniteden farklıysa) diye bir güvenlik önlemi.
      print(
        "Beklenmedik durum: _checkAndFinalizeUnitCompletion. _isReviewModeSession: $_isReviewModeSession, completedUnitName: $completedUnitName, userProgressUnit: ${UNIT_ORDER[latestUserProgress.currentUnitOrderIndex]}",
      );
      completionMessage = "'$completedUnitName' ünitesi tamamlandı.";
      shouldResetForNextUiState = true;
    }

    // Her durumda UserProgress'i kaydet (wordStatuses, listeler ve belki index güncellendi)
    await ref
        .read(firebaseServiceProvider)
        .updateUserProgress(userId, progressToUpdate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(completionMessage),
          duration: const Duration(seconds: 4),
        ),
      );

      if (shouldResetForNextUiState) {
        // Eğer inceleme modundaysak ve bittiyse, UnitSelectionScreen'e geri dön.
        if (_isReviewModeSession && Navigator.canPop(context)) {
          Navigator.of(
            context,
          ).pop(); // LearningScreen'i kapat, UnitSelectionScreen'e dön.
          // UnitSelectionScreen'deki .then() bloğu provider'ı yenileyecektir.
        } else {
          // Normal ilerleme veya son ünite bittiyse, UI'ı sıfırla ki build metodu
          // yeni aktif üniteyi (veya "tümü bitti" mesajını) yüklesin.
          setState(() {
            _currentUnitWordsSession = [];
            _currentWordSessionIndex = 0;
            _activeWordSession = null;
            _showMeaningSession = false;
          });
        }
      }
    }

    // 3 ve 5 ünite kontrolleri (sadece gerçekten ünite atlandıysa)
    if (unitAdvancedInThisSession) {
      int newGlobalIndex = progressToUpdate.currentUnitOrderIndex;
      if (newGlobalIndex > 0 && newGlobalIndex % 3 == 0) {
        String reviewedUnits = UNIT_ORDER
            .sublist(newGlobalIndex - 3, newGlobalIndex)
            .join(', ');
        print("3 ÜNİTE BİTTİ! ($reviewedUnits) TEKRAR ZAMANI!");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$reviewedUnits üniteleri için tekrar zamanı! (Özellik eklenecek)",
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      if (newGlobalIndex > 0 && newGlobalIndex % 5 == 0) {
        String quizedUnits = UNIT_ORDER
            .sublist(newGlobalIndex - 5, newGlobalIndex)
            .join(', ');
        print("5 ÜNİTE BİTTİ! ($quizedUnits) QUIZ ZAMANI!");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$quizedUnits üniteleri için quiz zamanı! (Özellik eklenecek)",
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }
}
