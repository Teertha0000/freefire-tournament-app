import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../core/theme.dart';
import '../widgets/app_background.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ignController;
  late TextEditingController _uidController;
  late TextEditingController _phoneController;

  late String _selectedAvatarId;
  late String _selectedPaymentMethod;
  File? _newAvatarFile;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ignController = TextEditingController(text: widget.user.ign);
    _uidController = TextEditingController(text: widget.user.uid);
    _phoneController = TextEditingController(text: widget.user.phone);
    _selectedAvatarId = widget.user.avatarId.isEmpty ? 'avatar_1' : widget.user.avatarId;
    _selectedPaymentMethod = widget.user.paymentMethod.isEmpty ? 'bKash' : widget.user.paymentMethod;
  }

  @override
  void dispose() {
    _ignController.dispose();
    _uidController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(profileUpdateProvider.notifier).updateProfile(
        widget.user.id,
        _ignController.text.trim(),
        _uidController.text.trim(),
        _phoneController.text.trim(),
        widget.user.referralCode, // Keep existing referral code
        _selectedPaymentMethod,
        _selectedAvatarId,
        newAvatarFile: _newAvatarFile,
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _newAvatarFile = File(image.path);
      });
    }
  }

  Widget _buildAvatarSelector() {
    return Center(
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryCyan, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryCyan.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.surfaceGrey,
              backgroundImage: _newAvatarFile != null
                  ? FileImage(_newAvatarFile!) as ImageProvider
                  : (widget.user.avatarId.startsWith('http')
                      ? NetworkImage(widget.user.avatarId)
                      : NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=${widget.user.ign.isEmpty ? 'Player' : widget.user.ign}&backgroundColor=b6e3f4,c0aede,d1d4f9')),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryCyan,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Payment Method',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildPaymentCard('bKash', Colors.pinkAccent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPaymentCard('Nagad', const Color(0xFFE95724)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentCard(String method, Color brandColor) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? brandColor.withOpacity(0.1) : AppTheme.surfaceGrey,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : Colors.white.withOpacity(0.05),
            width: 2,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isSelected ? brandColor : Colors.white54,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                method,
                style: TextStyle(
                  color: isSelected ? brandColor : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(profileUpdateProvider);

    ref.listen<ProfileUpdateState>(profileUpdateProvider, (previous, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: Colors.red));
      }
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.successMessage!), backgroundColor: Colors.green));
        Navigator.pop(context); // Go back after success
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAvatarSelector(),
                  const SizedBox(height: 32),
                  
                  TextFormField(
                    controller: _ignController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'In-Game Name (IGN)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.person, color: AppTheme.primaryCyan),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceGrey,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: _uidController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'FreeFire UID',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.numbers, color: AppTheme.primaryCyan),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceGrey,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: _phoneController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      labelStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryCyan),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppTheme.primaryCyan),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceGrey,
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  
                  const SizedBox(height: 32),
                  _buildPaymentMethodSelector(),
                  
                  const SizedBox(height: 48),
                  
                  ElevatedButton(
                    onPressed: updateState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                      shadowColor: AppTheme.primaryCyan.withOpacity(0.5),
                    ),
                    child: updateState.isLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
