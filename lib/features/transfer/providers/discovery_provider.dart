import 'dart:async';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../core/models/device_item.dart';

enum HotspotStatus { idle, initializing, active, failed }

class DiscoveryState {
  final List<DeviceItem> devices;
  final HotspotStatus hotspotStatus;
  final bool isScanning;
  final bool isConnecting;
  final String? errorMessage;
  final WifiP2PInfo? connectionInfo;

  DiscoveryState({
    required this.devices,
    this.hotspotStatus = HotspotStatus.idle,
    this.isScanning = false,
    this.isConnecting = false,
    this.errorMessage,
    this.connectionInfo,
  });

  DiscoveryState copyWith({
    List<DeviceItem>? devices,
    HotspotStatus? hotspotStatus,
    bool? isScanning,
    bool? isConnecting,
    String? errorMessage,
    WifiP2PInfo? connectionInfo,
  }) {
    return DiscoveryState(
      devices: devices ?? this.devices,
      hotspotStatus: hotspotStatus ?? this.hotspotStatus,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: errorMessage ?? this.errorMessage,
      connectionInfo: connectionInfo ?? this.connectionInfo,
    );
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(DiscoveryState(devices: [])) {
    _init();
  }

  final _p2pConnection = FlutterP2pConnection();
  StreamSubscription? _infoSubscription;
  StreamSubscription? _peersSubscription;

  void _init() {
    _p2pConnection.initialize();
    _p2pConnection.register();

    // Listen to connection info stream (case sensitive in 1.0.3)
    _infoSubscription = _p2pConnection.streamWifiP2PInfo().listen((info) {
      print('WiFi P2P Connection Info Changed: ${info.isConnected}');
      state = state.copyWith(connectionInfo: info);
    });
  }

  @override
  void dispose() {
    print('Disposing DiscoveryNotifier...');
    _infoSubscription?.cancel();
    _peersSubscription?.cancel();
    _p2pConnection.unregister();
    super.dispose();
  }

  Future<void> _checkAndEnableServices() async {
    print('Checking WiFi and Location services...');
    bool wifiEnabled = await _p2pConnection.checkWifiEnabled() ?? false;
    if (!wifiEnabled) {
      print('WiFi is OFF, enabling...');
      await _p2pConnection.enableWifiServices();
    }
    
    bool locationEnabled = await _p2pConnection.checkLocationEnabled() ?? false;
    if (!locationEnabled) {
      print('Location is OFF, enabling...');
      await _p2pConnection.enableLocationServices();
    }
  }

  Future<void> startScanning() async {
    if (state.isScanning) return;

    await _p2pConnection.initialize();
    await _p2pConnection.register();

    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();

    await _peersSubscription?.cancel();
    _peersSubscription = _p2pConnection.streamPeers().listen((peers) {
      state = state.copyWith(
        devices: peers.map((peer) {
          final String deviceName = peer.deviceName;

          return DeviceItem(
            id: peer.deviceAddress,
            name: deviceName,
            ipAddress: peer.deviceAddress,
          );
        }).toList(),
      );
    });

    bool isScanning = await _p2pConnection.discover() ?? false;
    state = state.copyWith(isScanning: isScanning);
    print('P2P Scanning started: $isScanning');
  }

  void stopScanning() {
    _peersSubscription?.cancel();
    _p2pConnection.unregister();
    state = DiscoveryState(devices: []);
  }

  Future<bool> startHotspotGroup() async {
    print('Checking if hotspot can be started...');
    state = state.copyWith(hotspotStatus: HotspotStatus.initializing);
    await _checkAndEnableServices();
    
    await _p2pConnection.initialize();
    await _p2pConnection.register();

    // Clear any existing group first
    try {
      await _p2pConnection.removeGroup();
      print('Existing groups cleared.');
    } catch (e) {
      print('None or error removing group: $e');
    }

    final locStatus = await Permission.location.request();
    final wifiStatus = await Permission.nearbyWifiDevices.request();
    print('Permissions - Location: $locStatus, Nearby WiFi: $wifiStatus');

    if (locStatus != PermissionStatus.granted || (await _isAndroid13Plus() && wifiStatus != PermissionStatus.granted)) {
       print('Permissions not fully granted.');
       state = state.copyWith(hotspotStatus: HotspotStatus.failed);
       return false;
    }

    try {
      bool created = await _p2pConnection.createGroup() ?? false;
      print('createGroup() result: $created');
      
      if (created) {
        // Calling discover() while being GO can help other devices find us
        await _p2pConnection.discover();
      }
      
      state = state.copyWith(
        hotspotStatus: created ? HotspotStatus.active : HotspotStatus.failed,
      );
      return created;
    } catch (e) {
      print('Error creating group: $e');
      state = state.copyWith(hotspotStatus: HotspotStatus.failed);
      return false;
    }
  }

  Future<bool> _isAndroid13Plus() async {
    if (!Platform.isAndroid) return false;
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33;
  }

  void discoverPeers() async {
    print('Starting Discovery...');
    state = state.copyWith(isScanning: true);
    await _checkAndEnableServices();
    print('Services enabled/checked.');

    await _p2pConnection.initialize();
    print('P2P Initialized.');
    await _p2pConnection.register();
    print('P2P Registered.');

    try {
      await _p2pConnection.removeGroup();
      print('Discovery Init: Cleaned up any old P2P groups.');
    } catch (e) {
      print('No existing group to remove during discovery init.');
    }

    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();

    await _peersSubscription?.cancel();
    _peersSubscription = _p2pConnection.streamPeers().listen((peers) {
      print('Discovery result - Peers found: ${peers.length}');
      for (var p in peers) {
        print(' - Found peer: ${p.deviceName} (${p.deviceAddress})');
      }
      state = state.copyWith(
        devices: peers.map((peer) {
          return DeviceItem(
            id: peer.deviceAddress,
            name: peer.deviceName,
            ipAddress: peer.deviceAddress,
          );
        }).toList(),
      );
    });

    try {
      bool isScanning = await _p2pConnection.discover() ?? false;
      state = state.copyWith(isScanning: isScanning);
      print('discover() result: $isScanning');
    } catch (e) {
      print('Error starting discovery: $e');
      state = state.copyWith(isScanning: false);
    }
  }

  Future<bool> connectToPeer(String deviceAddress) async {
    print('Initiating connection to $deviceAddress...');
    state = state.copyWith(isConnecting: true, errorMessage: null);
    try {
      bool success = await _p2pConnection.connect(deviceAddress) ?? false;
      print('Connect request result: $success');
      if (!success) {
        state = state.copyWith(isConnecting: false, errorMessage: 'Connection request failed');
      }
      return success;
    } catch (e) {
      print('Error connecting to peer: $e');
      state = state.copyWith(isConnecting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final discoveryProvider = StateNotifierProvider.autoDispose<DiscoveryNotifier, DiscoveryState>(
  (ref) {
    return DiscoveryNotifier();
  },
);
