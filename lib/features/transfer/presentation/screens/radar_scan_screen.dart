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
  bool _protocolStarted = false;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discoveryState = ref.watch(discoveryProvider);
    final hotspotStatus = discoveryState.hotspotStatus;
    final isConnected = discoveryState.connectionInfo?.isConnected ?? false;

    // Listen for discovery status
    ref.listen(discoveryProvider.select((s) => s.devices), (previous, next) {
      if (next.isNotEmpty && (previous?.isEmpty ?? true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Found ${next.length} potential receivers!')),
        );
      }
    });

    // Listen for connection (Sender side now acts as Client)
    ref.listen(discoveryProvider.select((s) => s.connectionInfo), (previous, next) {
      if (next?.isConnected == true && next?.isGroupOwner == false && !_protocolStarted) {
        _protocolStarted = true;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to receiver! Syncing...')),
          );
          
          final transferNotifier = ref.read(transferProvider.notifier);
          final selectedFiles = ref.read(selectedFilesProvider);
          
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              // As Client, the GO address is the receiver's IP (usually 192.168.49.1)
              final targetAddress = next!.groupOwnerAddress ?? "192.168.49.1";
              transferNotifier.startSending(selectedFiles, targetAddress, next.isGroupOwner);
              
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const TransferProgressScreen()),
              );
            }
          });
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
                            onTap: () => ref.read(discoveryProvider.notifier).connectToPeer(device.id),
                            child: _buildDeviceIcon(device.name, theme.primaryColor),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(height: 30.h),
                if (discoveryState.connectionInfo?.clients.isNotEmpty ?? false) ...[
                   Text(
                    'Connected Devices:',
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: theme.primaryColor),
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    constraints: BoxConstraints(maxHeight: 100.h),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: discoveryState.connectionInfo!.clients.length,
                      itemBuilder: (context, index) {
                        final client = discoveryState.connectionInfo!.clients[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.phone_android),
                          title: Text(client.deviceName),
                          subtitle: Text(client.deviceAddress),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                ],
                Text(
                  'Looking for receivers...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                if (isConnected) ...[
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      final selectedFiles = ref.read(selectedFilesProvider);
                      final goAddress = discoveryState.connectionInfo?.groupOwnerAddress ?? "192.168.49.1";
                      final isGO = discoveryState.connectionInfo?.isGroupOwner ?? false;
                      ref.read(transferProvider.notifier).startSending(selectedFiles, goAddress, isGO);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const TransferProgressScreen()),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Start Transfer Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                if (hotspotStatus == HotspotStatus.failed || hotspotStatus == HotspotStatus.idle) ...[
                  SizedBox(height: 20.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(discoveryProvider.notifier).startHotspotGroup();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
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
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
