import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:flutter_p2p_connection/flutter_p2p_connection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:datatransfer/features/transfer/providers/transfer_provider.dart';
import '../../providers/discovery_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transfer_progress_screen.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;
  Timer? _protocolTimer;
  // We use discoveryProvider instead of a local _host instance

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start Hotspot to receive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).startHotspotGroup();
    });
  }

  Future<void> checkAndRequestPermissions() async {
    if (!await Permission.storage.isGranted) await Permission.storage.request();
    if (!await Permission.location.isGranted)
      await Permission.location.request();
    if (!await Permission.nearbyWifiDevices.isGranted)
      await Permission.nearbyWifiDevices.request();
    if (!await Permission.bluetooth.isGranted)
      await Permission.bluetooth.request();
  }

  Future<void> checkAndEnableServices() async {
    final p2p = FlutterP2pConnection();
    if (await p2p.checkWifiEnabled() != true) await p2p.enableWifiServices();
    if (await p2p.checkLocationEnabled() != true)
      await p2p.enableLocationServices();
  }

  // Removed _startDiscovery as it is handled by the provider init or explicit calls

  @override
  void dispose() {
    _controller.dispose();
    _protocolTimer?.cancel();
    // Only stop scanning if we haven't navigated to transfer — stopping kills the P2P connection
    if (!_navigated) {
      // Use fullReset to ensure groups are cleared if user leaves early
      ref.read(discoveryProvider.notifier).fullReset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);

    // Handshake listener moved to handshakeRole below

    ref.listen(discoveryProvider.select((s) => s.handshakeRole), (
      previous,
      next,
    ) {
      if (mounted && next == HandshakeRole.receiving && !_navigated) {
        _navigated = true;

        final info = ref.read(discoveryProvider).connectionInfo;
        final goAddress = info?.groupOwnerAddress ?? '192.168.49.1';
        final isGO = info?.isGroupOwner ?? true;

        ref.read(transferProvider.notifier).startReceiving(goAddress, isGO);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TransferProgressScreen(),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 50.h),
                Text(
                  discoveryState.hotspotStatus == HotspotStatus.active
                      ? 'Radar Active'
                      : (discoveryState.hotspotStatus ==
                                HotspotStatus.initializing
                            ? 'Starting Radar...'
                            : (discoveryState.hotspotStatus ==
                                      HotspotStatus.failed
                                  ? 'Radar Failed'
                                  : 'Radar Offline')),
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: discoveryState.hotspotStatus == HotspotStatus.active
                        ? Colors.green
                        : (discoveryState.hotspotStatus == HotspotStatus.failed
                              ? Colors.red
                              : Colors.orange),
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (discoveryState.hotspotStatus == HotspotStatus.active
                                ? Colors.green
                                : Colors.orange)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color:
                          (discoveryState.hotspotStatus == HotspotStatus.active
                                  ? Colors.green
                                  : Colors.orange)
                              .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    discoveryState.hotspotStatus == HotspotStatus.active
                        ? 'Ready for connection (Invisible to System)'
                        : (discoveryState.hotspotStatus ==
                                  HotspotStatus.initializing
                              ? 'Configuring P2P Network...'
                              : 'Tap to try again'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color:
                          discoveryState.hotspotStatus == HotspotStatus.active
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (discoveryState.hotspotStatus == HotspotStatus.failed ||
                    discoveryState.hotspotStatus == HotspotStatus.idle)
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(discoveryProvider.notifier)
                        .startHotspotGroup(),
                    icon: Icon(Icons.radar, color: Colors.white),
                    label: Text(
                      discoveryState.hotspotStatus == HotspotStatus.failed
                          ? 'Retry Radar'
                          : 'Start Radar',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          discoveryState.hotspotStatus == HotspotStatus.failed
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                    ),
                  ),
                SizedBox(height: 20.h),

                // Radar Section
                SizedBox(
                  height: 350.h,
                  width: 350.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildRadarCircle(300.w, 0.1),
                      _buildRadarCircle(200.w, 0.2),
                      _buildRadarCircle(100.w, 0.3),

                      RotationTransition(
                        turns: _controller,
                        child: Container(
                          width: 300.w,
                          height: 300.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                Colors.transparent,
                                Theme.of(context).primaryColor.withOpacity(0.1),
                                Theme.of(context).primaryColor.withOpacity(0.5),
                              ],
                              stops: const [0.5, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Center Icon (Receiver)
                      Container(
                        width: 60.w,
                        height: 60.w,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // Connected Senders on Radar
                      if (discoveryState.connectionInfo != null)
                        ...discoveryState.connectionInfo!.clients
                            .asMap()
                            .entries
                            .map((entry) {
                              final int index = entry.key;
                              final client = entry.value;
                              final double radius = (index % 2 == 0)
                                  ? 100.w
                                  : 130.w;
                              final double angle =
                                  (index * 72) * (math.pi / 180);

                              return Positioned(
                                left: 175.w + radius * math.cos(angle) - 25.w,
                                top: 175.w + radius * math.sin(angle) - 25.w,
                                child: _buildDeviceIcon(
                                  client.deviceName,
                                  Colors.green,
                                ),
                              );
                            }),
                    ],
                  ),
                ),

                SizedBox(height: 30.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _buildDeviceList(),
                ),
                SizedBox(height: 50.h),
              ],
            ),
          ),
          if (discoveryState.isConnecting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20.h),
                    const Text(
                      'Connecting to Sender...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    final discoveryState = ref.watch(discoveryProvider);

    if (discoveryState.connectionInfo?.clients.isEmpty ?? true) {
      return Column(
        children: [
          const CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 10.h),
          const Text(
            'Waiting for someone to connect...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      );
    }

    return Column(
      children: discoveryState.connectionInfo!.clients.map((client) {
        return Card(
          margin: EdgeInsets.only(bottom: 10.h),
          child: ListTile(
            leading: const Icon(Icons.person, color: Colors.green),
            title: Text(client.deviceName),
            subtitle: Text(client.deviceAddress),
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRadarCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(opacity),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildDeviceIcon(String name, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 50.w,
          height: 50.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.phone_android, color: Colors.white, size: 24),
        ),
        SizedBox(height: 4.h),
        Text(
          name.split(' ').first,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
