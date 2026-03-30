import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _isBroadcasting = false;
  final _host = FlutterP2pConnection();

  @override
  void initState() {
    super.initState();
    _startBroadcasting();
  }

  Future<void> checkAndRequestPermissions() async {
    if (!await Permission.storage.isGranted) await Permission.storage.request();
    if (!await Permission.location.isGranted) await Permission.location.request();
    if (!await Permission.nearbyWifiDevices.isGranted) await Permission.nearbyWifiDevices.request();
    if (!await Permission.bluetooth.isGranted) await Permission.bluetooth.request();
  }

  Future<void> checkAndEnableServices() async {
    if (await _host.checkWifiEnabled() != true) await _host.enableWifiServices();
    if (await _host.checkLocationEnabled() != true) await _host.enableLocationServices();
  }

  Future<void> _startBroadcasting() async {
    await _host.initialize();
    await _host.register();
    await checkAndRequestPermissions();
    await checkAndEnableServices();

    // Create group
    bool created = await _host.createGroup() ?? false;

    if (created && mounted) {
      setState(() {
        _isBroadcasting = true;
      });
      print('Group Created & Advertised! Waiting for Sender to connect...');
    }
  }

  @override
  void dispose() {
    _host.removeGroup();
    _host.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isBroadcasting) ...[
              const CircularProgressIndicator(),
              SizedBox(height: 20.h),
              Text(
                'Waiting for sender to connect...',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10.h),
              Text(
                'Make sure both devices are on the same WiFi.',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey),
              ),
            ] else
              const CircularProgressIndicator(), // Loading while setting up NSD
          ],
        ),
      ),
    );
  }
}
