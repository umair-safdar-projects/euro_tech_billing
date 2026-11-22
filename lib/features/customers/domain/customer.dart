class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.notes,
  });

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
    id: map['id']! as int,
    name: map['name']! as String,
    phone: map['phone']! as String,
    address: map['address']! as String,
    notes: map['notes']! as String,
  );

  final int id;
  final String name;
  final String phone;
  final String address;
  final String notes;
}

class CustomerInput {
  const CustomerInput({
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
  });

  final String name;
  final String phone;
  final String address;
  final String notes;

  void validate() {
    if (name.trim().isEmpty) {
      throw const FormatException('Customer name is required.');
    }
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (normalizedPhone.isNotEmpty &&
        !RegExp(r'^\d{7,15}$').hasMatch(normalizedPhone)) {
      throw const FormatException(
        'Enter a valid phone number with 7 to 15 digits.',
      );
    }
  }
}
