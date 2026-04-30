import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- STRICT EMAIL LOGIN (NO REGISTRATION) ---
  Future<void> _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Attempt to log in. This will throw an error if the account doesn't exist.
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 2. Verify they actually have a profile in your database
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // They have an Auth account, but no database profile. Kick them out.
        await FirebaseAuth.instance.signOut();
        _showError('حسابك غير مسجل في قاعدة البيانات. تواصل مع الإدارة.');
        setState(() => _isLoading = false);
        return;
      }

      await _routeUser(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showError('حدث خطأ في الاتصال بقاعدة البيانات');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- STRICT GOOGLE SIGN IN (NO REGISTRATION) ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      await GoogleSignIn.instance.initialize();
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance
          .authenticate();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final uid = userCredential.user!.uid;

      // Check if this user exists in your Firestore database
      DocumentReference userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid);
      DocumentSnapshot userDoc = await userDocRef.get();

      // IF THEY DO NOT EXIST: Create their profile instead of deleting them
      if (!userDoc.exists) {
        await userDocRef.set({
          'name': userCredential.user!.displayName ?? 'مستخدم جديد',
          'email': userCredential.user!.email,
          'role': 'student', // Assigning default role
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Route them normally
      await _routeUser(uid);
    } catch (e) {
      print("Google Auth Error: $e"); // Helpful for debugging in terminal
      _showError('حدث خطأ أثناء التحقق من حساب Google');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the brand new account in Firebase Auth
      UserCredential credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = credential.user!.uid;

      // 2. Create their initial profile in the Firestore database
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name':
            'مستخدم جديد', // You can add a Name TextField later to capture this
        'email': email,
        'role': 'student', // Default role
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Route them to the app
      await _routeUser(uid);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        _showError('كلمة المرور ضعيفة جداً');
      } else if (e.code == 'email-already-in-use') {
        _showError('هذا الحساب موجود بالفعل، قم بتسجيل الدخول');
      } else {
        _handleAuthError(e);
      }
    } catch (e) {
      _showError('حدث خطأ في إنشاء الحساب');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SHARED ROUTING LOGIC ---
  Future<void> _routeUser(String uid) async {
    try {
      // Step 1: Prove login worked and we are fetching data
      _showError('Login Success: Fetching database profile...');

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _showError('Error: Profile not found in database.');
        await FirebaseAuth.instance.signOut();
        return;
      }

      final data = userDoc.data() as Map<String, dynamic>?;

      if (data == null) {
        _showError('Error: Profile data is null.');
        return;
      }

      String roleString = data['role'] ?? 'student';
      UserRole role = roleString == 'teacher'
          ? UserRole.teacher
          : UserRole.student;
      String userName = data.containsKey('name') ? data['name'] : 'مستخدم';

      // Step 2: Prove data was fetched and we are routing
      _showError('Data Fetched: Opening MainScreen...');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(role: role, userName: userName),
          ),
        );
      }
    } catch (e) {
      // If the data parsing or routing fails, show the exact error
      _showError('CRASH IN ROUTING: $e');
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
    _showError('System Error: ${e.code}');
    if (e.code == 'user-not-found' ||
        e.code == 'wrong-password' ||
        e.code == 'invalid-credential') {
      errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'صيغة البريد الإلكتروني غير صحيحة';
    }
    _showError(errorMessage);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.recording),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.school_rounded,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'تسجيل الدخول',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                obscureText: true,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleEmailLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),

                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'تسجيل الدخول بالبريد',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              
              const SizedBox(height: 24),
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: AppColors.textSecondary,
                      thickness: 0.5,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'أو',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: AppColors.textSecondary,
                      thickness: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(
                  Icons.g_mobiledata,
                  size: 28,
                  color: Colors.blue,
                ), // Placeholder for Google icon
                label: const Text(
                  'تسجيل باستخدام Google',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
