import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/models/device_item.dart';

class DiscoveryNotifier extends Notifier<List<DeviceItem>> {
  final _p2pConnection = FlutterP2pConnection();
  bool _isScanning = false;

  @override
  List<DeviceItem> build() => [];

  Future<void> startScanning() async {
    if (_isScanning) return;

    await _p2pConnection.initialize();
    await _p2pConnection.register();

    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();

    _p2pConnection.streamPeers().listen((peers) {
      state = peers.map((peer) {
        final String deviceName = peer.deviceName;

        return DeviceItem(
          id: peer.deviceAddress,
          name: deviceName,
          ipAddress: peer.deviceAddress,
        );
      }).toList();
    });

    _isScanning = await _p2pConnection.discover() ?? false;
    print('P2P Scanning started: $_isScanning');
  }

  void stopScanning() {
    _p2pConnection.unregister();
    _isScanning = false;
    state = [];
  }

  Future<bool> connectToDevice(String deviceAddress) async {
    return await _p2pConnection.connect(deviceAddress) ?? false;
  }
}

final discoveryProvider = NotifierProvider<DiscoveryNotifier, List<DeviceItem>>(
  () {
    return DiscoveryNotifier();
  },
);
