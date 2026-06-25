mod converter;
mod result;

use std::{ffi::CStr, os::raw::c_char};

pub use crate::{converter::optimize_image, result::ConverterError};

/// FFI-safe output structure
#[repr(C)]
pub struct OptimizeImageOutput {
    /// The quality level selected (0-100)
    pub quality: u8,
    /// Error code: 0 = success, 1-5 = errors (see optimize_image_ffi docs)
    pub error_code: i32,
}

/// Optimize an image and write it to the specified output path
///
/// # Arguments
/// * `image_path` - C string pointer to the input image file path
/// * `min_quality` - Minimum quality level (0-100)
/// * `output_path` - C string pointer to the output file path where optimized image will be written
/// * `output` - Pointer to output structure (must not be null)
///
/// # Return Value
/// Returns via the `output` parameter:
/// * `error_code = 0` on success (quality contains the selected quality level)
/// * `error_code = 1` if input file not found
/// * `error_code = 2` if failed to open input image
/// * `error_code = 3` if image type not supported
/// * `error_code = 4` if encoding failed
/// * `error_code = 5` if output file write failed
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
        return -1;
    }

    let output_path = match unsafe { CStr::from_ptr(output_path).to_str() } {
        Ok(s) => s.to_string(),
        Err(_) => return -1,
    };

    let path_cstr = match unsafe { CStr::from_ptr(image_path).to_str() } {
        Ok(s) => s.to_string(),
        Err(_) => return -1,
    };

    match optimize_image(path_cstr, output_path, min_quality) {
        Ok(quality) => {
            unsafe {
                (*output).quality = quality;
                (*output).error_code = 0;
            }
            1
        }
        Err(ConverterError::FileNotFound) => {
            unsafe {
                (*output).quality = 0;
                (*output).error_code = 1;
            }
            1
        }
        Err(ConverterError::FailedToOpenImage) => {
            unsafe {
                (*output).quality = 0;
                (*output).error_code = 2;
            }
            2
        }
        Err(ConverterError::ImageTypeNotSupported) => {
            unsafe {
                (*output).quality = 0;
                (*output).error_code = 3;
            }
            3
        }
        Err(ConverterError::EncodingFailed) => {
            unsafe {
                (*output).quality = 0;
                (*output).error_code = 4;
            }
            4
        }
        Err(ConverterError::FailedToWriteOutputFile) => {
            unsafe {
                (*output).quality = 0;
                (*output).error_code = 5;
            }
            5
        }
    }
}

#[cfg(test)]
mod tests {
    use super::{optimize_image_ffi, OptimizeImageOutput};
    use std::{ffi::CString, ptr};

    #[test]
    fn returns_error_for_null_output_path() {
        let image_path = CString::new("input.png").expect("valid C string");
        let mut output = OptimizeImageOutput {
            quality: 0,
            error_code: 0,
        };

        let result = optimize_image_ffi(
            image_path.as_ptr(),
            80,
            ptr::null(),
            &mut output as *mut OptimizeImageOutput,
        );

        assert_eq!(result, -1);
    }
}
