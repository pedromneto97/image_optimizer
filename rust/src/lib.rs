mod converter;
mod result;

use std::{ffi::CStr, os::raw::c_char};

pub use crate::{
    converter::optimize_image,
    result::{ConverterError, OptimizationOutcome},
};

/// FFI-safe output structure
#[repr(C)]
pub struct OptimizeImageOutput {
    /// The quality level selected (0-100)
    pub quality: u8,
    /// Number of frames written to the output. 1 for a still image, N for an
    /// animated WebP produced from an animated GIF.
    pub frame_count: u32,
    /// Error code: 0 = success, 1-7 = errors (see optimize_image_ffi docs)
    pub error_code: i32,
}

/// Write the result back through the output pointer and return the error code.
///
/// # Safety
/// * `output` must be a valid, non-null pointer to an OptimizeImageOutput struct
unsafe fn write_output(
    output: *mut OptimizeImageOutput,
    quality: u8,
    frame_count: u32,
    error_code: i32,
) -> i32 {
    unsafe {
        (*output).quality = quality;
        (*output).frame_count = frame_count;
        (*output).error_code = error_code;
    }

    error_code
}

/// Optimize an image and write it to the specified output path
///
/// Animated GIFs are converted to animated WebP, preserving frame delays and
/// loop count. Every other supported input produces a still WebP.
///
/// # Arguments
/// * `image_path` - C string pointer to the input image file path
/// * `min_quality` - Minimum quality level (0-100)
/// * `output_path` - C string pointer to the output file path where optimized image will be written
/// * `output` - Pointer to output structure (must not be null)
///
/// # Return Value
/// Returns via the `output` parameter:
/// * `error_code = 0` on success (quality contains the selected quality level,
///   frame_count the number of frames written)
/// * `error_code = 1` if input file not found
/// * `error_code = 2` if failed to open input image
/// * `error_code = 3` if image type not supported
/// * `error_code = 4` if encoding failed
/// * `error_code = 5` if output file write failed
/// * `error_code = 6` if the animation frames could not be decoded
/// * `error_code = 7` if animated WebP encoding failed (also reported when the
///   canvas exceeds the 16383x16383 WebP limit)
/// * `error_code = -1` if parameters are invalid (null pointers)
///
/// # Safety
/// * `image_path` must be a valid, null-terminated C string
/// * `output_path` must be a valid, null-terminated C string
/// * `output` must be a valid, non-null pointer to an OptimizeImageOutput struct
#[unsafe(no_mangle)]
pub extern "C" fn optimize_image_ffi(
    image_path: *const c_char,
    min_quality: u8,
    output_path: *const c_char,
    output: *mut OptimizeImageOutput,
) -> i32 {
    if image_path.is_null() || output_path.is_null() || output.is_null() {
        if !output.is_null() {
            unsafe {
                write_output(output, 0, 0, -1);
            }
        }
        return -1;
    }

    let output_path = match unsafe { CStr::from_ptr(output_path).to_str() } {
        Ok(s) => s.to_string(),
        Err(_) => return unsafe { write_output(output, 0, 0, -1) },
    };

    let path_cstr = match unsafe { CStr::from_ptr(image_path).to_str() } {
        Ok(s) => s.to_string(),
        Err(_) => return unsafe { write_output(output, 0, 0, -1) },
    };

    match optimize_image(path_cstr, output_path, min_quality) {
        Ok(outcome) => unsafe { write_output(output, outcome.quality, outcome.frame_count, 0) },
        // The code table lives on ConverterError and is exhaustive, so a new
        // variant is a compile error there rather than a silent 0 here.
        Err(error) => unsafe { write_output(output, 0, 0, error.code()) },
    }
}

#[cfg(test)]
mod tests {
    use super::{ConverterError, OptimizeImageOutput, optimize_image_ffi};
    use std::{ffi::CString, ptr};

    fn empty_output() -> OptimizeImageOutput {
        OptimizeImageOutput {
            quality: 0,
            frame_count: 0,
            error_code: 0,
        }
    }

    #[test]
    fn returns_error_for_null_output_path() {
        let image_path = CString::new("input.png").expect("valid C string");
        let mut output = empty_output();

        let result = optimize_image_ffi(image_path.as_ptr(), 80, ptr::null(), &mut output);

        assert_eq!(result, -1);
        assert_eq!(output.error_code, -1);
    }

    #[test]
    fn returns_error_for_null_image_path() {
        let output_path = CString::new("output.webp").expect("valid C string");
        let mut output = empty_output();

        let result = optimize_image_ffi(ptr::null(), 80, output_path.as_ptr(), &mut output);

        assert_eq!(result, -1);
        assert_eq!(output.error_code, -1);
    }

    #[test]
    fn does_not_dereference_a_null_output_struct() {
        let image_path = CString::new("input.png").expect("valid C string");
        let output_path = CString::new("output.webp").expect("valid C string");

        let result = optimize_image_ffi(
            image_path.as_ptr(),
            80,
            output_path.as_ptr(),
            ptr::null_mut(),
        );

        assert_eq!(result, -1);
    }

    #[test]
    fn reports_missing_input_through_the_output_struct() {
        let image_path = CString::new("definitely-not-a-real-file.png").expect("valid C string");
        let output_path = CString::new("output.webp").expect("valid C string");
        let mut output = empty_output();

        let result = optimize_image_ffi(image_path.as_ptr(), 80, output_path.as_ptr(), &mut output);

        assert_eq!(result, 1);
        assert_eq!(output.error_code, 1);
        assert_eq!(output.frame_count, 0);
    }

    #[test]
    fn error_codes_match_the_dart_switch() {
        assert_eq!(ConverterError::FileNotFound.code(), 1);
        assert_eq!(ConverterError::FailedToOpenImage.code(), 2);
        assert_eq!(ConverterError::ImageTypeNotSupported.code(), 3);
        assert_eq!(ConverterError::EncodingFailed.code(), 4);
        assert_eq!(ConverterError::FailedToWriteOutputFile.code(), 5);
        assert_eq!(ConverterError::FailedToDecodeAnimation.code(), 6);
        assert_eq!(ConverterError::AnimationEncodingFailed.code(), 7);
    }
}
