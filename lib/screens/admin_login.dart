import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lencana_barista/screens/admin_home.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/cupertino.dart';

class AdminLoginScreen extends StatefulWidget {
  @override
  _AdminLoginScreenState createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isBiometricAvailable = false;
  bool _obscureText = true;
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _checkBiometrics();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool? isLoggedIn = prefs.getBool('isLoggedIn');
    if (isLoggedIn == true) {
      _loginWithFingerprint();
    }
  }

  Future<void> _checkBiometrics() async {
    bool isBiometricAvailable = await auth.canCheckBiometrics;
    setState(() {
      _isBiometricAvailable = isBiometricAvailable;
    });
  }

  Future<void> _login() async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username == 'storiamo' && password == 'admin') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userType', 'admin');
      await prefs.setString('username', username);
      await prefs.setString('email', 'admin@storiamo.com');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AdminHomeScreen()),
      );
    } else if (username != 'storiamo') {
      _showCupertinoAlertDialog('Username Salah', 'Username pada admin salah');
    } else if (password != 'admin') {
      _showCupertinoAlertDialog('Password Salah', 'Password pada admin salah');
    }
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

  Future<bool> _authenticateWithBiometrics() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to authenticate',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error using fingerprint authentication: $e')),
      );
    }
    return authenticated;
  }

  Future<void> _loginWithFingerprint() async {
    bool authenticated = await _authenticateWithBiometrics();
    if (authenticated) {
      final prefs = await SharedPreferences.getInstance();
      String? username = prefs.getString('username');
      if (username == 'storiamo') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AdminHomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fingerprint authentication succeeded, but admin data not found. Please login with username and password first.')),
        );
      }
    } else {
      _showCupertinoAlertDialog('Gagal Mengautentikasi', 'Gagal mengautentikasi sidik jari. Coba lagi atau input dulu username dan password yang benar, setelah itu coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Log In', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF543310),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Admin Log In',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF543310),
              ),
            ),
            const SizedBox(height: 20),
            if (_isBiometricAvailable)
              Center(
                child: ElevatedButton(
                  onPressed: _loginWithFingerprint,
                  child: const Text('Login with Fingerprint', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF543310),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
