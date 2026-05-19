import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ntry_mobile/database/user_helper.dart';
import 'package:ntry_mobile/providers/lock_provider.dart';
import 'package:ntry_mobile/providers/user_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  final UserHelper _userHelper = UserHelper();

  bool _hasChanges = false;
  late String _originalName;

  @override
  void initState() {
    super.initState();
    _originalName = userProviderInstance.displayName;
    _usernameController.text = _originalName;
    _usernameController.addListener(_onNameChanged);
    _loadStaticData();
  }

  void _onNameChanged() {
    final changed = _usernameController.text.trim() != _originalName.trim();
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  Future<void> _loadStaticData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _userHelper.getUser(user.uid);
    if (!doc.exists) return;

    final data = doc.data();
    if (data == null) return;

    if (!mounted) return;
    setState(() {
      _emailController.text = data['email'] ?? '';
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final fullName = _usernameController.text.trim();
    final parts = fullName.split(' ');

    String firstName = '';
    String lastName = '';

    if (parts.isNotEmpty) {
      firstName = parts.first;
    }

    if (parts.length > 1) {
      lastName = parts.sublist(1).join(' ');
    }

    Map<String, dynamic> updates = {
      'first_name': firstName,
      'last_name': lastName,
    };

    try {
      await _firestore.collection('users').doc(user.uid).update(updates);

      if (!mounted) return;
      setState(() {
        _originalName = _usernameController.text.trim();
        _hasChanges = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onNameChanged);
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          userProviderInstance,
          lockProviderInstance,
        ]),
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                CircleAvatar(
                  radius: 50,
                  child: const Icon(Icons.person, size: 50),
                ),

                const SizedBox(height: 12),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (userProviderInstance.organization != null) ...[
                          Text(
                            userProviderInstance.organization!,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          const Text('·'),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          (userProviderInstance.role ?? '').isEmpty
                              ? ''
                              : '${userProviderInstance.role![0].toUpperCase()}${userProviderInstance.role!.substring(1)}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                if (userProviderInstance.role == 'resident') ...[
                  TextFormField(
                    readOnly: true,
                    enabled: false,
                    controller: TextEditingController(
                      text: lockProviderInstance.room ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Room',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                if (_hasChanges)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text('Save Changes'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
