import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/services/auth_service.dart'; // Will be used later

class ManagerCreateWorkerScreen extends StatefulWidget {
  const ManagerCreateWorkerScreen({super.key});

  @override
  State<ManagerCreateWorkerScreen> createState() =>
      _ManagerCreateWorkerScreenState();
}

class _ManagerCreateWorkerScreenState extends State<ManagerCreateWorkerScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createWorker() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final name = _nameController.text.trim();

      final authService = AuthService();
      final user = await authService.createWorkerAccount(
        context,
        email,
        password,
        name,
      );

      if (mounted) {
        if (user != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Worker account for ${user.email} created successfully!',
              ),
            ),
          );
          _emailController.clear();
          _passwordController.clear();
          _nameController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to create worker account. Manager re-authentication might have failed or worker email already exists.',
              ),
            ),
          );
        }
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Worker Account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Worker Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter worker\'s name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Worker Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter worker\'s email';
                  }
                  if (!value.contains('@')) {
                    // Basic email validation
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                    onPressed: _createWorker,
                    child: const Text('Create Worker Account'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
