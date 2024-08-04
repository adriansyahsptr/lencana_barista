import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'user_home.dart';

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _requestPermissions();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (status.isDenied) {
      if (await Permission.camera.request().isGranted) {
        print('Camera permission granted');
      }
    }
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      if (await Permission.storage.request().isGranted) {
        print('Storage permission granted');
      }
    }
    if (status.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String> _getImagePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';
    return '${directory.path}/$fileName';
  }

  Future<String> _uploadImageToFirebase(String imagePath) async {
    final file = File(imagePath);
    final storageReference = FirebaseStorage.instance
        .ref()
        .child('attendance_images/${DateTime.now().millisecondsSinceEpoch}.png');
    final uploadTask = storageReference.putFile(file);
    final taskSnapshot = await uploadTask.whenComplete(() => {});
    final downloadURL = await taskSnapshot.ref.getDownloadURL();
    return downloadURL;
  }

  Future<void> _saveAttendanceData(String status, String imagePath, Position position, String? alasan) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'User';

    final imageUrl = await _uploadImageToFirebase(imagePath);

    final newAttendanceFirestore = {
      'name': username,
      'status': status,
      'shift': _getShift(),
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'time': DateFormat('HH:mm:ss').format(DateTime.now()),
      'location': '${position.latitude}, ${position.longitude}',
      'imageURL': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'alasan': alasan ?? '',
    };

    await FirebaseFirestore.instance.collection('attendance').add(newAttendanceFirestore);
  }

  String _getShift() {
    final currentTime = DateTime.now();
    if (currentTime.hour >= 6 && currentTime.hour < 16) {
      return 'Pagi';
    } else if (currentTime.hour >= 16 && currentTime.hour <= 23) {
      return 'Siang';
    }
    return 'Tidak Diketahui';
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
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _showLoadingDialog() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoActivityIndicator(),
              SizedBox(height: 16),
              Text('Memuat kehadiran...'),
            ],
          ),
        );
      },
    );
  }

  void _hideLoadingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Future<String?> _showInputDialog(String title, String placeholder) async {
    String input = '';
    return showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: CupertinoTextField(
            onChanged: (value) {
              input = value;
            },
            placeholder: placeholder,
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Batal', style: TextStyle(color: CupertinoColors.destructiveRed)),
              onPressed: () {
                Navigator.of(context).pop(null);
              },
            ),
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(input);
              },
            ),
          ],
        );
      },
    );
  }

  void _showAttendanceOptions(BuildContext context, String imagePath, Position position) {
    final currentTime = DateTime.now();
    final isMorningShift = currentTime.hour >= 6 && currentTime.hour < 8;
    final isAfternoonShift = currentTime.hour >= 15 && currentTime.hour < 16;
    final isLateMorning = currentTime.hour >= 8 && currentTime.hour < 16;
    final isLateAfternoon = currentTime.hour >= 16 && currentTime.hour < 23;

    if (currentTime.hour >= 23 || currentTime.hour < 6) {
      _showErrorDialog('Absen tidak tersedia pada waktu ini');
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Konfirmasi Kehadiran'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.file(File(imagePath)),
                SizedBox(height: 16),
                Text('Pilih status kehadiran:'),
                if (isMorningShift || isAfternoonShift)
                  CupertinoDialogAction(
                    child: Text('Hadir'),
                    onPressed: () {
                      Navigator.pop(context, 'Hadir');
                    },
                  ),
                CupertinoDialogAction(
                  child: Text('Izin'),
                  onPressed: () async {
                    String? alasan = await _showInputDialog('Alasan Izin', 'Masukkan alasan');
                    if (alasan != null) {
                      Navigator.pop(context, 'Izin');
                      _showLoadingDialog();
                      await _saveAttendanceData('Izin', imagePath, position, alasan);
                      _hideLoadingDialog();
                      _showCompletionDialog();
                    }
                  },
                ),
                CupertinoDialogAction(
                  child: Text('Sakit'),
                  onPressed: () async {
                    String? alasan = await _showInputDialog('Alasan Sakit', 'Masukkan alasan');
                    if (alasan != null) {
                      Navigator.pop(context, 'Sakit');
                      _showLoadingDialog();
                      await _saveAttendanceData('Sakit', imagePath, position, alasan);
                      _hideLoadingDialog();
                      _showCompletionDialog();
                    }
                  },
                ),
                if (isLateMorning || isLateAfternoon || isMorningShift || isAfternoonShift)
                  CupertinoDialogAction(
                    child: Text('Terlambat'),
                    onPressed: () async {
                      String? alasan = await _showInputDialog('Alasan Terlambat', 'Masukkan alasan terlambat');
                      if (alasan != null) {
                        Navigator.pop(context, 'Terlambat');
                        _showLoadingDialog();
                        await _saveAttendanceData('Terlambat', imagePath, position, alasan);
                        _hideLoadingDialog();
                        _showCompletionDialog();
                      }
                    },
                  ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: Text('Retake', style: TextStyle(color: CupertinoColors.destructiveRed)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCompletionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Selesai Mengirim Data'),
          content: Text('Data kehadiran telah berhasil dikirim.'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  CupertinoPageRoute(builder: (context) => UserHomeScreen(camera: widget.camera)),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
    _controller.setFlashMode(
      _isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  void _switchCamera() async {
    final cameras = await availableCameras();
    final newCamera = _isRearCameraSelected
        ? cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front)
        : cameras.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back);
    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _controller = CameraController(newCamera, ResolutionPreset.high);
      _initializeControllerFuture = _controller.initialize();
    });
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Absen Karyawan', style: TextStyle(color: CupertinoColors.white)),
        backgroundColor: Color(0xFF543310),
        leading: CupertinoNavigationBarBackButton(color: CupertinoColors.white),
      ),
      child: Stack(
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CameraPreview(_controller);
              } else {
                return Center(child: CupertinoActivityIndicator());
              }
            },
          ),
          if (_isLoading)
            Center(
              child: Container(
                color: CupertinoColors.black.withOpacity(0.5),
                child: CupertinoActivityIndicator(),
              ),
            ),
          Positioned(
            bottom: 16.0,
            left: 16.0,
            child: CupertinoButton(
              child: Icon(
                _isFlashOn ? CupertinoIcons.lightbulb_fill : CupertinoIcons.lightbulb,
                color: CupertinoColors.white,
              ),
              color: CupertinoColors.systemGrey,
              onPressed: _toggleFlash,
            ),
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: CupertinoButton(
              child: Icon(
                CupertinoIcons.switch_camera,
                color: CupertinoColors.white,
              ),
              color: CupertinoColors.systemGrey,
              onPressed: _switchCamera,
            ),
          ),
          Positioned(
            bottom: 16.0,
            left: MediaQuery.of(context).size.width / 2 - 28,
            child: CupertinoButton(
              child: Icon(
                CupertinoIcons.camera,
                color: CupertinoColors.white,
              ),
              color: CupertinoColors.systemGrey,
              onPressed: () async {
                final currentTime = DateTime.now();
                if (currentTime.hour >= 23 || currentTime.hour < 6) {
                  _showErrorDialog('Absen tidak tersedia pada waktu ini, tersedia di jam 06.00 pagi');
                  return;
                }
                try {
                  await _initializeControllerFuture;
                  final image = await _controller.takePicture();
                  final imagePath = await _getImagePath();
                  await image.saveTo(imagePath);
                  final position = await _getCurrentPosition();
                  setState(() {
                    _isLoading = true;
                  });
                  _showLoadingDialog();
                  _showAttendanceOptions(context, imagePath, position);
                  setState(() {
                    _isLoading = false;
                  });
                } catch (e) {
                  print(e);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
