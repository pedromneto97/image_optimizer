This project is a Flutter desktop application to optimize image converting to WebP.

1. User can select images from their local file system.
2. User can choose the minimum quality for the WebP conversion.
3. The application will convert the selected images to WebP format with the best size/quality ratio.

# Flutter
- Uses Flutter framework for building the desktop application for Windows, macOS, and Linux.
- Uses Image Picker package for selecting images from the local file system.
- Calls the WebP conversion library to convert images to WebP format using FFI.
- Use Clean Architecture principles to separate the UI, business logic, and data layers of the application.

# Rust
- Uses Rust programming language for implementing the WebP conversion logic.