import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lencana_barista/screens/user_home.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';

class SignupScreen extends StatefulWidget {
  final CameraDescription camera;

  SignupScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _obscureText = true;

  Future<void> _saveLoginStatus(String email, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userType', 'user');
    await prefs.setString('userEmail', email);
    await prefs.setString('username', username);
  }

  void _showCupertinoAlertDialog(String title, String content) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              child: Text('Coba Lagi'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Akun', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF543310),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Buat Akun',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email dengan @gmail.com'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
              obscureText: _obscureText,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final user = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                    email: _emailController.text,
                    password: _passwordController.text,
                  );
                  await _saveLoginStatus(user.user!.email!, _usernameController.text);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserHomeScreen(camera: widget.camera),
                    ),
                  );
                } catch (e) {
                  if (e is FirebaseAuthException) {
                    switch (e.code) {
                      case 'invalid-email':
                        _showCupertinoAlertDialog('Email Format Salah', 'Berikan email google yang benar (xxx@gmail.com)');
                        break;
                      case 'weak-password':
                        _showCupertinoAlertDialog('Password Lemah', 'Password yang Anda masukkan terlalu lemah');
                        break;
                      case 'email-already-in-use':
                        _showCupertinoAlertDialog('Email Sudah Terdaftar', 'Email ini sudah terdaftar, jika lupa password pada email tersebut hubungi admin');
                        break;
                      default:
                        _showCupertinoAlertDialog('Registrasi Gagal', 'Terjadi kesalahan: ${e.message}');
                    }
                  } else {
                    _showCupertinoAlertDialog('Registrasi Gagal', 'Terjadi kesalahan: $e');
                  }
                }
              },
              child: Text('Daftar', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF543310),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
