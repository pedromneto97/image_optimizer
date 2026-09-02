#[derive(Debug)]
#[repr(C)]
pub enum ConverterError {
    FileNotFound,
    FailedToOpenImage,
    ImageTypeNotSupported,
    EncodingFailed,
    FailedToWriteOutputFile,
    FailedToDecodeAnimation,
    AnimationEncodingFailed,
}

impl ConverterError {
    /// Error code reported across the FFI boundary.
    ///
    /// Kept exhaustive on purpose: adding a variant must be a compile error
    /// here so the Dart side (`_throwExceptionFromCode`) is updated with it.
    pub const fn code(&self) -> i32 {
        match self {
            Self::FileNotFound => 1,
            Self::FailedToOpenImage => 2,
            Self::ImageTypeNotSupported => 3,
            Self::EncodingFailed => 4,
            Self::FailedToWriteOutputFile => 5,
            Self::FailedToDecodeAnimation => 6,
            Self::AnimationEncodingFailed => 7,
        }
    }
}

/// Result of a successful optimization.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct OptimizationOutcome {
    /// The quality level the sweep settled on (0-100).
    pub quality: u8,
    /// Number of frames written to the output. 1 for a still image.
    pub frame_count: u32,
}

pub type ConverterResult<T> = Result<T, ConverterError>;
