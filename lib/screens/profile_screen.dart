import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/rider_profile.dart';
import '../providers/profile_provider.dart';
import '../utils/app_theme.dart';
import '../widgets/glass_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobileController;
  String _bikeModel = RiderProfile.bikeModels.first;
  String _imagePath = '';

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _nameController = TextEditingController(text: profile.name);
    _emailController = TextEditingController(text: profile.email);
    _mobileController = TextEditingController(text: profile.mobile);
    _bikeModel = profile.bikeModel;
    _imagePath = profile.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider profile'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          GlassCard(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 58,
                        backgroundColor: AppColors.surfaceHigh,
                        backgroundImage: _imagePath.isEmpty
                            ? null
                            : FileImage(File(_imagePath)),
                        child: _imagePath.isEmpty
                            ? const Icon(Icons.person,
                                size: 54, color: AppColors.muted)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle, color: AppColors.green),
                        child: const Icon(Icons.camera_alt,
                            size: 18, color: AppColors.background),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Yezdi Rider',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Profile is saved locally on this phone',
                    style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                        labelText: 'Rider name', prefixIcon: Icon(Icons.badge)),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter rider name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email', prefixIcon: Icon(Icons.email)),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        prefixIcon: Icon(Icons.phone)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _bikeModel,
                    decoration: const InputDecoration(
                        labelText: 'Bike model',
                        prefixIcon: Icon(Icons.two_wheeler)),
                    items: RiderProfile.bikeModels
                        .map((model) =>
                            DropdownMenuItem(value: model, child: Text(model)))
                        .toList(),
                    onChanged: (value) => setState(() =>
                        _bikeModel = value ?? RiderProfile.bikeModels.first),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
    if (picked != null) setState(() => _imagePath = picked.path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = RiderProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      mobile: _mobileController.text.trim(),
      bikeModel: _bikeModel,
      imagePath: _imagePath,
    );
    await context.read<ProfileProvider>().save(profile);
    if (mounted) Navigator.pop(context);
  }
}
