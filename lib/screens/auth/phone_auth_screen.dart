import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

// Country model
class _Country {
  final String name;
  final String flag;
  final String code;

  const _Country({required this.name, required this.flag, required this.code});
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _verificationId;
  String? _error;

  static const List<_Country> _countries = [
    _Country(name: 'India', flag: '🇮🇳', code: '+91'),
    _Country(name: 'United States', flag: '🇺🇸', code: '+1'),
    _Country(name: 'United Kingdom', flag: '🇬🇧', code: '+44'),
    _Country(name: 'Australia', flag: '🇦🇺', code: '+61'),
    _Country(name: 'Canada', flag: '🇨🇦', code: '+1'),
    _Country(name: 'UAE', flag: '🇦🇪', code: '+971'),
    _Country(name: 'Singapore', flag: '🇸🇬', code: '+65'),
    _Country(name: 'Germany', flag: '🇩🇪', code: '+49'),
    _Country(name: 'France', flag: '🇫🇷', code: '+33'),
    _Country(name: 'Japan', flag: '🇯🇵', code: '+81'),
    _Country(name: 'China', flag: '🇨🇳', code: '+86'),
    _Country(name: 'Brazil', flag: '🇧🇷', code: '+55'),
    _Country(name: 'Mexico', flag: '🇲🇽', code: '+52'),
    _Country(name: 'South Africa', flag: '🇿🇦', code: '+27'),
    _Country(name: 'Nigeria', flag: '🇳🇬', code: '+234'),
    _Country(name: 'Pakistan', flag: '🇵🇰', code: '+92'),
    _Country(name: 'Bangladesh', flag: '🇧🇩', code: '+880'),
    _Country(name: 'Sri Lanka', flag: '🇱🇰', code: '+94'),
    _Country(name: 'Nepal', flag: '🇳🇵', code: '+977'),
    _Country(name: 'Malaysia', flag: '🇲🇾', code: '+60'),
    _Country(name: 'Indonesia', flag: '🇮🇩', code: '+62'),
    _Country(name: 'Philippines', flag: '🇵🇭', code: '+63'),
    _Country(name: 'Thailand', flag: '🇹🇭', code: '+66'),
    _Country(name: 'Vietnam', flag: '🇻🇳', code: '+84'),
    _Country(name: 'South Korea', flag: '🇰🇷', code: '+82'),
    _Country(name: 'Italy', flag: '🇮🇹', code: '+39'),
    _Country(name: 'Spain', flag: '🇪🇸', code: '+34'),
    _Country(name: 'Netherlands', flag: '🇳🇱', code: '+31'),
    _Country(name: 'Sweden', flag: '🇸🇪', code: '+46'),
    _Country(name: 'Norway', flag: '🇳🇴', code: '+47'),
    _Country(name: 'New Zealand', flag: '🇳🇿', code: '+64'),
    _Country(name: 'Saudi Arabia', flag: '🇸🇦', code: '+966'),
    _Country(name: 'Kuwait', flag: '🇰🇼', code: '+965'),
    _Country(name: 'Qatar', flag: '🇶🇦', code: '+974'),
    _Country(name: 'Bahrain', flag: '🇧🇭', code: '+973'),
    _Country(name: 'Oman', flag: '🇴🇲', code: '+968'),
  ];

  _Country _selectedCountry = _countries[0];

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return;
    }

    final fullPhone = '${_selectedCountry.code}$phone';

    setState(() {
      _loading = true;
      _error = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _saveUsername();
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _error = e.message ?? 'Verification failed';
          _loading = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) {
      setState(() => _error = 'Please enter the OTP');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      await _saveUsername();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Invalid OTP';
        _loading = false;
      });
    }
  }

  Future<void> _saveUsername() async {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({required String hint, Widget? prefix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: prefix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Kharcha Book',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the OTP sent to ${_selectedCountry.code}${_phoneController.text}'
                    : 'Sign in or create your account',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 40),
              if (!_otpSent) ...[
                // Country picker
                DropdownButtonFormField<_Country>(
                  value: _selectedCountry,
                  dropdownColor: const Color(0xFF1A1A1A),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                  items: _countries.map((c) {
                    return DropdownMenuItem<_Country>(
                      value: c,
                      child: Text(
                        '${c.flag}  ${c.name} (${c.code})',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCountry = val);
                  },
                ),
                const SizedBox(height: 16),
                // Phone number field
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: '98765 43210',
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text(
                        _selectedCountry.code,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Username field
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.name,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    hint: 'Username (optional)',
                    prefix: const Icon(Icons.person_outline, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Send OTP',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ] else ...[
                // OTP field
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 24, letterSpacing: 8),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: const TextStyle(color: Colors.grey),
                    counterText: '',
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Verify OTP',
                            style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _otpSent = false),
                    child: const Text('Change number',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
