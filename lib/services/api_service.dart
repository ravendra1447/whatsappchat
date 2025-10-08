import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../models/profile_setting.dart';

class ApiService {
  // Updated Base URL
  static const baseUrl = "http://184.168.126.71/api";

  static final _authBox = Hive.box("authBox");

  /// ================= AUTH ================= ///

  /// Send OTP
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/send_otp.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  /// Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/verify_otp.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "otp": otp}),
      );

      final data = jsonDecode(res.body);
      if (data["success"] == true) {
        await _authBox.put("user_id", data["user_id"]);
        await _authBox.put("phone", phone);
      }
      return data;
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  /// Set MPIN
  static Future<Map<String, dynamic>> setMpin(String mpin) async {
    try {
      final userId = _authBox.get("user_id");
      final res = await http.post(
        Uri.parse("$baseUrl/set_mpin.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "mpin": mpin}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  /// Verify MPIN
  static Future<Map<String, dynamic>> verifyMpin(String mpin) async {
    try {
      final userId = _authBox.get("user_id");
      final res = await http.post(
        Uri.parse("$baseUrl/verify_mpin.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "mpin": mpin}),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  static bool isLoggedIn() => _authBox.containsKey("user_id");
  static Future<void> logout() async => _authBox.clear();

  /// ================= PROFILE ================= ///

  /// Insert Profile
  static Future<Map<String, dynamic>> insertProfile(ProfileSetting profile) async {
    try {
      final userId = _authBox.get("user_id");
      final res = await http.post(
        Uri.parse("$baseUrl/insert_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile.toJson()..["user_id"] = userId),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  /// Update Profile
  static Future<Map<String, dynamic>> updateProfile(ProfileSetting profile) async {
    try {
      final userId = _authBox.get("user_id");
      final res = await http.post(
        Uri.parse("$baseUrl/update_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile.toJson()
          ..["user_id"] = userId
          ..["id"] = profile.id),
      );
      return jsonDecode(res.body);
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  /// Get Profile
  static Future<ProfileSetting?> getProfile() async {
    try {
      final userId = _authBox.get("user_id");
      final res = await http.get(
        Uri.parse("$baseUrl/get_profile.php?id=$userId"),
      );

      final data = jsonDecode(res.body);

      if (data["success"] == true && data["profile"] != null) {
        return ProfileSetting.fromJson(data["profile"]);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}