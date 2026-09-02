use image_optimizer::optimize_image;

fn main() {
    let current_dir = std::env::current_dir().expect("Failed to get current directory");

    // `cargo run` keeps converting example.jpeg; `cargo run -- some.gif` is the
    // fast loop for animation work.
    let input = std::env::args()
        .nth(1)
        .unwrap_or("example.jpeg".to_string());
    let input_path = current_dir.join(input);
    let input_path = input_path.to_str().unwrap().to_string();

    let output_path = current_dir.join("output.webp");
    let output_path = output_path.to_str().unwrap().to_string();

    match optimize_image(input_path, output_path.clone(), 80) {
        Ok(outcome) => {
            println!(
                "Saved optimized image to {:?} at quality {} ({} frame(s))",
                output_path, outcome.quality, outcome.frame_count
            );
        }
        Err(err) => eprintln!("Optimize failed: {err:?}"),
    }
}
