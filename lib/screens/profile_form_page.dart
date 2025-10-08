import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/profile_setting.dart';
import '../services/api_service.dart';
import '../services/local_auth_service.dart';
import 'business_type_page.dart';
import 'chat_home.dart'; // 👈 ensure ye file path sahi ho

class ProfileFormPage extends StatefulWidget {
  final ProfileSetting? existingProfile;
  final String selectedBusinessType;

  const ProfileFormPage({
    super.key,
    this.existingProfile,
    required this.selectedBusinessType,
  });

  @override
  State<ProfileFormPage> createState() => _ProfileFormPageState();
}

class _ProfileFormPageState extends State<ProfileFormPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final legalBusinessNameController = TextEditingController();
  final businessCategoryController = TextEditingController();
  final gstNoController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();
  final websiteController = TextEditingController();
  final businessDescriptionController = TextEditingController();
  final aboutController = TextEditingController();
  final upiQrCodeController = TextEditingController();

  String? selectedBusinessType;
  File? _pickedImage;

  final List<String> businessTypes = [
    "Manufacturer",
    "Retailer",
    "Trader",
    "Wholesaler",
    "Other",
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingProfile != null) {
      // Edit mode
      nameController.text = widget.existingProfile!.name ?? "";
      legalBusinessNameController.text =
          widget.existingProfile!.legalBusinessName ?? "";
      selectedBusinessType = widget.existingProfile!.businessType;
      businessCategoryController.text =
          widget.existingProfile!.businessCategory ?? "";
      gstNoController.text = widget.existingProfile!.gstNo ?? "";
      phoneController.text = widget.existingProfile!.phoneNumber ?? "";
      addressController.text = widget.existingProfile!.address ?? "";
      emailController.text = widget.existingProfile!.email ?? "";
      websiteController.text = widget.existingProfile!.website ?? "";
      businessDescriptionController.text =
          widget.existingProfile!.businessDescription ?? "";
      aboutController.text = widget.existingProfile!.about ?? "";
      upiQrCodeController.text = widget.existingProfile!.upiQrCode ?? "";
    } else {
      // Create mode: Logged-in user ka phone number auto-fill
      phoneController.text = LocalAuthService.getPhone() ?? "";
      selectedBusinessType = widget.selectedBusinessType;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const BusinessTypePage(),
              ),
            );
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),

              // Avatar + Edit button
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 70,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!)
                          : const AssetImage("assets/default_avatar.png")
                      as ImageProvider,
                    ),
                    TextButton(
                      onPressed: _pickImage,
                      child: const Text(
                        "Edit",
                        style: TextStyle(color: Colors.blue, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              buildTextField("Name", nameController, required: true),
              buildTextField("Legal Business Name", legalBusinessNameController),
              DropdownButtonFormField<String>(
                value: selectedBusinessType,
                decoration: const InputDecoration(
                  labelText: "Business Category",
                  border: OutlineInputBorder(),
                ),
                items: businessTypes
                    .map((type) =>
                    DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBusinessType = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: businessCategoryController.text.isNotEmpty
                    ? businessCategoryController.text
                    : null,
                decoration: const InputDecoration(
                  labelText: "Business Type",
                  border: OutlineInputBorder(),
                ),
                items: [
                  "Limited Liability Partnership",
                  "Sole Proprietorship",
                  "Partnership",
                  "Public Company",
                  "Private Company",
                  "Others",
                ]
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    businessCategoryController.text = value ?? "";
                  });
                },
              ),

              buildTextField("GST No", gstNoController),

              // ✅ Phone number field read-only
              buildTextField("Phone Number", phoneController, readOnly: true),

              buildTextField("Address", addressController),
              buildTextField("Email", emailController),
              buildTextField("Website", websiteController),
              buildTextField(
                  "Business Description", businessDescriptionController),
              buildTextField("About", aboutController),
              buildTextField("UPI QR Code URL", upiQrCodeController),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveProfile,
                child: Text(widget.existingProfile == null
                    ? "Create Profile"
                    : "Update Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool required = false, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: required
            ? (val) =>
        val == null || val.isEmpty ? "$label is required" : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    var profile = ProfileSetting(
      id: widget.existingProfile?.id,
      name: nameController.text,
      legalBusinessName: legalBusinessNameController.text,
      businessType: selectedBusinessType,
      businessCategory: businessCategoryController.text,
      gstNo: gstNoController.text,
      phoneNumber: phoneController.text,
      address: addressController.text,
      email: emailController.text,
      website: websiteController.text,
      businessDescription: businessDescriptionController.text,
      about: aboutController.text,
      profileImage: _pickedImage?.path ?? "",
      upiQrCode: upiQrCodeController.text,
    );

    Map<String, dynamic> response;

    if (widget.existingProfile == null) {
      response = await ApiService.insertProfile(profile);
    } else {
      response = await ApiService.updateProfile(profile);
    }

    bool success = response["success"] == true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? "Profile saved ✅"
              : "Failed to save ❌\n${response["message"] ?? ""}"),
        ),
      );
      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChatHomePage(),
          ),
        );
      }
    }
  }
}