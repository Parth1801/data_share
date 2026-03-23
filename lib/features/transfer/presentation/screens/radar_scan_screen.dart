import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'transfer_progress_screen.dart';

class RadarScanScreen extends StatefulWidget {
  const RadarScanScreen({super.key});

  @override
  State<RadarScanScreen> createState() => _RadarScanScreenState();
}

class _RadarScanScreenState extends State<RadarScanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _foundDevice = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Mock finding a device after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _foundDevice = true;
        });
      }
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
                        )
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  
                  // Found Device Mock
                  if (_foundDevice)
                    Positioned(
                      top: 40.h,
                      right: 60.w,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const TransferProgressScreen()),
                          );
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
                              child: const Icon(Icons.phone_android, color: Colors.white),
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
              _foundDevice ? 'Tap a device to send' : 'Searching for nearby devices...',
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
