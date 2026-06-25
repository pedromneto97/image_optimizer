import '../../../domain/exceptions.dart';
import '../cubit/image_optimizer_cubit.dart';

String imageOptimizerErrorMessage(Exception exception) => switch (exception) {
  InputImageNotFoundException() => 'Input image file was not found.',
  InputImageOpenException() => 'Failed to open the input image.',
  UnsupportedImageTypeException() => 'This image type is not supported.',
  WebPEncodingException() => 'WebP encoding failed.',
  OutputImageWriteException() => 'The optimized image could not be written.',
  InvalidOptimizerParametersException() =>
    'Invalid optimizer parameters were provided.',
  MissingOutputImageException() =>
    'The optimizer finished, but the output file was not created.',
  UnknownImageOptimizationException(:final code) =>
    'Image optimization failed with error code $code.',
  ImageNotSelectedException() => 'Choose an image before optimizing.',
  _ => 'Image optimization failed: $exception',
};
