class CompanySettings {
  const CompanySettings({
    required this.companyName,
    required this.ownerName,
    required this.primaryPhone,
    required this.secondaryPhone,
    required this.additionalContactName,
    required this.additionalContactPhone,
    required this.email,
    required this.address,
    this.logoPath,
  });

  factory CompanySettings.fromMap(Map<String, Object?> map) => CompanySettings(
    companyName: map['company_name']! as String,
    ownerName: map['owner_name']! as String,
    primaryPhone: map['primary_phone']! as String,
    secondaryPhone: map['secondary_phone']! as String,
    additionalContactName: map['additional_contact_name']! as String,
    additionalContactPhone: map['additional_contact_phone']! as String,
    email: map['email']! as String,
    address: map['address']! as String,
    logoPath: map['logo_path'] as String?,
  );

  final String companyName;
  final String ownerName;
  final String primaryPhone;
  final String secondaryPhone;
  final String additionalContactName;
  final String additionalContactPhone;
  final String email;
  final String address;
  final String? logoPath;

  Map<String, Object?> toUpdateMap() => {
    'company_name': companyName.trim(),
    'owner_name': ownerName.trim(),
    'primary_phone': primaryPhone.trim(),
    'secondary_phone': secondaryPhone.trim(),
    'additional_contact_name': additionalContactName.trim(),
    'additional_contact_phone': additionalContactPhone.trim(),
    'email': email.trim(),
    'address': address.trim(),
    'logo_path': logoPath,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}
