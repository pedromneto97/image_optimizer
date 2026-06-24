use image_optimizer::optimize_image;

fn main() {
    let current_dir = std::env::current_dir().expect("Failed to get current directory");
    let input_path = current_dir.join("example.jpeg");
    let input_path = input_path.to_str().unwrap().to_string();

    let output_path = current_dir.join("output.webp");
    let output_path = output_path.to_str().unwrap().to_string();

    match optimize_image(input_path, output_path.clone(), 80) {
        Ok(quality) => {
            println!(
                "Saved optimized image to {:?} at quality {}",
                output_path, quality
            );
        }
        Err(err) => eprintln!("Optimize failed: {err:?}"),
    }
}
