import 'package:datatransfer/features/transfer/providers/discovery_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'transfer_progress_screen.dart';

class RadarScanScreen extends ConsumerStatefulWidget {
  const RadarScanScreen({super.key});

  @override
  ConsumerState<RadarScanScreen> createState() => _RadarScanScreenState();
}

class _RadarScanScreenState extends ConsumerState<RadarScanScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discoveredDevices = ref.watch(discoveryProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scanning for Receivers'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
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

                  // Found Device Mock
                  if (discoveredDevices.isNotEmpty)
                    Positioned(
                      top: 40.h,
                      right: 60.w,
                      child: GestureDetector(
                        onTap: () async {
                          final device = discoveredDevices.first;
                          print('Attempting to connect to ${device.name}...');

                          // 1. Tell P2P hardware to build bridge
                          bool connected = await ref
                              .read(discoveryProvider.notifier)
                              .connectToDevice(device.id);

                          if (connected && context.mounted) {
                            print('SUCCESSFULLY CONNECTED!');
                            // TODO: Add transferring active files here in Riverpod
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TransferProgressScreen(),
                              ),
                            );
                          } else {
                            print('Failed to connect.');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to connect to device.'),
                                ),
                              );
                            }
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 50.w,
                              height: 50.w,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_android,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 5.h),
                            Text(
                              'John\'s Phone',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 50.h),
            Text(
              discoveredDevices.isNotEmpty
                  ? 'Tap a device to send'
                  : 'Searching for nearby devices...',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
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
}
