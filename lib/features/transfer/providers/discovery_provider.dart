import 'dart:async';
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/legacy.dart';
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
  DiscoveryNotifier() : super(DiscoveryState(devices: [])) {
    _init();
  }

  final _p2p = FlutterP2pConnection();
  StreamSubscription? _infoSubscription;
  StreamSubscription? _peersSubscription;
  Timer? _discoveryTimer;
  bool _isSender = false;
  bool _isReceiver = false;
  bool _handshakeTriggered = false;

  void _init() {
    _p2p.initialize();
    _p2p.register();

    _infoSubscription = _p2p.streamWifiP2PInfo().listen((info) {
      if (!mounted) return;
      state = state.copyWith(connectionInfo: info);

      if (info.groupFormed && !_handshakeTriggered) {
        _triggerHandshake(info);
      } else if (!info.groupFormed) {
        _handshakeTriggered = false;
      }
    });
  }

  void _triggerHandshake(WifiP2PInfo info) {
    if (_isSender) {
      _handshakeTriggered = true;
      // Clear the connecting overlay when group is formed
      state = state.copyWith(
        handshakeRole: HandshakeRole.sending,
        isConnecting: false,
      );
    } else if (_isReceiver) {
      if (info.isGroupOwner && info.clients.isEmpty) return;
      _handshakeTriggered = true;
      state = state.copyWith(
        handshakeRole: HandshakeRole.receiving,
        isConnecting: false,
      );
    }
  }

  @override
  void dispose() {
    _infoSubscription?.cancel();
    _peersSubscription?.cancel();
    _discoveryTimer?.cancel();
    _p2p.removeGroup();
    _p2p.unregister();
    super.dispose();
  }

  void stopScanning() {
    _peersSubscription?.cancel();
    _discoveryTimer?.cancel();
    // Do NOT unregister here — it kills the active P2P connection
    _isSender = false;
    _isReceiver = false;
    _handshakeTriggered = false;
    state = DiscoveryState(devices: []);
  }

  /// Full reset — call this when returning to home screen to start fresh
  Future<void> fullReset() async {
    _peersSubscription?.cancel();
    _discoveryTimer?.cancel();
    _isSender = false;
    _isReceiver = false;
    _handshakeTriggered = false;
    try {
      await _p2p.removeGroup();
    } catch (_) {}
    _p2p.unregister();
    await Future.delayed(const Duration(milliseconds: 300));
    await _p2p.initialize();
    await _p2p.register();
    state = DiscoveryState(devices: []);
  }

  Future<void> _ensureServicesAndPermissions() async {
    final wifiEnabled = await _p2p.checkWifiEnabled() ?? false;
    if (!wifiEnabled) await _p2p.enableWifiServices();

    final locationEnabled = await _p2p.checkLocationEnabled() ?? false;
    if (!locationEnabled) await _p2p.enableLocationServices();

    await Permission.location.request();
    await Permission.nearbyWifiDevices.request();
  }

  /// RECEIVER: creates a Wi-Fi Direct group (becomes Group Owner)
  Future<bool> startHotspotGroup() async {
    _isReceiver = true;
    _isSender = false;
    _handshakeTriggered = false;
    state = state.copyWith(
      hotspotStatus: HotspotStatus.initializing,
      handshakeRole: HandshakeRole.idle,
      errorMessage: null,
    );

    await _p2p.initialize();
    await _p2p.register();
    await _ensureServicesAndPermissions();

    try {
      if (state.connectionInfo?.groupFormed == true) {
        await _p2p.removeGroup();
        await Future.delayed(const Duration(milliseconds: 800));
      }
    } catch (_) {}

    try {
      final created = await _p2p.createGroup() ?? false;
      state = state.copyWith(
        hotspotStatus: created ? HotspotStatus.active : HotspotStatus.failed,
      );
      return created;
    } catch (e) {
      state = state.copyWith(
        hotspotStatus: HotspotStatus.failed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  /// SENDER: discovers peers and connects to one
  Future<void> discoverPeers() async {
    _isSender = true;
    _isReceiver = false;
    _handshakeTriggered = false;
    state = state.copyWith(
      isScanning: true,
      handshakeRole: HandshakeRole.idle,
      errorMessage: null,
      devices: [],
    );

    await _p2p.initialize();
    await _p2p.register();
    await _ensureServicesAndPermissions();

    try {
      await _p2p.removeGroup();
    } catch (_) {}

    _peersSubscription?.cancel();
    _peersSubscription = _p2p.streamPeers().listen((peers) {
      if (!mounted) return;
      state = state.copyWith(
        devices: peers
            .map(
              (p) => DeviceItem(
                id: p.deviceAddress,
                name: p.deviceName,
                ipAddress: p.deviceAddress,
              ),
            )
            .toList(),
      );
    });

    try {
      final scanning = await _p2p.discover() ?? false;
      state = state.copyWith(isScanning: scanning);
      if (scanning) {
        _discoveryTimer?.cancel();
        _discoveryTimer = Timer.periodic(const Duration(seconds: 10), (
          _,
        ) async {
          if (state.isScanning) await _p2p.discover();
        });
      }
    } catch (e) {
      state = state.copyWith(isScanning: false, errorMessage: e.toString());
    }
  }

  Future<bool> connectToPeer(String deviceAddress) async {
    state = state.copyWith(isConnecting: true, errorMessage: null);
    try {
      final success = await _p2p.connect(deviceAddress) ?? false;
      if (!success) {
        state = state.copyWith(
          isConnecting: false,
          errorMessage: 'Connection request failed',
        );
      }
      return success;
    } catch (e) {
      state = state.copyWith(isConnecting: false, errorMessage: e.toString());
      return false;
    }
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>(
      (ref) => DiscoveryNotifier(),
    );
