import 'package:hive/hive.dart';

part 'profile_setting.g.dart';

@HiveType(typeId: 0)
class ProfileSetting extends HiveObject {
  @HiveField(0)
  int? id;

  @HiveField(1)
  int? userId;

  @HiveField(2)
  String? profileImage;

  @HiveField(3)
  String? name;

  @HiveField(4)
  String? legalBusinessName;

  @HiveField(5)
  String? businessType;

  @HiveField(6)
  String? businessCategory;

  @HiveField(7)
  String? gstNo;

  @HiveField(8)
  String? phoneNumber;

  @HiveField(9)
  String? address;

  @HiveField(10)
  String? email;

  @HiveField(11)
  String? website;

  @HiveField(12)
  String? businessDescription;

  @HiveField(13)
  String? about;

  @HiveField(14)
  String? upiQrCode;

  // 🔹 extra user table fields
  @HiveField(15)
  String? userPhone;

  @HiveField(16)
  String? userName;

  ProfileSetting({
    this.id,
    this.userId,
    this.profileImage,
    this.name,
    this.legalBusinessName,
    this.businessType,
    this.businessCategory,
    this.gstNo,
    this.phoneNumber,
    this.address,
    this.email,
    this.website,
    this.businessDescription,
    this.about,
    this.upiQrCode,
    this.userPhone,
    this.userName,
  });

  factory ProfileSetting.fromJson(Map<String, dynamic> json) {
    return ProfileSetting(
      id: json["profile_id"] != null ? int.tryParse(json["profile_id"].toString()) : null,
      userId: json["user_id"] != null ? int.tryParse(json["user_id"].toString()) : null,
      profileImage: json["profile_image"],
      name: json["profile_name"],
      legalBusinessName: json["legal_business_name"],
      businessType: json["business_type"],
      businessCategory: json["business_category"],
      gstNo: json["gst_no"],
      phoneNumber: json["profile_phone"],
      address: json["address"],
      email: json["email"],
      website: json["website"],
      businessDescription: json["business_description"],
      about: json["profile_about"],
      upiQrCode: json["upi_qr_code"],

      // user table fields
      userPhone: json["user_phone"],
      userName: json["user_name"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "profile_image": profileImage,
      "name": name,
      "legal_business_name": legalBusinessName,
      "business_type": businessType,
      "business_category": businessCategory,
      "gst_no": gstNo,
      "phone_number": phoneNumber,
      "address": address,
      "email": email,
      "website": website,
      "business_description": businessDescription,
      "about": about,
      "upi_qr_code": upiQrCode,
      "user_phone": userPhone,
      "user_name": userName,
    };
  }
}
