import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lencana_barista/screens/user_home.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';

class UserLoginScreen extends StatefulWidget {
  final CameraDescription camera;

  UserLoginScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _UserLoginScreenState createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
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

  Future<void> _login() async {
    try {
      final user = await FirebaseAuth.instance.signInWithEmailAndPassword(
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
          case 'wrong-password':
            _showCupertinoAlertDialog('Password Salah', 'Password pada email salah, jika lupa password hubungi admin');
            break;
          case 'user-not-found':
            _showCupertinoAlertDialog('Email Tidak Terdaftar', 'Email tidak terdaftar pada database, coba buat akun baru');
            break;
          default:
            _showCupertinoAlertDialog('Login Gagal', 'Terjadi kesalahan: ${e.message}');
        }
      } else {
        _showCupertinoAlertDialog('Login Gagal', 'Terjadi kesalahan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Pengguna', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF543310),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Log In',
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
              onPressed: _login,
              child: Text('Login', style: TextStyle(color: Colors.white)),
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
