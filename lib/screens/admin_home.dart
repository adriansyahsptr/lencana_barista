import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lencana_barista/main.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'user_home.dart';

class AdminHomeScreen extends StatefulWidget {
  @override
  _AdminHomeScreenState createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<Map<String, dynamic>> _attendanceData = [];
  List<String> _logMessages = [];
  CameraDescription? camera;
  late String _username;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _loadUsername();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    setState(() {
      camera = cameras.first;
    });
  }

  Future<void> _loadAttendanceData() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('attendance').orderBy('timestamp', descending: true).get();
      final List<Map<String, dynamic>> attendanceData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        _addLogMessage(data);
        return {
          'name': data['name'] ?? '',
          'status': data['status'] ?? '',
          'shift': data['shift'] ?? '',
          'date': (data['timestamp'] as Timestamp).toDate(),
          'time': data['time'] ?? '',
          'location': data['location'] ?? '',
          'imageURL': data['imageURL'] ?? '',
          'id': doc.id,
          'alasan': data['alasan'] ?? '',
        };
      }).toList();

      setState(() {
        _attendanceData = attendanceData;
      });
    } catch (e) {
      print('Error loading attendance data: $e');
    }
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Admin';
    });
  }

  void _sortAttendanceData() {
    setState(() {
      _attendanceData.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    });
  }

  void _addLogMessage(Map<String, dynamic> data) {
    final dateTime = (data['timestamp'] as Timestamp).toDate();
    final date = DateFormat('EEEE, d MMMM', 'id_ID').format(dateTime); // Format sesuai permintaan
    final name = data['name'];
    final status = data['status'];
    final shift = data['shift'];
    final alasan = data['alasan'] ?? '';
    final logMessage = '$date - $name: $status $shift ${alasan.isNotEmpty ? 'Alasan: $alasan' : ''}';

    setState(() {
      _logMessages.add(logMessage);
    });
  }

  Future<void> _deleteAllData() async {
    final confirmation = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Konfirmasi Hapus Data'),
        content: Text('Apakah Anda yakin ingin menghapus semua data kehadiran?'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('Batal'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            child: Text('Hapus'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (var data in _attendanceData) {
        final docRef = FirebaseFirestore.instance.collection('attendance').doc(data['id']);
        batch.delete(docRef);
      }

      await batch.commit();
      setState(() {
        _attendanceData.clear();
        _logMessages.clear();
      });
    }
  }

  Future<String> _getLocationDetails(String coordinates) async {
    try {
      final latLng = coordinates.split(',');
      if (latLng.length != 2) return 'Invalid coordinates';

      final lat = latLng[0];
      final lon = latLng[1];
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['address'] != null) {
          final address = data['address'];
          String road = address['road'] ?? '';
          String houseNumber = address['house_number'] ?? '';
          String suburb = address['suburb'] ?? '';
          String city = address['city'] ?? address['town'] ?? address['village'] ?? '';
          String state = address['state'] ?? '';
          String postcode = address['postcode'] ?? '';
          String country = address['country'] ?? '';

          String fullAddress = '$road $houseNumber, $suburb, $city, $state, $postcode, $country';
          return fullAddress.trim().replaceAll(RegExp(r'\s+'), ' ');
        }
      }
      return 'Location details not available';
    } catch (e) {
      return 'Invalid coordinates';
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

  Future<void> _goBackToUserAccount() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => UserHomeScreen(camera: camera!)),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
  }

  String _getShiftLabel(String shift) {
    if (shift == 'Pagi') {
      return 'Shift Pagi (08:00 - 15:59)';
    } else if (shift == 'Siang') {
      return 'Shift Siang (16:00 - 23:30)';
    }
    return shift;
  }

  Future<void> _openMap(String coordinates) async {
    final latLng = coordinates.split(',');
    if (latLng.length != 2) return;

    final lat = latLng[0];
    final lon = latLng[1];
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';

    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }

  Future<void> _showLoadingDialog() async {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Memuat Data'),
          content: Center(
            child: CupertinoActivityIndicator(),
          ),
        );
      },
    );
  }

  Future<void> _showAttendanceDetails(Map<String, dynamic> data) async {
    await _showLoadingDialog(); // Show loading dialog
    String locationDetails = await _getLocationDetails(data['location']);
    Navigator.pop(context); // Close loading dialog before showing details

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Detail Kehadiran'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tanggal: ${_formatDate(data['date'])}'),
                Text('Waktu: ${data['time']}'),
                Text('Nama: ${data['name']}'),
                Text('Status: ${data['status']}', style: TextStyle(fontWeight: FontWeight.bold)),
                if (data['status'] != 'Off Shift')
                  Text('Shift: ${_getShiftLabel(data['shift'])}'),
                if (data['alasan'] != null && data['alasan'].isNotEmpty)
                  Text('Alasan: ${data['alasan']}'),
                GestureDetector(
                  onTap: () => _openMap(data['location']),
                  child: Text('Lokasi: $locationDetails', style: TextStyle(color: Colors.blue)),
                ),
                GestureDetector(
                  onTap: () => _openMap(data['location']),
                  child: Text('Koordinat: ${data['location']}', style: TextStyle(color: Colors.blue)),
                ),
                if (data['imageURL'] != null && data['imageURL'].isNotEmpty)
                  Image.network(data['imageURL']),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Tutup'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLogDetails(int index) {
    final data = _attendanceData[index];
    _showAttendanceDetails(data);
  }

  Widget _buildLogList() {
    return Expanded(
      child: Container(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _logMessages.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.grey[900],
                    child: ListTile(
                      onTap: () => _showLogDetails(index),
                      title: Text(
                        _logMessages[index],
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _logMessages.clear();
                  });
                },
                icon: Icon(Icons.delete, color: Colors.white),
                label: Text('Clear Logs'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_greetingMessage(), style: const TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF543310),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAttendanceData,
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Column(
        children: [
          Expanded(child: _buildEventList()),
          _buildLogList(),
        ],
      ),
    );
  }

  String _greetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Selamat Pagi';
    } else if (hour < 17) {
      return 'Selamat Siang';
    } else {
      return 'Selamat Malam';
    }
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text("Admin Management Storiamo Perintis"),
            accountEmail: Text(_username),
            currentAccountPicture: CircleAvatar(
              child: Icon(Icons.account_circle, color: Colors.white),
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
            leading: Icon(Icons.account_circle),
            title: Text('Kembali ke Akun ($_username)'),
            onTap: _goBackToUserAccount,
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Hapus Data Absen'),
            onTap: _deleteAllData,
            textColor: Colors.red, // Set text color to red
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final users = _attendanceData.map((data) => data['name']).toSet().toList();
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final userAttendance = _attendanceData.where((data) => data['name'] == user).toList();

        return ExpansionTile(
          title: Text(user, style: TextStyle(fontWeight: FontWeight.bold)),
          children: [
            _buildStatusTile('Hadir', userAttendance),
            _buildStatusTile('Izin', userAttendance),
            _buildStatusTile('Sakit', userAttendance),
            _buildStatusTile('Terlambat', userAttendance),
            _buildStatusTile('Off Shift', userAttendance),
          ],
        );
      },
    );
  }

  Widget _buildStatusTile(String status, List<Map<String, dynamic>> userAttendance) {
    final attendanceByStatus = userAttendance.where((data) => data['status'] == status).toList();
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$status'),
          Text('${attendanceByStatus.length}'),
        ],
      ),
      onTap: () {
        if (attendanceByStatus.isNotEmpty) {
          _showAttendanceDetails(attendanceByStatus.first);
        }
      },
    );
  }
}
