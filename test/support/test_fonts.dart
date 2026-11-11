import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as font_loader;
import 'package:google_fonts/src/google_fonts_descriptor.dart';
import 'package:google_fonts/src/google_fonts_family_with_variant.dart';
import 'package:google_fonts/src/google_fonts_variant.dart';

class _FontManifest extends Fake implements AssetManifest {
  final List<String> paths;
  _FontManifest(this.paths);
  @override
  List<String> listAssets() => paths;
}

Future<void> prepareTestFonts() async {
  final variants = [
    for (final weight in FontWeight.values)
      GoogleFontsFamilyWithVariant(
          family: 'Poppins',
          googleFontsVariant: GoogleFontsVariant(
              fontWeight: weight, fontStyle: FontStyle.normal))
  ];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  font_loader.assetManifest = _FontManifest([
    for (final variant in variants) '${variant.toApiFilenamePrefix()}.ttf',
  ]);
  messenger.setMockMessageHandler('flutter/assets', (_) async => ByteData(0));
  for (final variant in variants) {
    await font_loader.loadFontIfNecessary(GoogleFontsDescriptor(
        familyWithVariant: variant, file: GoogleFontsFile('', 0)));
  }
  messenger.setMockMessageHandler('flutter/assets', null);
  font_loader.assetManifest = null;
}
