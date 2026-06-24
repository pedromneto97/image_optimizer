#[derive(Debug)]
#[repr(C)]
pub enum ConverterError {
    FileNotFound,
    FailedToOpenImage,
    ImageTypeNotSupported,
    EncodingFailed,
    FailedToWriteOutputFile,
}

pub type ConverterResult<T> = Result<T, ConverterError>;
