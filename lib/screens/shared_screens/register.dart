import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 800;

          return isWide
              ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Image.asset(
                      'assets/images/register-image.png',
                      fit: BoxFit.cover,
                      height: double.infinity,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: _RegisterForm(),
                    ),
                  ),
                ],
              )
              : SingleChildScrollView(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/register-image.png',
                      fit: BoxFit.cover,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _RegisterForm(),
                    ),
                  ],
                ),
              );
        },
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  String? _selectedRole;
  String _selectedDialCode = '+351';
  bool _isLoading = false;
  String? _errorMessage;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _dobController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final fullPhone = '$_selectedDialCode ${_phoneController.text}';

    try {
      // Check if email already exists in Firebase Auth
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(_emailController.text.trim());
      if (methods.isNotEmpty) {
        setState(() {
          _errorMessage = 'This email is already registered.';
          _isLoading = false;
        });
        return;
      }

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'name': _nameController.text.trim(),
            'dob': _dobController.text.trim(),
            'email': _emailController.text.trim(),
            'phone': fullPhone,
            'countryCode': _selectedDialCode,
            'role': _selectedRole?.toLowerCase(),
            'uid': credential.user!.uid,
            'created_at': FieldValue.serverTimestamp(),
            'image': 'assets/images/default-profile-picture.png',
          });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User registered successfully')),
      );
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340), // Reduced width from 400 to 340
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Sign Up',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person),
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter your name';
                  if (!RegExp(r"^[A-Za-zÀ-ÿ\s'-]+$").hasMatch(val)) {
                    return 'Name must not contain numbers or symbols';
                  }
                  if (val.length < 2) return 'Name too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: () => _selectDate(context),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.calendar_today),
                  labelText: 'Date of Birth',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter your date of birth';
                  // Optionally, check if user is at least 13 years old
                  final parts = val.split('/');
                  if (parts.length == 3) {
                    final day = int.tryParse(parts[0]);
                    final month = int.tryParse(parts[1]);
                    final year = int.tryParse(parts[2]);
                    if (day != null && month != null && year != null) {
                      final dob = DateTime(year, month, day);
                      final now = DateTime.now();
                      final age = now.year - dob.year - ((now.month < dob.month || (now.month == dob.month && now.day < dob.day)) ? 1 : 0);
                      if (age < 13) return 'You must be at least 13 years old';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email),
                  labelText: 'Your email',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter your email';
                  if (!RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+$").hasMatch(val)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  CountryCodePicker(
                    onChanged:
                        (country) => setState(
                          () => _selectedDialCode = country.dialCode!,
                        ),
                    initialSelection: 'PT',
                    favorite: const ['+351', 'PT'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    showFlag: true,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter phone number';
                        if (!RegExp(r"^[0-9]{6,15}$").hasMatch(val.replaceAll(' ', ''))) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock),
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showPassword = !_showPassword;
                      });
                    },
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter a password';
                  if (val.length < 6) return 'Min 6 characters';
                  if (!RegExp(r'[A-Z]').hasMatch(val)) return 'At least one uppercase letter';
                  if (!RegExp(r'[a-z]').hasMatch(val)) return 'At least one lowercase letter';
                  if (!RegExp(r'[0-9]').hasMatch(val)) return 'At least one number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_showConfirmPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline),
                  labelText: 'Confirm Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _showConfirmPassword = !_showConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (val) {
                  if (val != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                onChanged: (value) => setState(() => _selectedRole = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline),
                  labelText: 'Select your role',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null ? 'Select a role' : null,
                items: const [
                  DropdownMenuItem(
                    value: 'caregiver',
                    child: Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Color(0xFF1976D2), size: 20),
                        SizedBox(width: 8),
                        Text('Caregiver'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'family',
                    child: Row(
                      children: [
                        Icon(Icons.family_restroom, color: Color(0xFF388E3C), size: 20),
                        SizedBox(width: 8),
                        Text('Family Member'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'older_adult',
                    child: Row(
                      children: [
                        Icon(Icons.elderly, color: Color(0xFF8D6E63), size: 20),
                        SizedBox(width: 8),
                        Text('Older Adult'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Sign Up'),
                  ),
              const SizedBox(height: 8),
              const Divider(height: 32),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? "),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Log In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
