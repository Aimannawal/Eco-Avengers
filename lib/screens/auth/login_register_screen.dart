import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../home_screen.dart';

class LoginRegisterScreen extends StatefulWidget {
  final bool initialIsLogin;
  const LoginRegisterScreen({Key? key, this.initialIsLogin = true}) : super(key: key);

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  late bool _isLogin;
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _displayNameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialIsLogin;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _pinController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final pin = _pinController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (username.isEmpty || pin.isEmpty) {
      setState(() => _errorMessage = 'Username dan PIN harus diisi');
      return;
    }
    if (pin.length != 4) {
      setState(() => _errorMessage = 'PIN harus 4 angka');
      return;
    }
    if (!_isLogin && displayName.isEmpty) {
      setState(() => _errorMessage = 'Display Name harus diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Map<String, dynamic> result;
    if (_isLogin) {
      result = await AuthService.instance.login(username: username, pin: pin);
    } else {
      result = await AuthService.instance.register(
        username: username,
        pin: pin,
        displayName: displayName,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        // success, go to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        setState(() => _errorMessage = result['error'] ?? 'Terjadi kesalahan');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 500;
    
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/background/kayu.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: 400,
                  padding: EdgeInsets.all(isCompact ? 20 : 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF7F2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF111111), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo/Title
                      Image.asset(
                        'assets/logo/logo.png',
                        height: isCompact ? 50 : 70,
                      ),
                      SizedBox(height: isCompact ? 12 : 24),
                      Text(
                        _isLogin ? 'LOGIN' : 'REGISTER',
                        style: GoogleFonts.montserrat(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF4A6741),
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: isCompact ? 12 : 24),
                      
                      // Error message
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEB5757).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFEB5757)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFEB5757), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFEB5757),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Fields
                      if (!_isLogin) ...[
                        _buildTextField(
                          controller: _displayNameController,
                          label: 'Display Name',
                          icon: Icons.badge_rounded,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _pinController,
                        label: '4-Digit PIN',
                        icon: Icons.lock_rounded,
                        isNumber: true,
                        maxLength: 4,
                        obscureText: true,
                      ),
                      
                      SizedBox(height: isCompact ? 20 : 32),
                      
                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFA5C18A),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFF111111), width: 2),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                )
                              : Text(
                                  _isLogin ? 'LOGIN' : 'REGISTER',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Toggle button
                      TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isLogin ? 'Belum punya akun? Register' : 'Sudah punya akun? Login',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4A6741),
                          ),
                        ),
                      ),
                      
                      // Back to home (skip login)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: Text(
                          'Kembali ke Beranda',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
    int? maxLength,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      maxLength: maxLength,
      obscureText: obscureText,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.black54),
        prefixIcon: Icon(icon, color: const Color(0xFF4A6741)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.2), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4A6741), width: 2),
        ),
      ),
    );
  }
}
