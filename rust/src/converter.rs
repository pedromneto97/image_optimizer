use std::{fs, path::Path};

use image::GenericImageView;
use libwebp_sys::{WebPEncodeRGB, WebPEncodeRGBA, WebPFree};

use crate::result::{ConverterError, ConverterResult};

enum ImageType {
    Rgb,
    Rgba,
}

struct ImageData {
    data: Vec<u8>,
    width: u32,
    height: u32,
    image_type: ImageType,
}

impl ImageData {
    fn new(data: Vec<u8>, width: u32, height: u32, image_type: ImageType) -> Self {
        Self {
            data,
            width,
            height,
            image_type,
        }
    }
}

fn get_image(image_path: String) -> ConverterResult<ImageData> {
    let path = Path::new(&image_path);
    if !path.exists() {
        return Err(ConverterError::FileNotFound);
    }

    let img = image::open(image_path).map_err(|_| ConverterError::FailedToOpenImage)?;

    let (width, height) = img.dimensions();
    let image_type = match img.color() {
        image::ColorType::Rgb8 => ImageType::Rgb,
        image::ColorType::Rgba8 => ImageType::Rgba,
        _ => {
            return Err(ConverterError::ImageTypeNotSupported);
        }
    };
    Ok(ImageData::new(
        img.as_bytes().to_vec(),
        width,
        height,
        image_type,
    ))
}

struct WebPBuffer {
    ptr: *mut u8,
}

impl WebPBuffer {
    fn new(ptr: *mut u8) -> Self {
        Self { ptr }
    }
}

impl Drop for WebPBuffer {
    fn drop(&mut self) {
        if !self.ptr.is_null() {
            unsafe {
                WebPFree(self.ptr.cast());
            }
        }
    }
}

fn encode(image: &ImageData, quality: f32) -> ConverterResult<Vec<u8>> {
    let mut out_buf = std::ptr::null_mut();

    unsafe {
        let len = match image.image_type {
            ImageType::Rgb => WebPEncodeRGB(
                image.data.as_ptr(),
                image.width as i32,
                image.height as i32,
                image.width as i32 * 3,
                quality,
                &mut out_buf,
            ),
            ImageType::Rgba => WebPEncodeRGBA(
                image.data.as_ptr(),
                image.width as i32,
                image.height as i32,
                image.width as i32 * 4,
                quality,
                &mut out_buf,
            ),
        };

        if len == 0 {
            return Err(ConverterError::EncodingFailed);
        }

        let buffer = WebPBuffer::new(out_buf);
        let bytes = std::slice::from_raw_parts(buffer.ptr, len).to_vec();

        Ok(bytes)
    }
}

pub fn optimize_image(
    image_path: String,
    output_path: String,
    min_quality: u8,
) -> ConverterResult<u8> {
    let image_data = get_image(image_path)?;

    // Test quality levels in range, find best compression/quality ratio
    let mut best_result = None;
    let mut best_quality = min_quality;
    let mut best_score = f32::MAX; // Lower score = better

    for quality in (min_quality..=100).step_by(2) {
        let encoded = encode(&image_data, quality as f32)?;
        let size = encoded.len() as f32;

        // Score: bytes per quality point. Lower = better compression at target quality
        let score = size / quality as f32;

        if score < best_score {
            best_score = score;
            best_result = Some(encoded);
            best_quality = quality;
        }
    }

    let best_result = best_result.ok_or(ConverterError::EncodingFailed)?;

    fs::write(output_path, best_result).map_err(|_| ConverterError::FailedToWriteOutputFile)?;

    Ok(best_quality)
}

#[cfg(test)]
mod tests {
    use super::{ImageData, ImageType, encode};

    #[test]
    fn encodes_rgb_images_without_crashing() {
        let image = ImageData::new(vec![255, 0, 0, 0, 255, 0], 1, 1, ImageType::Rgb);

        let result = encode(&image, 80.0);

        assert!(result.is_ok(), "expected RGB encoding to succeed");
    }
}
