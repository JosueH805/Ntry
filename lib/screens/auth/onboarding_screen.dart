import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ntry_mobile/auth/auth_service.dart';
import 'package:ntry_mobile/database/user_helper.dart';
import 'package:ntry_mobile/widgets/search_picker_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;
  int _roleIndex = 0; // 0 = Resident, 1 = Admin
  String? _selectedOrganization;
  final List<String> _organizations = ['CBU'];
  bool _ownDevice = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = authServiceInstance.currentUser;
      if (user == null) throw Exception('No authenticated user');

      await UserHelper().setUserProfile(user.uid, {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'hasCompletedOnboarding': true,
        'role': _roleIndex == 0 ? 'resident' : 'admin',
        'organization': _ownDevice ? 'Individual' : _selectedOrganization,
        'ownDevice': _ownDevice,
        'approvalStatus': 'pending',
      });

      // Refresh the auth service — the router will automatically redirect
      // to the correct home screen based on the user's role.
      await authServiceInstance.refreshProfile();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving profile. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Complete Your Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'First Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'First name is required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(hintText: 'Last Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Last name is required'
                          : null,
                    ),
                  ),
                ],
              ),
              if (!_ownDevice) ...[
                const SizedBox(height: 10),
                _buildRoleSelector(Theme.of(context).colorScheme),
                if (_roleIndex == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'You will need to be approved to be registered as an admin.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                FormField<String>(
                  initialValue: _selectedOrganization,
                  validator: (value) => _ownDevice
                      ? null
                      : value == null
                          ? 'Please select an organization'
                          : null,
                  builder: (field) {
                    return GestureDetector(
                      onTap: () async {
                        final result =
                            await showModalBottomSheet<PickerOption>(
                          context: context,
                          isScrollControlled: true,
                          builder: (ctx) => SearchPickerSheet(
                            title: 'Select Organization',
                            subtitle:
                                'Find and select your organization.',
                            searchHint: 'Search organizations...',
                            itemIcon: Icons.business_outlined,
                            optionsFuture: Future.value(
                              _organizations
                                  .map(
                                    (o) =>
                                        PickerOption(id: o, label: o),
                                  )
                                  .toList(),
                            ),
                            confirmLabel: 'Select',
                          ),
                        );
                        if (result != null) {
                          setState(
                            () => _selectedOrganization = result.id,
                          );
                          field.didChange(result.id);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'Select Organization',
                          prefixIcon: const Icon(
                            Icons.business_outlined,
                            size: 20,
                          ),
                          suffixIcon: const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                          ),
                          errorText: field.errorText,
                        ),
                        isEmpty: _selectedOrganization == null,
                        child: _selectedOrganization != null
                            ? Text(
                                _selectedOrganization!,
                                style: GoogleFonts.inter(fontSize: 14),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ],
              if (_roleIndex == 0)
                CheckboxListTile(
                  value: _ownDevice,
                  onChanged: (bool? value) {
                    setState(() {
                      _ownDevice = value ?? false;
                      _roleIndex = 0;
                      _selectedOrganization = null;
                    });
                  },
                  title: Text(
                    'I have my own personal Ntry device',
                    style: GoogleFonts.inter(fontSize: 14),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Role Selector Widget ───────────────────────────────────────────
  Widget _buildRoleSelector(ColorScheme colors) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          _roleOption(colors, 'Resident', 0),
          _roleOption(colors, 'Admin', 1),
        ],
      ),
    );
  }

  Widget _roleOption(ColorScheme colors, String label, int index) {
    final bool isSelected = _roleIndex == index;
    final Color contentColor =
        isSelected ? colors.onPrimary : colors.onSurfaceVariant;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _roleIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  index == 0 ? Icons.person_outline : Icons.shield_outlined,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: contentColor,
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
