import 'dart:math';

abstract final class SubmissionToken {
  static final Random _random = Random.secure();

  static String create() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final random = List.generate(
      4,
      (_) => _random.nextInt(0x7fffffff).toRadixString(36),
    ).join();
    return '$time-$random';
  }
}
