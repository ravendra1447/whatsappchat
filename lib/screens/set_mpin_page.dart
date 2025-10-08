import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:whatsappchat/screens/user_profile_page.dart';
import '../services/local_auth_service.dart';

class SetMpinPage extends StatefulWidget {
  const SetMpinPage({super.key});

  @override
  State<SetMpinPage> createState() => _SetMpinPageState();
}

class _SetMpinPageState extends State<SetMpinPage> {
  String mpin = "";
  String confirmMpin = "";
  bool loading = false;

  bool _showMpin = false;
  bool _showConfirmMpin = false;

  Future<void> _setMpin() async {
    if (mpin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("MPIN must be at least 4 digits")),
      );
      return;
    }

    if (mpin != confirmMpin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("MPIN and Confirm MPIN must match")),
      );
      return;
    }

    final userId = LocalAuthService.getUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found. Please login again.")),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => loading = true);
    final res = await LocalAuthService.setMpin(mpin);
    setState(() => loading = false);

    if (res["success"] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(userId: userId), // ✅ FIXED
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Failed to set MPIN")),
      );
    }
  }

  Widget buildPinField({
    required bool obscure,
    required Function(String) onChanged,
    required VoidCallback toggleObscure,
  }) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        PinCodeTextField(
          appContext: context,
          length: 6,
          obscureText: !obscure,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(10),
            fieldHeight: 55,
            fieldWidth: 50,
            activeFillColor: Colors.white,
            inactiveFillColor: Colors.white,
            selectedFillColor: Colors.grey.shade100,
          ),
          animationDuration: const Duration(milliseconds: 250),
          enableActiveFill: true,
          onChanged: onChanged,
        ),
        Positioned(
          right: 0,
          child: IconButton(
            icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: toggleObscure,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Your MPIN")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Create a secure 4–6 digit MPIN\nThis will be used for quick login",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            buildPinField(
              obscure: _showMpin,
              onChanged: (val) => mpin = val,
              toggleObscure: () => setState(() => _showMpin = !_showMpin),
            ),

            const SizedBox(height: 20),
            const Text(
              "Confirm MPIN",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            buildPinField(
              obscure: _showConfirmMpin,
              onChanged: (val) => confirmMpin = val,
              toggleObscure: () =>
                  setState(() => _showConfirmMpin = !_showConfirmMpin),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : _setMpin,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: loading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text("Set MPIN"),
            ),
          ],
        ),
      ),
    );
  }
}
