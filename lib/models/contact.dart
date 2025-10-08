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

  // नया field add करें
  @HiveField(6)
  DateTime? updatedAt;

  Contact({
    required this.contactId,
    required this.ownerUserId,
    required this.contactName,
    required this.contactPhone,
    this.isOnApp = false,
    this.appUserId,
    this.updatedAt, // constructor में add करें
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
          : null, // JSON से parse करें
    );
  }
}