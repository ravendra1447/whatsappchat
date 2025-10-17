import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 4)
class Contact extends HiveObject {
  @HiveField(0)
  final int contactId;

  @HiveField(1)
  final int ownerUserId;

  @HiveField(2)
  String contactName;

  @HiveField(3)
  final String contactPhone;

  @HiveField(4)
  bool isOnApp;

  @HiveField(5)
  int? appUserId;

  @HiveField(6)
  DateTime? updatedAt;

  @HiveField(7)
  bool isDeleted;

  // ✅ 8. Last Message Time field जोड़ा गया
  @HiveField(8)
  DateTime lastMessageTime; // Now a part of the Hive object

  Contact({
    required this.contactId,
    required this.ownerUserId,
    required this.contactName,
    required this.contactPhone,
    this.isOnApp = false,
    this.appUserId,
    this.updatedAt,
    this.isDeleted = false,
    // ✅ 9. lastMessageTime constructor में शामिल किया गया
    required this.lastMessageTime,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      contactId: int.tryParse(json["contact_id"].toString()) ?? 0,
      ownerUserId: int.tryParse(json["owner_user_id"].toString()) ?? 0,
      contactName: json["contact_name"] ?? "",
      contactPhone: json["contact_phone"] ?? "",
      isOnApp: json["is_on_app"] == 1 || json["is_on_app"] == true,
      appUserId: json["user_id"] != null
          ? int.tryParse(json["user_id"].toString())
          : null,
      updatedAt: json["updated_at"] != null
          ? DateTime.parse(json["updated_at"].toString())
          : null,
      isDeleted: false,
      // ✅ 10. lastMessageTime के लिए एक डिफ़ॉल्ट मान (जैसे एक बहुत पुरानी तारीख) दिया गया है।
      // यह मान लिया गया है कि API response में यह नहीं होता, लेकिन constructor में ज़रूरी है।
      lastMessageTime: DateTime(2000),
    );
  }

  // 🟢 toJson method जोड़ा गया ताकि यह JSON में एन्कोड हो सके
  Map<String, dynamic> toJson() {
    return {
      'contact_id': contactId,
      'owner_user_id': ownerUserId,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'is_on_app': isOnApp ? 1 : 0, // आमतौर पर API 1/0 की उम्मीद करता है
      'app_user_id': appUserId,
      'is_deleted': isDeleted ? 1 : 0, // आमतौर पर API 1/0 की उम्मीद करता है
      'updated_at': updatedAt?.toIso8601String(),
      'last_message_time': lastMessageTime.toIso8601String(),
    };
  }
}
