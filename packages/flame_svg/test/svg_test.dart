import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame_svg/svg.dart' as flame_svg;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart';

class _SvgPainter extends CustomPainter {
  final flame_svg.Svg svg;

  _SvgPainter(this.svg);

  @override
  void paint(Canvas canvas, Size size) {
    svg.render(canvas, Vector2(size.width, size.height));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

/// A [BytesLoader] that loads vector graphics from a file path (for testing).
class _FileBytesLoader extends BytesLoader {
  const _FileBytesLoader(this.path);

  final String path;

  @override
  Future<ByteData> loadBytes(BuildContext? context) async {
    final bytes = File(path).readAsBytesSync();
    return ByteData.view(bytes.buffer);
  }

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) {
    return other is _FileBytesLoader && other.path == path;
  }
}

Future<flame_svg.Svg> _parseSvgFromTestFile(String path) async {
  final pictureInfo = await vg.loadPicture(_FileBytesLoader(path), null);
  return flame_svg.Svg(pictureInfo);
}

void main() {
  group('Svg', () {
    late flame_svg.Svg svgInstance;

    setUp(() async {
      svgInstance =
          await _parseSvgFromTestFile('test/_resources/android.svg.vec');
    });

    test('multiple calls to dispose should not throw error', () async {
      svgInstance.render(Canvas(PictureRecorder()), Vector2.all(100));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      svgInstance.dispose();
      svgInstance.dispose();
    });

    testWidgets(
      'render sharply',
      (tester) async {
        final flameSvg = await _parseSvgFromTestFile(
          'test/_resources/hand.svg.vec',
        );
        flameSvg.render(Canvas(PictureRecorder()), Vector2.all(300));
        await tester.binding.setSurfaceSize(const Size(800, 600));
        tester.view.devicePixelRatio = 3;
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: CustomPaint(
                  size: const Size(300, 300),
                  painter: _SvgPainter(flameSvg),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('./_goldens/render_sharply.png'),
        );
      },
    );

    testWidgets(
      'render sharply with viewfinder zoom',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });

        final flameSvg = await _parseSvgFromTestFile(
          'test/_resources/hand.svg.vec',
        );

        tester.view.devicePixelRatio = 1;
        await tester.binding.setSurfaceSize(const Size(100, 100));

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Transform.scale(
              scale: 2,
              child: CustomPaint(
                painter: _SvgPainter(flameSvg),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            './_goldens/render_sharply_with_viewfinder_zoom.png',
          ),
        );
      },
    );
  });
}
