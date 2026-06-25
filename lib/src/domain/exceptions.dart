sealed class ImageOptimizationException implements Exception {
  const ImageOptimizationException();
}

class InputImageNotFoundException extends ImageOptimizationException {
  const InputImageNotFoundException();
}

class InputImageOpenException extends ImageOptimizationException {
  const InputImageOpenException();
}

class UnsupportedImageTypeException extends ImageOptimizationException {
  const UnsupportedImageTypeException();
}

class WebPEncodingException extends ImageOptimizationException {
  const WebPEncodingException();
}

class OutputImageWriteException extends ImageOptimizationException {
  const OutputImageWriteException();
}

class InvalidOptimizerParametersException extends ImageOptimizationException {
  const InvalidOptimizerParametersException();
}

class MissingOutputImageException extends ImageOptimizationException {
  const MissingOutputImageException();
}

class UnknownImageOptimizationException extends ImageOptimizationException {
  const UnknownImageOptimizationException(this.code);

  final int code;
}
