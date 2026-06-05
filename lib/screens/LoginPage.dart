import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import 'RegisterPage.dart';
import 'HomePage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> signInWithEmail() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;

      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await _auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('verify_email_message')),
            duration: const Duration(seconds: 5),
          ),
        );

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white.withValues(alpha: 0.95),
            title: Text(
              AppLocalizations.of(context).translate('email_not_verified'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            content: Text(
              AppLocalizations.of(context).translate('resend_verification_email'),
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                child: Text(AppLocalizations.of(context).translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await userCredential.user!.sendEmailVerification();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).translate('verification_email_sent'))),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("${AppLocalizations.of(context).translate('verification_email_error')}: ${e.toString()}")),
                    );
                  }
                },
                child: Text(AppLocalizations.of(context).translate('send')),
              ),
            ],
          ),
        );

        return;
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists && userDoc.data()?['status'] == 'inactive') {
        if (userCredential.user!.emailVerified) {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({'status': 'active'});
        } else {
          await _auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).translate('account_inactive'))),
          );
          return;
        }
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context).translate('error')}: ${e.toString()}")),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // v7: singleton pattern, initialize once before use
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      // v7: authenticate() replaces signIn()
      final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

      // v7: idToken is on googleUser.authentication (now synchronous)
      final String? idToken = googleUser.authentication.idToken;

      // v7: accessToken requires explicit scope authorization
      final GoogleSignInClientAuthorization clientAuth =
          await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);
      final String accessToken = clientAuth.accessToken;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (!mounted) return;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).translate('sign_in_failed'))),
        );
        return;
      }

      final DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const RegisterPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end)
                  .chain(CurveTween(curve: curve));
              return SlideTransition(
                  position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'BACOOR',
                    style: GoogleFonts.poppins(
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF4080FF),
                    ),
                  ),
                  Text(
                    'DINATES',
                    style: GoogleFonts.poppins(
                      fontSize: 29,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFFB300),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: localizations.translate('email'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: localizations.translate('password'),
                  labelStyle: const TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: signInWithEmail,
                child: Text(
                  localizations.translate('sign_in'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              Text(localizations.translate('or_sign_in_with')),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: signInWithGoogle,
                    child: Image.asset('assets/google.png', height: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RegisterPage()),
                  );
                },
                child: Text(
                  localizations.translate('dont_have_account'),
                  style: const TextStyle(color: Colors.blue, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}