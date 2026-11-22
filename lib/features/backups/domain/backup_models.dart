class BackupMetadata {
  const BackupMetadata({
    required this.path,
    required this.createdAt,
    required this.fileSize,
    required this.schemaVersion,
    required this.invoiceCount,
    required this.customerCount,
    required this.paymentCount,
  });

  final String path;
  final DateTime createdAt;
  final int fileSize;
  final int schemaVersion;
  final int invoiceCount;
  final int customerCount;
  final int paymentCount;
}

class BackupHistoryEntry {
  const BackupHistoryEntry({
    required this.path,
    required this.createdAt,
    required this.fileSize,
    required this.type,
    required this.integrityStatus,
  });

  final String path;
  final DateTime createdAt;
  final int fileSize;
  final String type;
  final String integrityStatus;
}

class BackupStatus {
  const BackupStatus({
    required this.destination,
    required this.lastSuccessfulAt,
    required this.history,
  });

  final String destination;
  final DateTime? lastSuccessfulAt;
  final List<BackupHistoryEntry> history;

  bool get isHealthy =>
      lastSuccessfulAt != null &&
      DateTime.now().difference(lastSuccessfulAt!).inHours < 48;
}

class BackupException implements Exception {
  const BackupException(this.message, {this.technicalDetails});

  final String message;
  final String? technicalDetails;

  @override
  String toString() => message;
}
