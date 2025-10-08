import 'package:flutter/material.dart';
import '../services/local_auth_service.dart';
import 'otp_verify_page.dart';

class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _controller = TextEditingController();
  bool loading = false;

  Future<void> _sendOtp() async {
    final phone = _controller.text.trim();

    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid phone number")),
      );
      return;
    }

    FocusScope.of(context).unfocus(); // keyboard band karo

    setState(() => loading = true);
    final res = await LocalAuthService.sendOtp(phone);
    setState(() => loading = false);

    if (res["success"] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpVerifyPage(phone: phone)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Failed to send OTP")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                "Verify your phone number",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "WhatsApp will need to verify your phone number.\nCarrier charges may apply.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Country dropdown (abhi static India rakha hai)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: "India",
                    items: const [
                      DropdownMenuItem(
                        value: "India",
                        child: Text("India"),
                      ),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Phone input row
              Row(
                children: [
                  Container(
                    width: 70,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      "+91",
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: "Phone number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Green button like WhatsApp
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // WhatsApp green
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    "Next",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
