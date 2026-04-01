import 'dart:async';
import 'package:datatransfer/features/file_selection/providers/selected_files_provider.dart';
import 'package:datatransfer/features/transfer/providers/discovery_provider.dart';
import 'package:datatransfer/features/transfer/providers/transfer_provider.dart';
import 'package:datatransfer/features/transfer/presentation/screens/transfer_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;

class RadarScanScreen extends ConsumerStatefulWidget {
  const RadarScanScreen({super.key});

  @override
  ConsumerState<RadarScanScreen> createState() => _RadarScanScreenState();
}

class _RadarScanScreenState extends ConsumerState<RadarScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _navigated = false;
  Timer? _protocolTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Start scanning for receivers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(discoveryProvider.notifier).discoverPeers();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _protocolTimer?.cancel();
    if (!_navigated) {
      ref.read(discoveryProvider.notifier).stopScanning();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discoveryState = ref.watch(discoveryProvider);

    ref.listen(discoveryProvider.select((s) => s.handshakeRole), (
      previous,
      next,
    ) {
      if (mounted && next == HandshakeRole.sending && !_navigated) {
        _navigated = true;

        final selectedFiles = ref.read(selectedFilesProvider);
        final info = ref.read(discoveryProvider).connectionInfo;
        final goAddress = info?.groupOwnerAddress ?? '192.168.49.1';
        final isGO = info?.isGroupOwner ?? false;

        ref
            .read(transferProvider.notifier)
            .startSending(selectedFiles, goAddress, isGO);
        // Clear selection so next send starts fresh
        ref.read(selectedFilesProvider.notifier).clearFiles();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TransferProgressScreen(),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scanning for Receivers'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 350.h,
                  width: 350.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radar Circles
                      _buildRadarCircle(300.w, 0.1),
                      _buildRadarCircle(200.w, 0.2),
                      _buildRadarCircle(100.w, 0.3),

                      // Radar Sweep Animation
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
                                theme.primaryColor.withOpacity(0.1),
                                theme.primaryColor.withOpacity(0.5),
                              ],
                              stops: const [0.5, 0.8, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Center Icon (Sender)
                      Container(
                        width: 60.w,
                        height: 60.w,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

                      // Discovered Receivers on Radar
                      ...discoveryState.devices.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final device = entry.value;
                        final double radius = (index % 2 == 0) ? 100.w : 130.w;
                        final double angle = (index * 72) * (math.pi / 180);

                        return Positioned(
                          left: 175.w + radius * math.cos(angle) - 25.w,
                          top: 175.w + radius * math.sin(angle) - 25.w,
                          child: GestureDetector(
                            onTap: () => ref
                                .read(discoveryProvider.notifier)
                                .connectToPeer(device.id),
                            child: _buildDeviceIcon(
                              device.name,
                              theme.primaryColor,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),
                if (discoveryState.isConnecting) ...[
                  Text(
                    'Connecting...',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],
                Text(
                  discoveryState.devices.isEmpty
                      ? 'Looking for receivers...'
                      : 'Tap a device to connect',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
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
                      'Client Connecting...',
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
