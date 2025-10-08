import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

class LocalAuthService {
  static final _authBox = Hive.box('authBox');

  // ⚠️ Apna server ka base URL yaha daalo
  // Emulator: http://10.0.2.2/api
  // Mobile Device: http://<your-ip>/api\
  //http://sbr.181.mytemp.website/api
  static const String baseUrl = "http://184.168.126.71/api";

  /// ---------------- Local Storage ----------------

  static Future<void> saveUser(int userId, String phone) async {
    await _authBox.put('userId', userId);
    await _authBox.put('phone', phone);
  }

  static int? getUserId() => _authBox.get('userId');
  static String? getPhone() => _authBox.get('phone');

  static bool isLoggedIn() => _authBox.containsKey('userId');

  static Future<void> logout() async => _authBox.clear();

  /// ✅ New: check if MPIN exists locally
  static bool hasMpin() => _authBox.containsKey('mpin');

  /// ---------------- API CALLS ----------------

  /// 1️⃣ Send OTP
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/send_otp.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// 2️⃣ Verify OTP
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/verify_otp.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone, "otp": otp}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        await saveUser(data['user_id'], phone);
      }

      return data;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// 3️⃣ Set MPIN
  static Future<Map<String, dynamic>> setMpin(String mpin) async {
    try {
      final userId = getUserId();
      if (userId == null) {
        return {"success": false, "message": "User not logged in"};
      }

      final response = await http.post(
        Uri.parse("$baseUrl/set_mpin.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "mpin": mpin}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        // ✅ MPIN ko locally bhi save karo taki splash screen check kar sake
        await _authBox.put('mpin', mpin);
      }

      return data;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// 4️⃣ Verify MPIN
  static Future<Map<String, dynamic>> verifyMpin(String mpin) async {
    try {
      final userId = getUserId();
      if (userId == null) {
        return {"success": false, "message": "User not logged in"};
      }

      final response = await http.post(
        Uri.parse("$baseUrl/verify_mpin.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "mpin": mpin}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        // agar server ne verify kar diya to local mpin bhi update ho jaye
        await _authBox.put('mpin', mpin);
      }

      return data;
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }


  /// 5️⃣ Insert Profile
  static Future<Map<String, dynamic>> insertProfile(Map<String, dynamic> profile) async {
    try {
      final userId = getUserId();
      if (userId == null) {
        return {"success": false, "message": "User not logged in"};
      }

      profile['user_id'] = userId;

      final response = await http.post(
        Uri.parse("$baseUrl/insert_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile),
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {"success": false, "message": "Error: ${e.toString()}"};
    }
  }

  /// 6️⃣ Update Profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profile) async {
    try {
      final userId = getUserId();
      if (userId == null) {
        return {"success": false, "message": "User not logged in"};
      }

      profile['user_id'] = userId;

      final response = await http.post(
        Uri.parse("$baseUrl/update_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile),
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {"success": false, "message": "Error: ${e.toString()}"};
    }
  }

  /// 7️⃣ Get Profile
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final userId = getUserId();
      if (userId == null) {
        return {"success": false, "message": "User not logged in"};
      }

      final response = await http.post(
        Uri.parse("$baseUrl/get_profile.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId}),
      );

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      return {"success": false, "message": "Error: ${e.toString()}"};
    }
  }

}
