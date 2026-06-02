import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:untitled/l10n/app_localizations.dart';
import 'package:untitled/providers/auth_provider.dart' as CustomAuthProvider;

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  bool _isCurrentPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String password) {
    if (password.isEmpty) {
      _passwordStrength = 0.0;
      _passwordStrengthText = '';
    } else if (password.length < 6) {
      _passwordStrength = 0.2;
      _passwordStrengthText = 'Very Weak';
    } else if (password.length < 8) {
      _passwordStrength = 0.4;
      _passwordStrengthText = 'Weak';
    } else if (password.contains(RegExp(r'[0-9]')) && password.contains(RegExp(r'[a-zA-Z]'))) {
      _passwordStrength = 0.7;
      _passwordStrengthText = 'Good';
    } else if (password.contains(RegExp(r'[0-9]')) && password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[!@#\$&*~]'))) {
      _passwordStrength = 1.0;
      _passwordStrengthText = 'Strong';
    } else {
      _passwordStrength = 0.5;
      _passwordStrengthText = 'Average';
    }
    setState(() {});
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final user = context.read<CustomAuthProvider.AuthProvider>().user;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text.trim());
      await context.read<CustomAuthProvider.AuthProvider>().user?.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('passwordUpdatedSuccessfully'))),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message = AppLocalizations.of(context).translate('passwordChangeFailed');
      if (e.code == 'wrong-password') {
        message = AppLocalizations.of(context).translate('currentPasswordIncorrect');
      } else if (e.code == 'weak-password') {
        message = AppLocalizations.of(context).translate('newPasswordTooWeak');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('unexpectedErrorOccurred'))),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = context.read<CustomAuthProvider.AuthProvider>().user?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('passwordResetEmailSent'))),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('failedToSendPasswordResetEmail'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('changePassword')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('currentPassword'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isCurrentPasswordVisible = !_isCurrentPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isCurrentPasswordVisible,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context).translate('enterCurrentPassword');
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: Text(AppLocalizations.of(context).translate('forgotPassword')),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                onChanged: _checkPasswordStrength,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('newPassword'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isNewPasswordVisible,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return AppLocalizations.of(context).translate('newPasswordTooShort');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              if (_passwordStrength > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _passwordStrength,
                      backgroundColor: Colors.grey[300],
                      color: _passwordStrength == 1.0 ? Colors.green : Colors.orange,
                      minHeight: 5,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _passwordStrengthText,
                      style: TextStyle(
                        color: _passwordStrength == 1.0 ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).translate('confirmPassword'),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                obscureText: !_isConfirmPasswordVisible,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return AppLocalizations.of(context).translate('passwordsDoNotMatch');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(                  onPressed: _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4080FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(AppLocalizations.of(context).translate('changePassword')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
