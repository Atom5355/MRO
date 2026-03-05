import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ──────────
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF141414);
  static const Color _border = Color(0xFF222222);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _text = Color(0xFFEAEAEA);
  static const Color _textDim = Color(0xFF777777);

  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _isSignUp = false;
  bool _isLoading = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _isFormValid {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    if (!_emailRegex.hasMatch(email)) return false;
    if (pin.length != 5 || int.tryParse(pin) == null) return false;
    if (_isSignUp && _nameController.text.trim().isEmpty) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic));
    _fadeController.forward();

    // Rebuild on every keystroke so the button enables/disables in real time
    _emailController.addListener(() => setState(() {}));
    _pinController.addListener(() => setState(() {}));
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _pinController.dispose();
    _nameController.dispose();
    _emailFocus.dispose();
    _pinFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _error = null;
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final pin = _pinController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (pin.length != 5 || int.tryParse(pin) == null) {
      setState(() => _error = 'PIN must be exactly 5 digits');
      return;
    }
    if (_isSignUp && name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    String? err;
    if (_isSignUp) {
      err = await _auth.signUp(email: email, pin: pin, name: name);
    } else {
      err = await _auth.signIn(email: email, pin: pin);
    }

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _error = err;
        _isLoading = false;
      });
    } else {
      widget.onAuthenticated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _accent.withValues(alpha: 0.1),
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.precision_manufacturing,
                          color: _accent, size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text('MRO ENGINE',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _text,
                            letterSpacing: 2)),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isSignUp ? 'Create your account' : 'Sign in to continue',
                        key: ValueKey(_isSignUp),
                        style: const TextStyle(
                            fontSize: 13, color: _textDim),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Name field (sign up only)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _isSignUp
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildField(
                                controller: _nameController,
                                focusNode: _nameFocus,
                                label: 'Full Name',
                                hint: 'Your name',
                                icon: Icons.person_outline,
                                onSubmit: () => _emailFocus.requestFocus(),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // Email
                    _buildField(
                      controller: _emailController,
                      focusNode: _emailFocus,
                      label: 'Email',
                      hint: 'you@company.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onSubmit: () => _pinFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),

                    // PIN
                    _buildField(
                      controller: _pinController,
                      focusNode: _pinFocus,
                      label: '5-Digit PIN',
                      hint: '\u2022\u2022\u2022\u2022\u2022',
                      icon: Icons.lock_outline,
                      obscure: true,
                      maxLength: 5,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(5),
                      ],
                      onSubmit: (_) => _submit(),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              size: 15, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.redAccent)),
                          ),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: (!_isFormValid || _isLoading)
                              ? _accent.withValues(alpha: 0.3)
                              : _accent,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_isFormValid && !_isLoading) ? _submit : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                  : Text(
                                      _isSignUp
                                          ? 'CREATE ACCOUNT'
                                          : 'SIGN IN',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _isFormValid
                                              ? Colors.white
                                              : Colors.white.withValues(alpha: 0.4),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.2)),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
                    // Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? 'Already have an account?'
                              : "Don't have an account?",
                          style:
                              const TextStyle(fontSize: 12, color: _textDim),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: _toggleMode,
                          child: Text(
                            _isSignUp ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                                fontSize: 12,
                                color: _accent,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Function? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: _textDim,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: const TextStyle(color: _text, fontSize: 14),
          onSubmitted: (v) {
            if (onSubmit != null) {
              if (onSubmit is Function(String)) {
                onSubmit(v);
              } else {
                (onSubmit as VoidCallback)();
              }
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textDim, fontSize: 13),
            prefixIcon:
                Icon(icon, size: 18, color: _textDim),
            counterText: '',
            filled: true,
            fillColor: _bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
