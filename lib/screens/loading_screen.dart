import 'package:flutter/material.dart';

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
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _dotController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.progress * 100).toInt().clamp(0, 100);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo mark
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        color: const Color(0xFF3B82F6),
                        child: const Icon(
                          Icons.precision_manufacturing,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MRO ENGINE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEAEAEA),
                              letterSpacing: 3,
                              height: 1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'PARTS SEARCH SYSTEM',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF555555),
                              letterSpacing: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Progress percentage — large display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$pct',
                        style: const TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFEAEAEA),
                          height: 1,
                          letterSpacing: -2,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          '%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF555555),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress bar
                  Container(
                    height: 2,
                    color: const Color(0xFF1A1A1A),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        widthFactor: widget.progress.clamp(0.0, 1.0),
                        child: Container(color: const Color(0xFF3B82F6)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status row
                  Row(
                    children: [
                      // Animated dots
                      AnimatedBuilder(
                        animation: _dotController,
                        builder: (context, _) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(3, (i) {
                              final phase = (_dotController.value * 3 - i).clamp(0.0, 1.0);
                              final opacity = (phase < 0.5)
                                  ? phase * 2
                                  : 2 - phase * 2;
                              return Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.only(right: 3),
                                color: Color.lerp(
                                  const Color(0xFF222222),
                                  const Color(0xFF3B82F6),
                                  opacity.clamp(0.0, 1.0),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Bottom accent line
                  Container(
                    height: 1,
                    color: const Color(0xFF1A1A1A),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Initializing database and search indices...',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
