import 'package:flutter/material.dart';
import 'dart:math' as math;

class GmodLoadingScreen extends StatefulWidget {
  final double progress;
  final String status;

  const GmodLoadingScreen({
    super.key,
    required this.progress,
    required this.status,
  });

  @override
  State<GmodLoadingScreen> createState() => _GmodLoadingScreenState();
}

class _GmodLoadingScreenState extends State<GmodLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
              const Text(
                'MRO ENGINE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFCC4444),
                  letterSpacing: 4,
                  shadows: [Shadow(color: Color(0x80CC4444), blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 60),

              // Rotating loader icon
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFCC4444),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: CustomPaint(painter: _LoadingIconPainter()),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Status text
              Text(
                widget.status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFAAAAAA),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 30),

              // Progress bar container
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF404040), width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      // Progress fill
                      FractionallySizedBox(
                        widthFactor: widget.progress.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFCC4444),
                                const Color(0xFFDD5555),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x40CC4444),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Percentage text
                      Center(
                        child: Text(
                          '${(widget.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: widget.progress > 0.5
                                ? const Color(0xFF1A1A1A)
                                : const Color(0xFFAAAAAA),
                            letterSpacing: 2,
                            shadows: widget.progress > 0.5
                                ? [
                                    const Shadow(
                                      color: Color(0x80000000),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Additional info text
              Text(
                'Please wait while we load the MRO database',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCC4444)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw segments (like a gear)
    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final x = center.dx + radius * 0.6 * math.cos(angle);
      final y = center.dy + radius * 0.6 * math.sin(angle);
      canvas.drawCircle(Offset(x, y), radius * 0.15, paint);
    }

    // Draw center circle
    canvas.drawCircle(center, radius * 0.25, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
