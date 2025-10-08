import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/local_auth_service.dart';
import 'chat_home.dart';
import 'otp_verify_page.dart';

class VerifyMpinPage extends StatefulWidget {
  const VerifyMpinPage({super.key});

  @override
  State<VerifyMpinPage> createState() => _VerifyMpinPageState();
}

class _VerifyMpinPageState extends State<VerifyMpinPage> {
  String mpin = "";
  bool loading = false;

  Future<void> _verifyMpin() async {
    if (mpin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your MPIN")),
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

    // ✅ Sirf MPIN verify karo
    final res = await LocalAuthService.verifyMpin(mpin);
    setState(() => loading = false);

    if (res["success"] == true) {
      // 🔥 Direct Chat screen khol do
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChatHomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Invalid MPIN")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify MPIN")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter your 4–6 digit MPIN\nto unlock your account",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 40),

            // MPIN BOXES
            PinCodeTextField(
              appContext: context,
              length: 6,
              obscureText: true,
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
              onChanged: (value) => mpin = value,
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: loading ? null : _verifyMpin,
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
                  : const Text("Verify MPIN"),
            ),

            const SizedBox(height: 15),

            // 🔑 Forgot MPIN
            TextButton(
              onPressed: () {
                final phone = LocalAuthService.getPhone();
                if (phone != null && phone.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OtpVerifyPage(phone: phone),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Phone number not found!")),
                  );
                }
              },
              child: const Text(
                "Forgot MPIN?",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
