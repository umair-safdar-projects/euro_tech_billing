import 'dart:io';

import 'package:image/image.dart';

void main() {
  const sourcePath = 'assets/branding/euro_tech_logo.png';
  const outputPath = 'windows/runner/resources/app_icon.ico';
  final source = decodePng(File(sourcePath).readAsBytesSync());
  if (source == null) throw StateError('Could not decode $sourcePath');

  // The supplied artwork contains the wordmark above the symbol. Windows
  // renders the smallest icon sizes at 16-32 pixels, so use the symbol as the
  // application mark while retaining the exact supplied gold artwork.
  final mark = copyCrop(source, x: 170, y: 270, width: 660, height: 660);
  final canvas = Image(width: 256, height: 256, numChannels: 4);
  fill(canvas, color: ColorRgba8(16, 42, 67, 255));
  compositeImage(
    canvas,
    copyResize(
      mark,
      width: 196,
      height: 196,
      interpolation: Interpolation.cubic,
    ),
    dstX: 30,
    dstY: 30,
  );
  final branded = copyCrop(
    canvas,
    x: 0,
    y: 0,
    width: 256,
    height: 256,
    radius: 34,
  );
  File(
    'assets/branding/euro_tech_icon_256.png',
  ).writeAsBytesSync(encodePng(branded), flush: true);
  final frames = <Image>[
    for (final size in [16, 24, 32, 48, 64, 128, 256])
      copyResize(
        branded,
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
