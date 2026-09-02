use std::{
    fs::{self, File},
    io::BufReader,
    path::Path,
};

use image::{
    AnimationDecoder, Delay, GenericImageView, ImageDecoder, ImageFormat, ImageReader,
    codecs::gif::GifDecoder, metadata::LoopCount,
};
use libwebp_sys::{
    WEBP_MAX_DIMENSION, WebPAnimEncoder as WebPAnimEncoderHandle, WebPAnimEncoderAdd,
    WebPAnimEncoderAssemble, WebPAnimEncoderDelete, WebPAnimEncoderNewInternal,
    WebPAnimEncoderOptions, WebPAnimEncoderOptionsInitInternal, WebPConfig, WebPData,
    WebPDataClear, WebPEncodeRGB, WebPEncodeRGBA, WebPFree, WebPGetMuxABIVersion, WebPPicture,
    WebPPictureFree, WebPPictureImportRGBA,
};

use crate::result::{ConverterError, ConverterResult, OptimizationOutcome};

/// Quality step used when sweeping a still image.
const STILL_QUALITY_STEP: u8 = 2;

/// Upper bound on how many full-animation encodes a GIF conversion performs.
/// Every candidate re-encodes *every* frame, so this is what keeps a 200-frame
/// GIF from turning into thousands of frame encodes.
const MAX_ANIMATION_CANDIDATES: u8 = 4;

/// A GIF frame with no delay would collapse into a zero-duration WebP frame,
/// so give it the same floor browsers apply.
const MIN_FRAME_DURATION_MS: i32 = 10;

/// WebP stores the loop count in 16 bits (libwebp rejects anything larger).
const MAX_LOOP_COUNT: u32 = u16::MAX as u32;

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

fn detect_format(image_path: &str) -> ConverterResult<Option<ImageFormat>> {
    // Sniff the magic bytes rather than trusting the extension: the picker
    // hands back the original filename, and a GIF named .jpg should still
    // animate.
    let reader = ImageReader::open(image_path)
        .map_err(|_| ConverterError::FailedToOpenImage)?
        .with_guessed_format()
        .map_err(|_| ConverterError::FailedToOpenImage)?;

    Ok(reader.format())
}

fn get_image(image_path: &str) -> ConverterResult<ImageData> {
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

fn open_gif(image_path: &str) -> ConverterResult<GifDecoder<BufReader<File>>> {
    let file = File::open(image_path).map_err(|_| ConverterError::FailedToOpenImage)?;

    GifDecoder::new(BufReader::new(file)).map_err(|_| ConverterError::FailedToDecodeAnimation)
}

/// How long a frame stays on screen, in milliseconds.
///
/// GIF delays are whole centiseconds, so the millisecond conversion is exact.
fn frame_duration_ms(delay: Delay) -> i32 {
    let (numerator, denominator) = delay.numer_denom_ms();
    let duration = if denominator == 0 {
        0
    } else {
        (numerator / denominator).min(i32::MAX as u32) as i32
    };

    duration.max(MIN_FRAME_DURATION_MS)
}

/// Whether libwebp can build a canvas this size.
///
/// `WebPAnimEncoderNewInternal` only rejects on total *area*, not on the
/// per-axis limit, so a 20000x100 GIF would sail past it and fail much later
/// with an opaque error.
fn canvas_is_encodable(width: u32, height: u32) -> bool {
    width > 0 && height > 0 && width <= WEBP_MAX_DIMENSION && height <= WEBP_MAX_DIMENSION
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

/// Owns a `WebPAnimEncoder` so the `?` early returns below cannot leak it.
struct AnimEncoder {
    ptr: *mut WebPAnimEncoderHandle,
}

impl AnimEncoder {
    fn new(width: u32, height: u32, options: &WebPAnimEncoderOptions) -> ConverterResult<Self> {
        let ptr = unsafe {
            WebPAnimEncoderNewInternal(width as i32, height as i32, options, WebPGetMuxABIVersion())
        };

        if ptr.is_null() {
            return Err(ConverterError::AnimationEncodingFailed);
        }

        Ok(Self { ptr })
    }
}

impl Drop for AnimEncoder {
    fn drop(&mut self) {
        unsafe {
            WebPAnimEncoderDelete(self.ptr);
        }
    }
}

/// Owns the pixel memory `WebPPictureImportRGBA` allocates.
struct Picture {
    inner: WebPPicture,
}

impl Picture {
    /// Builds an ARGB picture from a tightly packed RGBA8 buffer.
    ///
    /// `width`/`height` describe `rgba` itself, never the canvas it will be
    /// drawn onto: libwebp reads `height` rows of `width * 4` bytes straight
    /// off the pointer, so a buffer smaller than that is an out-of-bounds
    /// read. The dimension check also keeps the stride inside `i32`.
    fn from_rgba(rgba: &[u8], width: u32, height: u32) -> ConverterResult<Self> {
        if !canvas_is_encodable(width, height) {
            return Err(ConverterError::AnimationEncodingFailed);
        }

        // Both axes are inside libwebp's limit by now, so this cannot overflow.
        if rgba.len() < width as usize * height as usize * 4 {
            return Err(ConverterError::AnimationEncodingFailed);
        }

        let mut inner = WebPPicture::new().map_err(|_| ConverterError::AnimationEncodingFailed)?;
        inner.use_argb = 1;
        inner.width = width as i32;
        inner.height = height as i32;

        // Wrap before importing: the import allocates internally and can still
        // fail afterwards, so Drop has to be on the hook by then.
        let mut picture = Self { inner };
        let imported =
            unsafe { WebPPictureImportRGBA(&mut picture.inner, rgba.as_ptr(), width as i32 * 4) };

        if imported == 0 {
            return Err(ConverterError::AnimationEncodingFailed);
        }

        Ok(picture)
    }
}

impl Drop for Picture {
    fn drop(&mut self) {
        unsafe {
            WebPPictureFree(&mut self.inner);
        }
    }
}

/// Owns the bitstream `WebPAnimEncoderAssemble` hands back.
struct AnimData {
    inner: WebPData,
}

impl AnimData {
    fn new() -> Self {
        Self {
            inner: WebPData::default(),
        }
    }

    fn to_vec(&self) -> Vec<u8> {
        if self.inner.bytes.is_null() || self.inner.size == 0 {
            return Vec::new();
        }

        unsafe { std::slice::from_raw_parts(self.inner.bytes, self.inner.size) }.to_vec()
    }
}

impl Drop for AnimData {
    fn drop(&mut self) {
        unsafe {
            WebPDataClear(&mut self.inner);
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

struct EncodedAnimation {
    bytes: Vec<u8>,
    frame_count: u32,
}

/// Encodes the whole GIF at `image_path` as one animated WebP at `quality`.
///
/// Re-decodes the GIF on every call rather than caching frames. Holding them
/// would cost `width * height * 4 * frames` — 1.6 GB for a 1080p 200-frame GIF
/// — while a GIF decode is cheap next to the WebP encode it feeds.
fn encode_animation(image_path: &str, quality: f32) -> ConverterResult<EncodedAnimation> {
    let decoder = open_gif(image_path)?;
    let (width, height) = decoder.dimensions();

    if !canvas_is_encodable(width, height) {
        return Err(ConverterError::AnimationEncodingFailed);
    }

    let loop_count = match decoder.loop_count() {
        LoopCount::Infinite => 0,
        LoopCount::Finite(times) => times.get().min(MAX_LOOP_COUNT) as i32,
    };

    let mut config = WebPConfig::new().map_err(|_| ConverterError::AnimationEncodingFailed)?;
    config.quality = quality;

    // Every field is a plain integer, so an all-zero value is a valid
    // `WebPAnimEncoderOptions`; the init call then overwrites all of them.
    let mut options: WebPAnimEncoderOptions = unsafe { std::mem::zeroed() };
    if unsafe { WebPAnimEncoderOptionsInitInternal(&mut options, WebPGetMuxABIVersion()) } == 0 {
        return Err(ConverterError::AnimationEncodingFailed);
    }
    options.anim_params.loop_count = loop_count;
    // GIF frames are palette-based and often compress smaller losslessly, so
    // let libwebp choose per frame. `minimize_size` is deliberately left off:
    // it makes the encoder try both dispose methods per frame, which multiplies
    // across every candidate in the sweep for a marginal size win.
    options.allow_mixed = 1;

    let encoder = AnimEncoder::new(width, height, &options)?;

    let mut timestamp_ms: i32 = 0;
    let mut frame_count: u32 = 0;

    for frame in decoder.into_frames() {
        let frame = frame.map_err(|_| ConverterError::FailedToDecodeAnimation)?;
        let duration_ms = frame_duration_ms(frame.delay());

        // The GIF decoder always yields a full canvas at (0, 0), already
        // composited for disposal and blending, so the buffer maps 1:1 onto
        // the encoder canvas. Import it by its own dimensions all the same —
        // the canvas size comes from a different decoder instance, and the
        // import reads straight off the pointer.
        let buffer = frame.into_buffer();
        let (frame_width, frame_height) = buffer.dimensions();
        let mut picture = Picture::from_rgba(buffer.as_raw(), frame_width, frame_height)?;

        // `timestamp_ms` is the frame's *start* time; libwebp derives each
        // duration from the gap to the next one.
        let added =
            unsafe { WebPAnimEncoderAdd(encoder.ptr, &mut picture.inner, timestamp_ms, &config) };
        if added == 0 {
            return Err(ConverterError::AnimationEncodingFailed);
        }

        timestamp_ms = timestamp_ms.saturating_add(duration_ms);
        frame_count += 1;
    }

    if frame_count == 0 {
        return Err(ConverterError::FailedToDecodeAnimation);
    }

    // Required terminator. Without it `WebPAnimEncoderAssemble` guesses the
    // last frame's duration as the average of the earlier ones.
    let terminated = unsafe {
        WebPAnimEncoderAdd(
            encoder.ptr,
            std::ptr::null_mut(),
            timestamp_ms,
            std::ptr::null(),
        )
    };
    if terminated == 0 {
        return Err(ConverterError::AnimationEncodingFailed);
    }

    let mut assembled = AnimData::new();
    if unsafe { WebPAnimEncoderAssemble(encoder.ptr, &mut assembled.inner) } == 0 {
        return Err(ConverterError::AnimationEncodingFailed);
    }

    let bytes = assembled.to_vec();
    if bytes.is_empty() {
        return Err(ConverterError::AnimationEncodingFailed);
    }

    Ok(EncodedAnimation { bytes, frame_count })
}

/// Bytes per quality point; lower is better.
///
/// The divisor floors at 1 so quality 0 scores finitely — `bytes / 0.0` is
/// `+inf`, which made quality 0 unselectable.
fn score(size: usize, quality: u8) -> f32 {
    size as f32 / f32::from(quality.max(1))
}

/// Quality levels tried for a still image: the full 2-point sweep.
fn still_candidates(min_quality: u8) -> Vec<u8> {
    // Note: `step_by(2)` skips 100 when `100 - min_quality` is odd. Left as-is
    // so still-image output does not change.
    (min_quality.min(100)..=100)
        .step_by(STILL_QUALITY_STEP as usize)
        .collect()
}

/// Quality levels tried for an animation: at most [`MAX_ANIMATION_CANDIDATES`],
/// spread from `min_quality` to 100 no matter how many frames there are.
fn animation_candidates(min_quality: u8) -> Vec<u8> {
    let min = min_quality.min(100);
    let step = ((100 - min) / (MAX_ANIMATION_CANDIDATES - 1)).max(1);

    let mut candidates: Vec<u8> = (min..100)
        .step_by(step as usize)
        .take(MAX_ANIMATION_CANDIDATES as usize - 1)
        .collect();
    candidates.push(100);

    candidates
}

fn optimize_still(
    image_path: &str,
    output_path: &str,
    min_quality: u8,
) -> ConverterResult<OptimizationOutcome> {
    let image_data = get_image(image_path)?;

    // Test quality levels in range, find best compression/quality ratio
    let mut best: Option<(u8, Vec<u8>)> = None;
    let mut best_score = f32::MAX; // Lower score = better

    for quality in still_candidates(min_quality) {
        let encoded = encode(&image_data, f32::from(quality))?;
        let candidate_score = score(encoded.len(), quality);

        if candidate_score < best_score {
            best_score = candidate_score;
            best = Some((quality, encoded));
        }
    }

    let (quality, encoded) = best.ok_or(ConverterError::EncodingFailed)?;
    fs::write(output_path, encoded).map_err(|_| ConverterError::FailedToWriteOutputFile)?;

    Ok(OptimizationOutcome {
        quality,
        frame_count: 1,
    })
}

fn optimize_animation(
    image_path: &str,
    output_path: &str,
    min_quality: u8,
) -> ConverterResult<OptimizationOutcome> {
    // The frame count travels with the bytes: reporting the last candidate's
    // count next to a different candidate's file would be a lie the moment a
    // decode ever stops early on one pass.
    let mut best: Option<(u8, EncodedAnimation)> = None;
    let mut best_score = f32::MAX;

    for quality in animation_candidates(min_quality) {
        let encoded = encode_animation(image_path, f32::from(quality))?;

        // A one-frame GIF is a still image wearing a GIF hat; the still
        // encoder gives it a smaller, non-animated container.
        if encoded.frame_count <= 1 {
            return optimize_still(image_path, output_path, min_quality);
        }

        let candidate_score = score(encoded.bytes.len(), quality);
        if candidate_score < best_score {
            best_score = candidate_score;
            best = Some((quality, encoded));
        }
    }

    let (quality, EncodedAnimation { bytes, frame_count }) =
        best.ok_or(ConverterError::AnimationEncodingFailed)?;
    fs::write(output_path, bytes).map_err(|_| ConverterError::FailedToWriteOutputFile)?;

    Ok(OptimizationOutcome {
        quality,
        frame_count,
    })
}

pub fn optimize_image(
    image_path: String,
    output_path: String,
    min_quality: u8,
) -> ConverterResult<OptimizationOutcome> {
    if !Path::new(&image_path).exists() {
        return Err(ConverterError::FileNotFound);
    }

    // Guarantees a non-empty sweep for both paths; Dart already clamps, but
    // this is a public API and a u8 can carry 101-255.
    let min_quality = min_quality.min(100);

    // GIF is the only animated input we accept; everything else keeps the
    // single-image path untouched.
    if detect_format(&image_path)? == Some(ImageFormat::Gif) {
        optimize_animation(&image_path, &output_path, min_quality)
    } else {
        optimize_still(&image_path, &output_path, min_quality)
    }
}

#[cfg(test)]
mod tests {
    use std::{
        fs,
        path::PathBuf,
        sync::atomic::{AtomicU32, Ordering},
    };

    use image::{
        Delay, Frame, RgbaImage,
        codecs::gif::{GifEncoder, Repeat},
    };

    use super::{
        ImageData, ImageType, MAX_ANIMATION_CANDIDATES, Picture, animation_candidates,
        canvas_is_encodable, encode, optimize_image, score, still_candidates,
    };
    use crate::result::OptimizationOutcome;

    const MAX_CANDIDATES: usize = MAX_ANIMATION_CANDIDATES as usize;
    const FRAME_DELAY_MS: u32 = 100;

    /// A self-deleting temp path. Cheaper than a `tempfile` dev-dependency for
    /// the handful of round-trip tests below.
    struct TempPath {
        path: PathBuf,
    }

    impl TempPath {
        fn new(suffix: &str) -> Self {
            static COUNTER: AtomicU32 = AtomicU32::new(0);
            let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
            let name = format!("image_optimizer_{}_{unique}{suffix}", std::process::id());

            Self {
                path: std::env::temp_dir().join(name),
            }
        }

        fn as_str(&self) -> &str {
            self.path.to_str().expect("temp path is valid UTF-8")
        }
    }

    impl Drop for TempPath {
        fn drop(&mut self) {
            let _ = fs::remove_file(&self.path);
        }
    }

    fn write_gif(path: &TempPath, frame_count: u32, repeat: Repeat) {
        let file = fs::File::create(&path.path).expect("create test gif");
        let mut encoder = GifEncoder::new(file);
        encoder.set_repeat(repeat).expect("set repeat");

        for index in 0..frame_count {
            // Distinct colours per frame so libwebp cannot merge them away.
            let shade = (index * 60 % 200 + 20) as u8;
            let buffer = RgbaImage::from_fn(16, 16, |x, y| {
                image::Rgba([shade, x as u8 * 12, y as u8 * 12, 255])
            });

            encoder
                .encode_frame(Frame::from_parts(
                    buffer,
                    0,
                    0,
                    Delay::from_numer_denom_ms(FRAME_DELAY_MS, 1),
                ))
                .expect("encode gif frame");
        }
    }

    fn convert(input: &TempPath, output: &TempPath, min_quality: u8) -> OptimizationOutcome {
        optimize_image(
            input.as_str().to_string(),
            output.as_str().to_string(),
            min_quality,
        )
        .expect("conversion should succeed")
    }

    /// Walks the top-level RIFF chunks of a WebP file.
    fn riff_chunks(webp: &[u8]) -> Vec<(&[u8], &[u8])> {
        let mut chunks = Vec::new();
        let mut cursor = 12; // 'RIFF' + u32 size + 'WEBP'

        while cursor + 8 <= webp.len() {
            let id = &webp[cursor..cursor + 4];
            let size_bytes: [u8; 4] = webp[cursor + 4..cursor + 8]
                .try_into()
                .expect("four size bytes");
            let size = u32::from_le_bytes(size_bytes) as usize;
            let Some(body) = webp.get(cursor + 8..cursor + 8 + size) else {
                break;
            };

            chunks.push((id, body));
            // Chunk payloads are padded to an even length.
            cursor += 8 + size + (size & 1);
        }

        chunks
    }

    fn chunks_named<'a>(chunks: &[(&'a [u8], &'a [u8])], id: &[u8; 4]) -> Vec<&'a [u8]> {
        chunks
            .iter()
            .filter(|(chunk_id, _)| chunk_id == id)
            .map(|(_, body)| *body)
            .collect()
    }

    fn assert_is_webp(bytes: &[u8]) {
        assert!(bytes.len() > 12, "output is too short to be a WebP");
        assert_eq!(&bytes[0..4], b"RIFF", "missing RIFF header");
        assert_eq!(&bytes[8..12], b"WEBP", "missing WEBP fourcc");
    }

    fn convert_gif(frames: u32, repeat: Repeat) -> (OptimizationOutcome, Vec<u8>) {
        let input = TempPath::new(".gif");
        let output = TempPath::new(".webp");
        write_gif(&input, frames, repeat);

        let outcome = convert(&input, &output, 80);
        let bytes = fs::read(&output.path).expect("read optimized webp");

        (outcome, bytes)
    }

    #[test]
    fn encodes_rgb_images_without_crashing() {
        let image = ImageData::new(vec![255, 0, 0], 1, 1, ImageType::Rgb);

        let result = encode(&image, 80.0);

        assert!(result.is_ok(), "expected RGB encoding to succeed");
    }

    #[test]
    fn encodes_rgba_images_without_crashing() {
        let image = ImageData::new(vec![255, 0, 0, 128], 1, 1, ImageType::Rgba);

        let result = encode(&image, 80.0);

        assert!(result.is_ok(), "expected RGBA encoding to succeed");
    }

    #[test]
    fn quality_zero_scores_finitely() {
        assert!(score(1_000, 0).is_finite());
        assert_eq!(score(1_000, 0), score(1_000, 1));
    }

    #[test]
    fn still_candidates_keep_the_two_point_sweep() {
        let candidates = still_candidates(80);

        assert_eq!(candidates.len(), 11);
        assert_eq!(candidates.first(), Some(&80));
        assert_eq!(candidates.last(), Some(&100));
        // A minimum above the valid range used to produce an empty sweep.
        assert_eq!(still_candidates(200), vec![100]);
    }

    #[test]
    fn animation_candidates_are_capped() {
        for min_quality in 0..=255u8 {
            let candidates = animation_candidates(min_quality);

            assert!(
                !candidates.is_empty(),
                "min quality {min_quality} produced an empty sweep"
            );
            assert!(
                candidates.len() <= MAX_CANDIDATES,
                "expected at most {MAX_CANDIDATES} candidates for min quality \
                 {min_quality}, got {candidates:?}"
            );
            assert_eq!(
                candidates.last(),
                Some(&100),
                "quality 100 should always be tried"
            );
            assert!(
                candidates
                    .iter()
                    .all(|&quality| quality >= min_quality.min(100)),
                "candidates must not drop below the requested minimum"
            );
        }

        assert_eq!(animation_candidates(80), vec![80, 86, 92, 100]);
        assert_eq!(animation_candidates(0), vec![0, 33, 66, 100]);
        assert_eq!(animation_candidates(100), vec![100]);
    }

    #[test]
    fn rejects_canvases_beyond_the_webp_limit() {
        assert!(canvas_is_encodable(16383, 16383));
        assert!(!canvas_is_encodable(16384, 100));
        // Area stays tiny, so only the per-axis check catches this one.
        assert!(!canvas_is_encodable(20000, 100));
        assert!(!canvas_is_encodable(0, 100));
    }

    #[test]
    fn rejects_a_buffer_smaller_than_the_dimensions_it_claims() {
        let rgba = vec![0u8; 4 * 4 * 4];

        assert!(Picture::from_rgba(&rgba, 4, 4).is_ok());
        // libwebp would read past the end of the allocation for these.
        assert!(Picture::from_rgba(&rgba, 8, 8).is_err());
        assert!(Picture::from_rgba(&rgba, 20000, 4).is_err());
    }

    #[test]
    fn converts_animated_gif_to_animated_webp() {
        let (outcome, bytes) = convert_gif(3, Repeat::Infinite);

        assert_eq!(outcome.frame_count, 3);
        assert_is_webp(&bytes);

        let chunks = riff_chunks(&bytes);
        assert_eq!(chunks_named(&chunks, b"VP8X").len(), 1, "missing VP8X");
        assert_eq!(chunks_named(&chunks, b"ANIM").len(), 1, "missing ANIM");
        assert_eq!(
            chunks_named(&chunks, b"ANMF").len(),
            3,
            "expected one ANMF per frame"
        );
    }

    #[test]
    fn preserves_frame_delays() {
        let (_, bytes) = convert_gif(3, Repeat::Infinite);
        let chunks = riff_chunks(&bytes);
        let frames = chunks_named(&chunks, b"ANMF");

        // ANMF payload: x/64, y/64, width-1, height-1 (24 bits each), then the
        // frame duration in ms as a 24-bit little-endian value.
        for body in frames {
            let duration = u32::from_le_bytes([body[12], body[13], body[14], 0]);

            assert_eq!(
                duration, FRAME_DELAY_MS,
                "frame duration should survive the round trip"
            );
        }
    }

    #[test]
    fn preserves_loop_count() {
        for (repeat, expected) in [(Repeat::Infinite, 0), (Repeat::Finite(3), 3)] {
            let (_, bytes) = convert_gif(3, repeat);
            let chunks = riff_chunks(&bytes);
            let anim = chunks_named(&chunks, b"ANIM");
            let body = anim.first().expect("missing ANIM chunk");

            // ANIM payload: 4-byte BGRA background, then a 16-bit loop count.
            let loop_count = u16::from_le_bytes([body[4], body[5]]);

            assert_eq!(
                loop_count, expected,
                "loop count should survive for {repeat:?}"
            );
        }
    }

    #[test]
    fn single_frame_gif_falls_back_to_the_still_path() {
        let (outcome, bytes) = convert_gif(1, Repeat::Infinite);

        assert_eq!(outcome.frame_count, 1);
        assert_is_webp(&bytes);

        let chunks = riff_chunks(&bytes);
        assert!(
            chunks_named(&chunks, b"ANIM").is_empty(),
            "a single frame should not produce an animation"
        );
    }

    #[test]
    fn reports_missing_input_file() {
        let missing = TempPath::new(".gif");
        let output = TempPath::new(".webp");

        let result = optimize_image(
            missing.as_str().to_string(),
            output.as_str().to_string(),
            80,
        );

        assert!(result.is_err(), "expected a missing input to fail");
    }
}
