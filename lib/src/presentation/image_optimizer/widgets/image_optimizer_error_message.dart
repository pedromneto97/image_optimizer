import '../../../domain/exceptions.dart';

String imageOptimizerErrorMessage(Exception exception) => switch (exception) {
  InputImageNotFoundException() => 'Input image file was not found.',
  InputImageOpenException() => 'Failed to open the input image.',
  UnsupportedImageTypeException() => 'This image type is not supported.',
  WebPEncodingException() => 'WebP encoding failed.',
  OutputImageWriteException() => 'The optimized image could not be written.',
  AnimationDecodingException() =>
    'The animation frames could not be read. The file may be corrupt.',
  AnimationEncodingException() =>
    'Animated WebP encoding failed. The image may be too large '
        '(WebP supports up to 16383 pixels per side).',
  InvalidOptimizerParametersException() =>
    'Invalid optimizer parameters were provided.',
  MissingOutputImageException() =>
    'The optimizer finished, but the output file was not created.',
  UnknownImageOptimizationException(:final code) =>
    'Image optimization failed with error code $code.',

  _ => 'Image optimization failed: $exception',
};
