import '../../../domain/exceptions.dart';

String imageOptimizerErrorMessage(Exception exception) => switch (exception) {
  InputImageNotFoundException() => 'Input image file was not found.',
  InputImageOpenException() => 'Failed to open the input image.',
  UnsupportedImageTypeException() => 'This image type is not supported.',
  WebPEncodingException() => 'WebP encoding failed.',
  OutputImageWriteException() => 'The optimized image could not be written.',
  AnimationDecodingException() =>
    'The animation frames could not be read. The file may be corrupt.',
  // Seven different libwebp failures share this code, so the message can
  // suggest the likely cause but must not assert it.
  AnimationEncodingException() =>
    'Animated WebP encoding failed. The image may be too large (WebP '
        'supports up to 16383 pixels per side) or the encoder may have run '
        'out of memory.',
  InvalidOptimizerParametersException() =>
    'Invalid optimizer parameters were provided.',
  MissingOutputImageException() =>
    'The optimizer finished, but the output file was not created.',
  UnexpectedOptimizationFailureException(:final error) =>
    'Image optimization stopped unexpectedly: $error',
  UnknownImageOptimizationException(:final code) =>
    'Image optimization failed with error code $code.',

  _ => 'Image optimization failed: $exception',
};
