use std::{fs, io::BufReader, path::Path};

use image::{codecs::gif::GifDecoder, AnimationDecoder, GenericImageView};
use libwebp_sys::{
    WebPAnimEncoderAdd, WebPAnimEncoderAssemble, WebPAnimEncoderDelete, WebPAnimEncoderNewInternal,
    WebPAnimEncoderOptions, WebPAnimEncoderOptionsInitInternal, WebPConfig, WebPData, WebPDataClear,
    WebPEncodeRGB, WebPEncodeRGBA, WebPFree, WebPPicture, WebPPictureFree,
    WebPPictureImportRGBA, WEBP_MUX_ABI_VERSION,
};

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

fn is_gif_path(image_path: &str) -> bool {
    Path::new(image_path)
        .extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| extension.eq_ignore_ascii_case("gif"))
}

fn get_image(image_path: String) -> ConverterResult<ImageData> {
    let path = Path::new(&image_path);
    if !path.exists() {
        return Err(ConverterError::FileNotFound);
    }

    if is_gif_path(&image_path) {
        return Err(ConverterError::ImageTypeNotSupported);
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

pub fn optimize_animated_gif_to_webp(
    input_path: String,
    output_path: String,
    min_quality: u8,
) -> ConverterResult<u8> {
    let path = Path::new(&input_path);
    if !path.exists() {
        return Err(ConverterError::FileNotFound);
    }

    let file = fs::File::open(path).map_err(|_| ConverterError::FailedToOpenImage)?;
    let decoder = GifDecoder::new(BufReader::new(file))
        .map_err(|_| ConverterError::FailedToOpenImage)?;
    let frames = decoder
        .into_frames()
        .collect_frames()
        .map_err(|_| ConverterError::FailedToOpenImage)?;

    let first_frame = frames.first().ok_or(ConverterError::FailedToOpenImage)?;
    let width = first_frame.buffer().width() as i32;
    let height = first_frame.buffer().height() as i32;

    unsafe {
        let mut options = std::mem::MaybeUninit::<WebPAnimEncoderOptions>::zeroed();
        if WebPAnimEncoderOptionsInitInternal(
            options.as_mut_ptr(),
            WEBP_MUX_ABI_VERSION as i32,
        ) == 0
        {
            return Err(ConverterError::EncodingFailed);
        }
        let options = options.assume_init();
        let encoder = WebPAnimEncoderNewInternal(
            width,
            height,
            &options,
            WEBP_MUX_ABI_VERSION as i32,
        );
        if encoder.is_null() {
            return Err(ConverterError::EncodingFailed);
        }

        let mut config = WebPConfig::new_with_preset(
            libwebp_sys::WebPPreset::WEBP_PRESET_DEFAULT,
            min_quality as f32,
        )
        .map_err(|_| ConverterError::EncodingFailed)?;
        config.lossless = 0;
        config.quality = min_quality as f32;

        let mut timestamp_ms = 0i32;
        for frame in frames {
            let delay = frame.delay();
            let rgba = frame.into_buffer();
            let mut picture = WebPPicture::new().map_err(|_| ConverterError::EncodingFailed)?;
            picture.width = width;
            picture.height = height;

            if WebPPictureImportRGBA(&mut picture, rgba.as_ptr(), width * 4) == 0 {
                WebPPictureFree(&mut picture);
                WebPAnimEncoderDelete(encoder);
                return Err(ConverterError::EncodingFailed);
            }

            if WebPAnimEncoderAdd(encoder, &mut picture, timestamp_ms, &config) == 0 {
                WebPPictureFree(&mut picture);
                WebPAnimEncoderDelete(encoder);
                return Err(ConverterError::EncodingFailed);
            }
            WebPPictureFree(&mut picture);

            let (numerator, denominator) = delay.numer_denom_ms();
            let delay_ms = if denominator == 0 {
                0
            } else {
                (u64::from(numerator) * 2 + u64::from(denominator))
                    / (u64::from(denominator) * 2)
            };
            timestamp_ms = timestamp_ms.saturating_add(delay_ms.max(1) as i32);
        }

        if WebPAnimEncoderAdd(
            encoder,
            std::ptr::null_mut(),
            timestamp_ms,
            std::ptr::null(),
        ) == 0
        {
            WebPAnimEncoderDelete(encoder);
            return Err(ConverterError::EncodingFailed);
        }

        let mut webp_data = WebPData::default();
        if WebPAnimEncoderAssemble(encoder, &mut webp_data) == 0 {
            WebPAnimEncoderDelete(encoder);
            return Err(ConverterError::EncodingFailed);
        }

        let bytes = std::slice::from_raw_parts(webp_data.bytes, webp_data.size).to_vec();
        WebPDataClear(&mut webp_data);
        WebPAnimEncoderDelete(encoder);

        fs::write(output_path, bytes).map_err(|_| ConverterError::FailedToWriteOutputFile)?;
    }

    Ok(min_quality)
}

pub fn optimize_image(
    image_path: String,
    output_path: String,
    min_quality: u8,
) -> ConverterResult<u8> {
    if is_gif_path(&image_path) {
        return optimize_animated_gif_to_webp(image_path, output_path, min_quality);
    }

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
    use super::{encode, optimize_image, ImageData, ImageType};

    #[test]
    fn encodes_rgb_images_without_crashing() {
        let image = ImageData::new(vec![255, 0, 0, 0, 255, 0], 1, 1, ImageType::Rgb);

        let result = encode(&image, 80.0);

        assert!(result.is_ok(), "expected RGB encoding to succeed");
    }

    fn anmf_durations(webp: &[u8]) -> Vec<u32> {
        let mut durations = Vec::new();
        let mut cursor = 12;

        while cursor + 8 <= webp.len() {
            let chunk_id = &webp[cursor..cursor + 4];
            let chunk_size = u32::from_le_bytes([
                webp[cursor + 4],
                webp[cursor + 5],
                webp[cursor + 6],
                webp[cursor + 7],
            ]) as usize;
            let payload_start = cursor + 8;

            if chunk_id == b"ANMF" && payload_start + 15 <= webp.len() {
                durations.push(
                    u32::from(webp[payload_start + 12])
                        | (u32::from(webp[payload_start + 13]) << 8)
                        | (u32::from(webp[payload_start + 14]) << 16),
                );
            }

            cursor = payload_start + chunk_size + (chunk_size % 2);
        }

        durations
    }

    #[test]
    fn optimizes_animated_gif_to_valid_multi_frame_webp() {
        use image::{
            codecs::gif::{GifEncoder, Repeat},
            Delay, Frame, Rgba, RgbaImage,
        };
        use std::{
            fs,
            time::{SystemTime, UNIX_EPOCH},
        };

        let test_dir = std::env::temp_dir().join(format!(
            "image_optimizer_gif_test_{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("system time should be after Unix epoch")
                .as_nanos()
        ));
        fs::create_dir_all(&test_dir).expect("test dir should be created");
        let input_path = test_dir.join("animated.gif");
        let output_path = test_dir.join("animated.webp");

        let file = fs::File::create(&input_path).expect("GIF fixture should be created");
        let mut encoder = GifEncoder::new(file);
        encoder
            .set_repeat(Repeat::Infinite)
            .expect("GIF repeat should be configured");

        let red = RgbaImage::from_pixel(2, 2, Rgba([255, 0, 0, 255]));
        let blue = RgbaImage::from_pixel(2, 2, Rgba([0, 0, 255, 255]));
        encoder
            .encode_frame(Frame::from_parts(
                red,
                0,
                0,
                Delay::from_numer_denom_ms(40, 1),
            ))
            .expect("first GIF frame should be encoded");
        encoder
            .encode_frame(Frame::from_parts(
                blue,
                0,
                0,
                Delay::from_numer_denom_ms(60, 1),
            ))
            .expect("second GIF frame should be encoded");
        drop(encoder);

        let result = optimize_image(
            input_path.to_string_lossy().into_owned(),
            output_path.to_string_lossy().into_owned(),
            80,
        );

        assert!(result.is_ok(), "expected animated GIF optimization to succeed");
        let output = fs::read(&output_path).expect("animated WebP should be written");
        assert_eq!(&output[0..4], b"RIFF");
        assert_eq!(&output[8..12], b"WEBP");
        assert!(
            output.windows(4).any(|chunk| chunk == b"ANIM"),
            "animated WebP should include an ANIM chunk"
        );
        assert!(
            output.windows(4).filter(|chunk| *chunk == b"ANMF").count() >= 2,
            "animated WebP should preserve multiple frames"
        );
        assert_eq!(anmf_durations(&output), vec![40, 60]);

        fs::remove_dir_all(test_dir).expect("test dir should be removed");
    }
}
