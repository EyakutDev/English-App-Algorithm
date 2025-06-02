// lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// firebase_service.dart dosyasındaki firebaseServiceProvider'a erişmek için doğru yolu kullanın
// Proje adınız "algorithm_101" ise ve providers klasörü lib altındaysa:
import 'package:algorithm_101/providers/firebase_providers.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey =
      GlobalKey<FormState>(); // Formun durumunu yönetmek için anahtar
  bool _isLoginMode = true; // True ise Giriş modu, false ise Kayıt modu
  bool _isLoading = false; // İşlem sırasında yükleme göstergesi için

  String _email = '';
  String _password = '';

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Firebase Auth instance'ı
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Formu gönderme ve kimlik doğrulama işlemini yapma fonksiyonu
  Future<void> _submitAuthForm() async {
    // 1. Formdaki validator'ları çalıştırarak girdilerin geçerli olup olmadığını kontrol et
    final isValid = _formKey.currentState?.validate();
    if (isValid == null || !isValid) {
      return; // Form geçerli değilse işlemi durdur
    }
    // 2. Form geçerliyse, onSaved metotlarını çalıştırarak _email ve _password değişkenlerine değerleri ata
    _formKey.currentState?.save();

    // 3. Yükleme göstergesini aktif et
    setState(() {
      _isLoading = true;
    });

    UserCredential?
    userCredential; // Kullanıcı kimlik bilgilerini tutacak Firebase objesi

    try {
      if (_isLoginMode) {
        // Eğer Giriş modundaysak, Firebase ile giriş yapmayı dene
        print("Giriş deneniyor: $_email");
        userCredential = await _auth.signInWithEmailAndPassword(
          email: _email.trim(), // Başındaki/sonundaki boşlukları temizle
          password: _password.trim(),
        );
        print("Giriş başarılı: ${userCredential.user?.uid}");
      } else {
        // Eğer Kayıt modundaysak, Firebase ile yeni kullanıcı oluşturmayı dene
        print("Kayıt deneniyor: $_email");
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: _email.trim(),
          password: _password.trim(),
        );
        print("Kayıt başarılı: ${userCredential.user?.uid}");

        // YENİ KULLANICI KAYIT OLDUĞUNDA ÇOK ÖNEMLİ:
        // Kullanıcı için Firestore'da başlangıç UserProgress verisini oluştur.
        if (userCredential.user != null) {
          // firebaseServiceProvider'ı kullanarak FirebaseService'e erişiyoruz
          // ve createInitialUserProgress metodunu çağırıyoruz.
          await ref
              .read(firebaseServiceProvider)
              .createInitialUserProgress(userCredential.user!.uid);
          print(
            "Yeni kullanıcı için başlangıç UserProgress verisi Firestore'da oluşturuldu: ${userCredential.user!.uid}",
          );
        }
      }

      // Başarılı giriş veya kayıt sonrası, uygulamanın ana ekranına yönlendirme
      // main.dart dosyasındaki authStateChangesProvider tarafından otomatik olarak yönetilecektir.
      // Bu yüzden bu ekranda ek bir Navigator.push/pop yapmamıza genellikle gerek kalmaz.
      // Eğer işlem başarılıysa ve widget hala ağaçtaysa (mounted), _isLoading'i false yap.
      // Ancak yönlendirme olacağı için bu setState çağrısı bazen "unmounted" hatası verebilir,
      // bu yüzden başarılı durumda setState'i burada yapmayabiliriz. Yönlendirme zaten ekranı değiştirecek.
    } on FirebaseAuthException catch (error) {
      // Firebase Authentication'dan kaynaklanan belirli hataları yakala
      String message = 'Bir hata oluştu, lütfen bilgilerinizi kontrol edin.';
      // Sık karşılaşılan hata kodlarına göre kullanıcı dostu mesajlar hazırla
      if (error.code == 'weak-password') {
        message = 'Girdiğiniz şifre çok zayıf.';
      } else if (error.code == 'email-already-in-use') {
        message =
            'Bu e-posta adresi zaten başka bir hesap tarafından kullanılıyor.';
      } else if (error.code == 'user-not-found') {
        message = 'Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.';
      } else if (error.code == 'wrong-password') {
        message = 'Girdiğiniz şifre yanlış.';
      } else if (error.code == 'invalid-email') {
        message = 'Geçersiz bir e-posta adresi formatı girdiniz.';
      }
      // Diğer hata kodları için Firebase dokümantasyonuna bakabilirsiniz.
      print(
        "AuthScreen - FirebaseAuthException: Kod: ${error.code}, Mesaj: ${error.message}",
      );

      // Eğer widget hala ekrandaysa (kullanıcı başka bir yere gitmediyse) hata mesajını göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error, // Hata rengi
          ),
        );
      }
    } catch (error) {
      // Diğer beklenmedik hataları yakala
      print("AuthScreen - Genel Hata: $error");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Giriş/Kayıt sırasında beklenmedik bir hata oluştu.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    // İşlem tamamlandığında (başarılı veya başarısız), eğer widget hala ekrandaysa yükleme göstergesini kaldır
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Controller'ları temizle
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar isteğe bağlı, istersen kaldırabilirsin
      // appBar: AppBar(
      //   title: Text(_isLoginMode ? 'Giriş Yap' : 'Kayıt Ol'),
      // ),
      backgroundColor: Colors.lightBlue[50], // Arka plan rengi
      body: Center(
        child: SingleChildScrollView(
          // Klavye açıldığında içeriğin kaymasını sağlar
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Card(
            // Formu bir kart içinde göstermek daha şık durabilir
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey, // Form anahtarını ata
                child: Column(
                  mainAxisSize: MainAxisSize.min, // İçeriğe göre boyut al
                  children: <Widget>[
                    // Başlık
                    Text(
                      _isLoginMode
                          ? 'Tekrar Hoş Geldiniz!'
                          : 'Aramıza Katılın!',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // E-posta giriş alanı
                    TextFormField(
                      key: const ValueKey('email_auth'), // Testler için anahtar
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-posta Adresiniz',
                        hintText: 'ornek@eposta.com',
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Theme.of(context).primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        // Doğrulama fonksiyonu
                        if (value == null ||
                            value.trim().isEmpty ||
                            !value.contains('@')) {
                          return 'Lütfen geçerli bir e-posta adresi girin.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        // Form kaydedildiğinde çalışır
                        _email = value ?? '';
                      },
                    ),
                    const SizedBox(height: 16),

                    // Şifre giriş alanı
                    TextFormField(
                      key: const ValueKey(
                        'password_auth',
                      ), // Testler için anahtar
                      controller: _passwordController,
                      obscureText:
                          true, // Şifreyi gizler (nokta olarak gösterir)
                      decoration: InputDecoration(
                        labelText: 'Şifreniz',
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Theme.of(context).primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        // Doğrulama fonksiyonu
                        if (value == null ||
                            value.trim().isEmpty ||
                            value.length < 6) {
                          return 'Şifreniz en az 6 karakter olmalıdır.';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        // Form kaydedildiğinde çalışır
                        _password = value ?? '';
                      },
                    ),
                    const SizedBox(height: 24),

                    // Yükleme göstergesi veya Giriş/Kayıt butonu
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).primaryColor, // Ana renk
                          foregroundColor: Colors.white, // Yazı rengi
                          minimumSize: const Size(
                            double.infinity,
                            50,
                          ), // Butonun tüm genişliği kaplaması
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed:
                            _submitAuthForm, // Butona tıklandığında _submitAuthForm'u çalıştır
                        child: Text(_isLoginMode ? 'GİRİŞ YAP' : 'KAYIT OL'),
                      ),
                    const SizedBox(height: 16),

                    // Giriş/Kayıt modunu değiştirme butonu
                    if (!_isLoading)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLoginMode = !_isLoginMode; // Modu tersine çevir
                            _formKey.currentState
                                ?.reset(); // Hata mesajlarını temizle
                            _emailController.clear(); // Email alanını temizle
                            _passwordController
                                .clear(); // Şifre alanını temizle
                          });
                        },
                        child: Text(
                          _isLoginMode
                              ? 'Hesabınız yok mu? Hemen kaydolun!'
                              : 'Zaten bir hesabınız var mı? Giriş yapın.',
                          style: TextStyle(
                            color: Theme.of(context).primaryColorDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
