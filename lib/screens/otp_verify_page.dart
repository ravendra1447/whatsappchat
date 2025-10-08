import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../services/my_firebase_messaging_service.dart';
import '../services/local_auth_service.dart';
import 'set_mpin_page.dart';
import 'verify_mpin_page.dart';
import '../services/my_firebase_messaging_service.dart'; // ✅ Added this import

class OtpVerifyPage extends StatefulWidget {
  final String phone;
  const OtpVerifyPage({super.key, required this.phone});

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  String otp = "";
  bool loading = false;

  Future<void> _verifyOtp() async {
    if (otp.isEmpty || otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter valid 6-digit OTP")),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() => loading = true);
    final res = await LocalAuthService.verifyOtp(widget.phone, otp);
    setState(() => loading = false);

    if (res["success"] == true) {
      // ✅ STEP 1: Now that user ID is saved in ApiService.dart,
      // send the FCM token to the server.
      await MyFirebaseMessagingService.saveFcmTokenToServer();

      // ✅ STEP 2: Navigate to the correct page based on mpin status.
      if (res["mpin_set"] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VerifyMpinPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SetMpinPage()),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res["message"] ?? "Invalid OTP")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifying your number")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Waiting to automatically detect 6-digit code sent by SMS to\n${widget.phone}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),

            // OTP BOXES
            PinCodeTextField(
              appContext: context,
              length: 6,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 50,
                fieldWidth: 45,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.white,
                selectedFillColor: Colors.grey.shade200,
              ),
              animationDuration: const Duration(milliseconds: 300),
              enableActiveFill: true,
              onChanged: (value) => otp = value,
            ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // TODO: resend OTP API call
              },
              child: const Text("Didn't receive code? Resend"),
            ),

            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: loading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
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
                  : const Text("Verify"),
            ),
          ],
        ),
      ),
    );
  }
}
