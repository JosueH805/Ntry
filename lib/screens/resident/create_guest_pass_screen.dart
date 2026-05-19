import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/theme/app_colors.dart';
import 'package:ntry_mobile/widgets/lock_form_widgets.dart';
import 'package:ntry_mobile/Database/guest_helper.dart';
import 'package:ntry_mobile/Database/lock_helper.dart';
import 'package:ntry_mobile/Database/cloud_functions.dart';

class CreateGuestPassScreen extends StatefulWidget {
  final String lockId;

  const CreateGuestPassScreen({super.key, required this.lockId});

  @override
  State<CreateGuestPassScreen> createState() => _CreateGuestPassScreenState();
}

class _CreateGuestPassScreenState extends State<CreateGuestPassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String _generatePin() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  Future<void> _submit() async {
  final name = _nameController.text.trim();
  final durationText = _durationController.text.trim();

  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enter guest name")),
    );
    return;
  }

  final durationHours = int.tryParse(durationText);
  if (durationHours == null || durationHours <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enter valid duration")),
    );
    return;
  }

  final maxDuration =
      await LockHelper().getGuestPassMaxDuration(widget.lockId);

  // print("maxDuration: $maxDuration");

  if (maxDuration != null && durationHours > maxDuration) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            "Maximum allowed duration is $maxDuration hours"),
      ),
    );
    return;
  }

  setState(() => _submitting = true);

  try {
    final pin = _generatePin();

    final now = DateTime.now();
    final expiresAt = now.add(Duration(hours: durationHours));

    await GuestHelper().createGuest(
      lockId: widget.lockId,
      name: name,
      passkey: pin,
      duration: durationHours,
      initTime: DateTime.now().toIso8601String(),
      expiresAt: expiresAt,
    );

    // final cloudFunctions = CloudFunctions();

  //   await cloudFunctions.signGuestPass(
  //   passId: pin,
  //   lockId: widget.lockId,
  //   expiresAt: expiresAt.millisecondsSinceEpoch,
  // );

    if (mounted) Navigator.of(context).pop();
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _submitting = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        title: const Text("Create Guest Pass"),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LockSectionLabel('Guest Information'),
              const SizedBox(height: 12),

              LockTextField(
                controller: _nameController,
                label: 'Guest Name',
                icon: Icons.person_outline,
                hintText: 'e.g. John Smith',
              ),

              const SizedBox(height: 16),

              LockTextField(
                controller: _durationController,
                label: 'Duration (hours)',
                icon: Icons.timer_outlined,
                hintText: 'e.g. 2',
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Guest Pass'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}