import 'dart:io';

import 'package:image/image.dart';

void main() {
  const sourcePath = 'assets/branding/euro_tech_icon_256.png';
  const outputPath = 'windows/runner/resources/app_icon.ico';
  final source = decodePng(File(sourcePath).readAsBytesSync());
  if (source == null) throw StateError('Could not decode $sourcePath');
  final frames = <Image>[
    for (final size in [16, 24, 32, 48, 64, 128, 256])
      copyResize(
        source,
        width: size,
        height: size,
        interpolation: Interpolation.cubic,
      ),
  ];
  final icon = Image.from(frames.first);
  for (final frame in frames.skip(1)) {
    icon.addFrame(frame);
  }
  File(outputPath).writeAsBytesSync(encodeIco(icon), flush: true);
  stdout.writeln(outputPath);
}
