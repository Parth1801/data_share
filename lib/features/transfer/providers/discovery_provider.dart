import 'dart:async';
import 'dart:io';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'transfer_provider.dart';
import '../../../../core/models/device_item.dart';

enum HotspotStatus { idle, initializing, active, failed }
enum HandshakeRole { idle, sending, receiving }

class DiscoveryState {
  final List<DeviceItem> devices;
  final HotspotStatus hotspotStatus;
  final bool isScanning;
  final bool isConnecting;
  final String? errorMessage;
  final WifiP2PInfo? connectionInfo;
  final HandshakeRole handshakeRole;

  DiscoveryState({
    required this.devices,
    this.hotspotStatus = HotspotStatus.idle,
    this.isScanning = false,
    this.isConnecting = false,
    this.errorMessage,
    this.connectionInfo,
    this.handshakeRole = HandshakeRole.idle,
  });

  DiscoveryState copyWith({
    List<DeviceItem>? devices,
    HotspotStatus? hotspotStatus,
    bool? isScanning,
    bool? isConnecting,
    String? errorMessage,
    WifiP2PInfo? connectionInfo,
    HandshakeRole? handshakeRole,
  }) {
    return DiscoveryState(
      devices: devices ?? this.devices,
      hotspotStatus: hotspotStatus ?? this.hotspotStatus,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      errorMessage: errorMessage ?? this.errorMessage,
      connectionInfo: connectionInfo ?? this.connectionInfo,
      handshakeRole: handshakeRole ?? this.handshakeRole,
    );
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final dynamic _ref;
  DiscoveryNotifier(this._ref) : super(DiscoveryState(devices: [])) {
    _init();
  }

  final _p2pConnection = FlutterP2pConnection();
  StreamSubscription? _infoSubscription;
  StreamSubscription? _peersSubscription;
  Timer? _discoveryTimer;
  bool _isSenderSessionUpdate = false;
  bool _isReceiverSessionUpdate = false;
  bool _protocolTriggered = false;

  void _init() {
    _p2pConnection.initialize();
    _p2pConnection.register();

    // Listen to connection info stream (case sensitive in 1.0.3)
    _infoSubscription = _p2pConnection.streamWifiP2PInfo().listen((info) {
      if (!mounted) return;
      print('WiFi P2P Connection Info Changed: groupFormed=${info.groupFormed}');
      state = state.copyWith(connectionInfo: info);

      if (info.groupFormed && !_protocolTriggered) {
        _handleHandshake(info);
      } else if (!info.groupFormed) {
        _protocolTriggered = false;
      }
    });
  }

  void _handleHandshake(WifiP2PInfo info) {
    // Logic: Sender is the one who initiated Discovery (_isSenderSessionUpdate)
    // Receiver is the one who initiated Hotspot (_isReceiverSessionUpdate)
    // Who is GO (Group Owner) is secondary.
    
    if (_isSenderSessionUpdate && info.groupFormed) {
      print('DiscoveryNotifier: Detected Connection as Initiator (Sender). Triggering protocol...');
      _protocolTriggered = true;
      state = state.copyWith(handshakeRole: HandshakeRole.sending);
      
    } else if (_isReceiverSessionUpdate && info.groupFormed) {
      if (info.isGroupOwner && info.clients.isEmpty) {
        print('DiscoveryNotifier: GO group formed but no clients yet. Waiting...');
        return;
      }
      
      print('DiscoveryNotifier: Detected Connection as Host (Receiver). Triggering protocol...');
      _protocolTriggered = true;
      state = state.copyWith(handshakeRole: HandshakeRole.receiving);
    }
  }

  @override
  void dispose() {
    print('Disposing DiscoveryNotifier...');
    _infoSubscription?.cancel();
    _peersSubscription?.cancel();
    _discoveryTimer?.cancel();
    _p2pConnection.removeGroup(); // Fire and forget to clear group
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
      if (!mounted) return;
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
    
    if (isScanning) {
      _discoveryTimer?.cancel();
      _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (state.isScanning) {
          print('Periodic Discovery Refresh...');
          await _p2pConnection.discover();
        }
      });
    }
    print('P2P Scanning started: $isScanning');
  }

  void stopScanning() {
    print('Stopping Scanning and clearing P2P groups...');
    _peersSubscription?.cancel();
    _discoveryTimer?.cancel();
    _p2pConnection.unregister();
    _isSenderSessionUpdate = false;
    _isReceiverSessionUpdate = false;
    _protocolTriggered = false;
    state = DiscoveryState(devices: []);
  }

  Future<bool> startHotspotGroup() async {
    print('DiscoveryNotifier: Starting Hotspot Group (Receiver Role)');
    final currentTransfer = _ref.read(transferProvider);
    if (!currentTransfer.isTransferring && !currentTransfer.isCompleted) {
      _ref.read(transferProvider.notifier).reset();
    }
    _isReceiverSessionUpdate = true;
    _isSenderSessionUpdate = false;
    state = state.copyWith(hotspotStatus: HotspotStatus.initializing, handshakeRole: HandshakeRole.idle);
    await _checkAndEnableServices();
    
    await _p2pConnection.initialize();
    await _p2pConnection.register();

    // Clear any existing group first and wait a bit
    try {
      if (state.connectionInfo?.groupFormed == true) {
        print('DiscoveryNotifier: Group already exists. Removing...');
        await _p2pConnection.removeGroup();
        await Future.delayed(const Duration(milliseconds: 800)); 
      }
    } catch (e) {
      print('DiscoveryNotifier: Error clearing existing group: $e');
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
    print('DiscoveryNotifier: Starting Discovery (Sender Role)');
    final currentTransfer = _ref.read(transferProvider);
    if (!currentTransfer.isTransferring && !currentTransfer.isCompleted) {
      _ref.read(transferProvider.notifier).reset();
    }
    _isSenderSessionUpdate = true;
    _isReceiverSessionUpdate = false;
    state = state.copyWith(isScanning: true, handshakeRole: HandshakeRole.idle);
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
      if (!mounted) return;
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
      if (isScanning) {
        _discoveryTimer?.cancel();
        _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
          if (state.isScanning) {
            print('Periodic Peer Refresh...');
            await _p2pConnection.discover();
          }
        });
      }
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
        state = state.copyWith(
          isConnecting: false, 
          errorMessage: 'Connection request failed',
          devices: state.devices.where((d) => d.id != deviceAddress).toList(),
        );
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
    return DiscoveryNotifier(ref);
  },
);
