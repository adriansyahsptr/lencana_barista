import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/admin_login.dart';
import 'screens/user_login.dart';
import 'screens/signup.dart';
import 'screens/user_home.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Tambahkan impor ini

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  cameras = await availableCameras();
  
  if (!await _checkInternetConnection()) {
    runApp(NoInternetApp());
    return;
  }

  if (!await _requestLocationPermission()) {
    runApp(NoLocationPermissionApp());
    return;
  }

  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

Future<bool> _checkInternetConnection() async {
  var connectivityResult = await (Connectivity().checkConnectivity()); // Pastikan menggunakan Connectivity dari connectivity_plus
  if (connectivityResult == ConnectivityResult.none) {
    return false;
  }
  return true;
}

Future<bool> _requestLocationPermission() async {
  var status = await Permission.location.status;
  if (status.isDenied) {
    status = await Permission.location.request();
  }

  if (status.isDenied || status.isPermanentlyDenied) {
    openAppSettings();
    return false;
  }

  return true;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lencana Barista',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          color: Color(0xFF543310), // Warna coklat dari palet yang diberikan
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white), // Panah back putih
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late bool _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    });

    if (_isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserHomeScreen(camera: cameras.first),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lencana Barista'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Image.asset(
              'assets/STORIA PERINTIS.png',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF543310),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignupScreen(camera: cameras.first)),
                );
              },
              child: const Text('Buat Akun', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF543310),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserLoginScreen(camera: cameras.first)),
                );
              },
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF543310),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AdminLoginScreen()),
                );
              },
              child: const Text('Admin Manager', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class NoInternetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lencana Barista',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          color: Color(0xFF543310), // Warna coklat dari palet yang diberikan
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white), // Panah back putih
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('No Internet Connection')),
        body: Center(
          child: Text('Tidak ada koneksi internet. Silakan periksa koneksi Anda dan coba lagi.'),
        ),
      ),
    );
  }
}

class NoLocationPermissionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lencana Barista',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: AppBarTheme(
          color: Color(0xFF543310), // Warna coklat dari palet yang diberikan
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white), // Panah back putih
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Location Permission Required')),
        body: Center(
          child: Text('Izin lokasi diperlukan untuk menggunakan aplikasi ini. Silakan aktifkan di pengaturan.'),
        ),
      ),
    );
  }
}
