import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'package:lencana_barista/main.dart';
import 'admin_login.dart';
import 'package:analog_clock/analog_clock.dart';
import 'package:ntp/ntp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class UserHomeScreen extends StatefulWidget {
  final CameraDescription camera;

  const UserHomeScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _UserHomeScreenState createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  late String _timeString;
  String _email = "user@example.com";
  String _username = "User";
  late DateTime _currentTime;
  DateTime? _lastOffShiftDate;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (!await _requestLocationPermission()) {
      _showLocationDeniedDialog();
      return;
    }

    await _initializeTime();
    Timer.periodic(Duration(seconds: 1), (Timer t) => _updateTime());
    await _loadUserData();
    setState(() {
      _initialized = true;
    });
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied) {
      if (await Permission.location.request().isGranted) {
        return true;
      }
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
    return status == PermissionStatus.granted;
  }

  Future<void> _initializeTime() async {
    DateTime ntpTime = await NTP.now();
    setState(() {
      _currentTime = ntpTime;
      _timeString = _formatDateTime(_currentTime);
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getString('userEmail') ?? "user@example.com";
      _username = prefs.getString('username') ?? "User";
      _lastOffShiftDate = DateTime.tryParse(prefs.getString('lastOffShiftDate') ?? '');
    });
  }

  void _updateTime() {
    setState(() {
      _currentTime = _currentTime.add(Duration(seconds: 1));
      _timeString = _formatDateTime(_currentTime);
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dateTime);
  }

  String _greetingMessage() {
    final hour = _currentTime.hour;
    if (hour < 12) {
      return 'Selamat Pagi, $_username';
    } else if (hour < 17) {
      return 'Selamat Siang, $_username';
    } else {
      return 'Selamat Malam, $_username';
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
    );
  }

  Future<void> _offShift() async {
    if (_lastOffShiftDate != null &&
        _lastOffShiftDate!.year == _currentTime.year &&
        _lastOffShiftDate!.month == _currentTime.month &&
        _lastOffShiftDate!.day == _currentTime.day) {
      _showMessage('Anda sudah melakukan Off-Shift hari ini.');
      return;
    }

    final confirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Off-Shift'),
        content: Text('Anda yakin Off-Shift pada ${_formatDate(_currentTime)}?'),
        actions: <Widget>[
          TextButton(
            child: Text('Tidak'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: Text('Ya'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      Position position;
      try {
        position = await _getCurrentPosition();
      } catch (e) {
        _showMessage('Tidak dapat mendapatkan lokasi. Pastikan lokasi diaktifkan.');
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pesan Terkirim'),
          content: Text('Pesan sudah disampaikan ke manager'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      prefs.setString('lastOffShiftDate', _currentTime.toIso8601String());
      setState(() {
        _lastOffShiftDate = _currentTime;
      });

      await FirebaseFirestore.instance.collection('attendance').add({
        'name': _username,
        'status': 'Off Shift',
        'shift': 'N/A',
        'date': DateFormat('yyyy-MM-dd').format(_currentTime),
        'time': DateFormat('HH:mm:ss').format(_currentTime),
        'location': '${position.latitude}, ${position.longitude}', // Valid coordinates
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _showMessage(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pesan'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showLocationDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Izin Lokasi Diperlukan'),
        content: Text('Aplikasi ini memerlukan izin lokasi untuk berfungsi. Silakan izinkan akses lokasi di pengaturan.'),
        actions: <Widget>[
          TextButton(
            child: Text('Buka Pengaturan'),
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Keluar'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_greetingMessage(), style: const TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF543310),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: <Widget>[
          Container(
            height: 200.0,
            padding: const EdgeInsets.only(top: 20.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: AnalogClock(
                decoration: BoxDecoration(
                  border: Border.all(width: 2.0, color: Colors.black),
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                width: 150.0,
                height: 150.0,
                isLive: true,
                hourHandColor: Colors.black,
                minuteHandColor: Colors.black,
                secondHandColor: Colors.red,
                numberColor: Colors.black87,
                showNumbers: true,
                textScaleFactor: 1.4,
                showTicks: true,
                showDigitalClock: false,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tanggal: ${_formatDate(_currentTime)}',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 20),
          Text(
            _timeString,
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF543310)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CameraScreen(camera: widget.camera),
                ),
              );
            },
            child: const Text('Mulai Absen', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF543310)),
            onPressed: _offShift,
            child: const Text('Off Shift', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(_username),
            accountEmail: Text(_email),
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.person, color: Colors.white),
              backgroundColor: Color(0xFF543310),
            ),
            decoration: BoxDecoration(
              color: Color(0xFF543310),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log Out'),
            onTap: _logout,
          ),
          ListTile(
            leading: Icon(Icons.admin_panel_settings),
            title: Text('Admin Login'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminLoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
