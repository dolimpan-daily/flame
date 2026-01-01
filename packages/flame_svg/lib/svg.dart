import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:vector_graphics/vector_graphics.dart';

/// A [Svg] to be rendered on a Flame [Game].
class Svg {
  /// Creates an [Svg] with the received [pictureInfo].
  /// Default [pixelRatio] is the device pixel ratio.
  Svg(this.pictureInfo, {double? pixelRatio})
    : pixelRatio =
          pixelRatio ??
          WidgetsBinding
              .instance
              .platformDispatcher
              .views
              .first
              .devicePixelRatio;

  /// The [PictureInfo] that this [Svg] represents.
  final PictureInfo pictureInfo;

  /// The pixel ratio that this [Svg] is rendered based on.
  final double pixelRatio;

  final MemoryCache<Size, Image> _imageCache = MemoryCache();

  final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Loads an [Svg] from a pre-compiled vector graphics file (.svg.vec).
  ///
  /// The [fileName] should be the path to a pre-compiled .svg.vec file.
  /// Use `vector_graphics_compiler` to compile SVG files:
  /// ```bash
  /// dart run vector_graphics_compiler -i input.svg -o output.svg.vec
  /// ```
  static Future<Svg> load(
    String fileName, {
    double? pixelRatio,
  }) async {
    final pictureInfo = await vg.loadPicture(AssetBytesLoader(fileName), null);
    return Svg(
      pictureInfo,
      pixelRatio: pixelRatio,
    );
  }

  /// Renders the svg on the [canvas] using the dimensions provided by [size].
  void render(
    Canvas canvas,
    Vector2 size, {
    Paint? overridePaint,
  }) {
    // Scale the canvas to the size of the destination clip bounds
    // This is necessary to avoid blurriness when having a
    // camera.viewfinder.zoom larger than 1.0
    final destinationClipBounds = canvas.getDestinationClipBounds();
    final localClipBounds = canvas.getLocalClipBounds();
    final widthRatio =
        destinationClipBounds.size.width / localClipBounds.size.width;
    final heightRatio =
        destinationClipBounds.size.height / localClipBounds.size.height;

    final localSize = Size(size.x, size.y);
    final image = _getImage(localSize, widthRatio, heightRatio);

    canvas.save();
    canvas.scale(
      1 / (pixelRatio * widthRatio),
      1 / (pixelRatio * heightRatio),
    );
    canvas.drawImage(
      image,
      Offset.zero,
      overridePaint ?? _paint,
    );
    canvas.restore();
  }

  /// Renders the svg on the [canvas] on the given [position] using the
  /// dimensions provided by [size].
  void renderPosition(
    Canvas canvas,
    Vector2 position,
    Vector2 size,
  ) {
    canvas.renderAt(position, (c) => render(c, size));
  }

  Image _getImage(Size size, double widthRatio, double heightRatio) {
    final cacheKey = Size(size.width * widthRatio, size.height * heightRatio);
    final image = _imageCache.getValue(cacheKey);

    if (image == null) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.scale(pixelRatio * widthRatio, pixelRatio * heightRatio);
      _render(canvas, size);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(
        (size.width * pixelRatio * widthRatio).ceil(),
        (size.height * pixelRatio * heightRatio).ceil(),
      );

      picture.dispose();
      _imageCache.setValue(cacheKey, image);
      return image;
    }

    return image;
  }

  void _render(Canvas canvas, Size size) {
    final scale = math.min(
      size.width / pictureInfo.size.width,
      size.height / pictureInfo.size.height,
    );
    canvas.translate(
      (size.width - pictureInfo.size.width * scale) / 2,
      (size.height - pictureInfo.size.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);
  }

  /// Clear all the stored cache from this SVG, be sure to call
  /// this method once the instance is no longer needed to avoid
  /// memory leaks
  void dispose() {
    _imageCache.keys.forEach((key) {
      _imageCache.getValue(key)?.dispose();
    });
    _imageCache.clearCache();
  }
}

/// Provides a loading method for [Svg] on the [Game] class.
extension SvgLoader on Game {
  /// Loads an [Svg] from a pre-compiled vector graphics file (.svg.vec).
  Future<Svg> loadSvg(String fileName) => Svg.load(fileName);
}
