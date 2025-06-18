import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart';
import 'package:gyefo_clocking_app/services/preferences_service.dart';
import 'package:gyefo_clocking_app/services/firestore_service.dart';
import 'package:gyefo_clocking_app/utils/app_theme.dart';
import 'package:gyefo_clocking_app/screens/manager_dashboard.dart';
import 'package:gyefo_clocking_app/screens/worker_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _rememberCredentials = false;
  bool _obscurePassword = true;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadSavedCredentials();
    _startAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: AppAnimations.slow,
      vsync: this,
    );
    _slideController = AnimationController(
      duration: AppAnimations.normal,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: AppAnimations.fadeInCurve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: AppAnimations.slideInCurve,
      ),
    );
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      _slideController.forward();
    });
  }

  Future<void> _loadSavedCredentials() async {
    final credentials = await PreferencesService.loadCredentials();
    final rememberCredentials =
        await PreferencesService.shouldRememberCredentials();

    if (credentials['email'] != null && credentials['password'] != null) {
      setState(() {
        _emailController.text = credentials['email']!;
        _passwordController.text = credentials['password']!;
        _rememberCredentials = rememberCredentials;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      // Add haptic feedback
      HapticFeedback.lightImpact();

      setState(() {
        _isLoading = true;
      });

      try {
        // Save credentials if remember is checked
        if (_rememberCredentials) {
          await PreferencesService.saveCredentials(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            rememberCredentials: true,
          );
        } else {
          await PreferencesService.clearCredentials();
        }

        final authService = AuthService();
        final user = await authService.signIn(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (mounted && user != null) {
          // Success haptic feedback
          HapticFeedback.mediumImpact();

          // Get user role from Firestore
          final userDoc = await FirestoreService.getUserData(user.uid);
          final userRole = userDoc?['role'] ?? 'worker';

          if (mounted) {
            if (userRole == 'manager') {
              Navigator.of(context).pushReplacement(
                AppTheme.createPageRoute(
                  const ManagerDashboard(),
                  routeName: '/manager-dashboard',
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                AppTheme.createPageRoute(
                  const WorkerDashboard(),
                  routeName: '/worker-dashboard',
                ),
              );
            }
          }
        } else if (mounted) {
          _showErrorSnackBar('Invalid email or password');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('An error occurred: ${e.toString()}');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Enter your email address',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _signIn(),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Enter your password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildRememberCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberCredentials,
          onChanged: (value) {
            setState(() {
              _rememberCredentials = value ?? false;
            });
          },
          activeColor: AppTheme.primaryGreen,
        ),
        Text(
          'Remember my credentials',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppTheme.textDark),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        child:
            _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : const Text('Sign In'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightGrey,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // App Logo/Icon
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Welcome Text
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Welcome Back',
                          style: Theme.of(
                            context,
                          ).textTheme.displayMedium?.copyWith(
                            color: AppTheme.textDark,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue to Gyefo',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppTheme.textLight),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Login Form
                  SlideTransition(
                    position: _slideAnimation,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email Field
                          _buildEmailField(),
                          const SizedBox(height: 16),

                          // Password Field
                          _buildPasswordField(),
                          const SizedBox(height: 16),

                          // Remember Credentials Checkbox
                          _buildRememberCheckbox(),
                          const SizedBox(height: 32), // Login Button
                          _buildLoginButton(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),

                  // Developer Credit Footer
                  SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      'Developed with ❤️ by Manuel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
