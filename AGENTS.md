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

# Commands

| Task | Command |
|---|---|
| Install deps | `flutter pub get` |
| Run the app | `flutter run -d windows` (or `macos` / `linux`) |
| Static analysis (the CI gate) | `flutter analyze` |
| Autofix lints | `dart fix --apply` |
| Rust unit tests | `cd rust && cargo test` |
| One Rust test | `cd rust && cargo test returns_error_for_null_output_path` |
| Exercise conversion without Flutter | `cd rust && cargo run` |
| Regenerate Dart FFI bindings | `dart run tool/ffigen.dart` |
| Release build | `flutter build windows\|macos\|linux --release` |
| MSIX package | `dart run msix:create --build-windows false --output-path dist` |

- `.github/workflows/standard.yaml` runs only `flutter analyze` on PRs — it is
  the sole automated gate, so it must be clean.
- `cargo run` (`rust/src/main.rs`) converts `rust/example.jpeg` →
  `rust/output.webp` at min quality 80. Fastest loop for conversion-algorithm
  work; skips the whole Flutter boot. `cargo run -- some.gif` converts that file
  instead — the fast loop for animation work.
- `test/` is **empty** — there is no Dart test suite yet. Rust is the only place
  with tests (`rust/src/lib.rs`, `rust/src/converter.rs`).
- The Rust toolchain is pinned to 1.96.0 with six cross targets in
  `rust/rust-toolchain.toml`; `rustup toolchain install` from `rust/` sets it up.

# Architecture

A Flutter desktop shell over a Rust WebP encoder, wired with native assets — no
manual `DynamicLibrary.open`, no bundled `.dll`/`.dylib` to manage.

**Layers** (`lib/src/`, Clean Architecture):

- `domain/` — `entities/optimization_result.dart`, the sealed `exceptions.dart`
  hierarchy, the `ImageOptimizerRepository` interface, and the `OptimizeImage`
  use case (invoked through `call()`).
- `data/` — `FfiImageOptimizerRepository` is the only implementation; it owns
  all `calloc`/`free` and the error-code translation.
- `presentation/image_optimizer/` — one Cubit, one page, small widgets.

**Wiring** is manual in `lib/main.dart`: `FfiImageOptimizerRepository` →
`OptimizeImage` → `ImageOptimizerCubit` via a single `BlocProvider`. No DI
container.

**Native build:** `hook/build.dart` runs `RustBuilder` from
`native_toolchain_rust` with `assetName: 'src/ffi.g.dart'`. `flutter run` and
`flutter build` compile the Rust crate automatically — never build or copy the
library by hand. Non-macOS targets get `RUSTFLAGS=-Ctarget-cpu=native`.

## The FFI boundary

One function, `optimize_image_ffi`, crosses four artifacts that must stay in
sync. Changing the signature or adding an error variant means touching all four:

1. `rust/src/lib.rs` — `optimize_image_ffi` plus
   `OptimizeImageOutput { quality, frame_count, error_code }`. The
   `ConverterError` → code table lives on `ConverterError::code()` in
   `rust/src/result.rs` and is exhaustive, so a new variant is a compile error
   there.
2. `rust/bindings.h` — **generated** by cbindgen from `rust/build.rs` on every
   `cargo build`. Do not hand-edit.
3. `lib/src/ffi.g.dart` — **generated** by `dart run tool/ffigen.dart` from
   `bindings.h`. Do not hand-edit. (`pubspec.yaml` also carries an `ffigen:`
   block mirroring the same config.)
4. `_throwExceptionFromCode` in
   `lib/src/data/repositories/ffi_image_optimizer_repository.dart` ↔
   `lib/src/domain/exceptions.dart`.

Regeneration order: `cargo build` (refreshes `bindings.h`), then
`dart run tool/ffigen.dart`.

Error codes, duplicated between `ConverterError::code()`, the Rust doc comment
and the Dart switch:
`0` ok · `1` file not found · `2` open failed · `3` unsupported type ·
`4` encode failed · `5` write failed · `6` animation decode failed ·
`7` animated encode failed · `-1` invalid params (null pointer).
Dart adds `MissingOutputImageException` for when the encoder reports success but
no file landed on disk.

The FFI call runs inside `Isolate.run` (`FfiImageOptimizerRepository`) because
it never yields — an animated GIF re-encodes every frame once per quality
candidate and would otherwise freeze the UI. That is why `_optimizeSync` and
`_throwExceptionFromCode` are top-level: an `Isolate.run` closure cannot
capture `this`.

## Optimization algorithm

`optimize_image` in `rust/src/converter.rs` sniffs the format, then takes one of
two paths. Both score candidates as `bytes / quality` and keep the lowest, so
the quality returned is often *higher* than the requested minimum.

- **Still images** decode once and sweep `min_quality..=100` in steps of 2 (~11
  encodes). Only `Rgb8` and `Rgba8` inputs are supported; anything else is
  `ImageTypeNotSupported`.
- **GIFs** become animated WebP via libwebp's `WebPAnimEncoder`, preserving
  frame delays and loop count. Because each candidate re-encodes *every* frame,
  the sweep is capped at `MAX_ANIMATION_CANDIDATES` (4) spread across
  `min_quality..=100`. The GIF is re-decoded per candidate rather than held in
  memory — a 1080p 200-frame GIF would be 1.6 GB of decoded frames. A one-frame
  GIF falls back to the still path. `allow_mixed` lets libwebp pick lossy or
  lossless per frame, which palette-based GIF content usually wins from.

Three libwebp contracts the animation path depends on: the last
`WebPAnimEncoderAdd` must pass a null frame (it is what fixes the final frame's
duration); `WebPAnimEncoderNewInternal` validates only total *area*, so the
per-axis 16383 limit is checked in `canvas_is_encodable`; and frames added are
not frames written — the encoder folds a repeated frame into its predecessor and
drops the animation container entirely when only one survives. So the reported
`frame_count` is demuxed back out of the assembled bitstream
(`WEBP_FF_FRAME_COUNT`), never counted on the way in. The decoded count still
decides the one-frame-GIF fallback, because how many frames survive encoding
moves with the quality candidate and the fallback must not.

## State conventions

`image_optimizer_state.dart` is a sealed hierarchy: the root
`ImageOptimizerState` carries `minimumQuality`, and the sealed
`ImageOptimizerFilePicked` adds `pickedFile` + `outputPath`. When adding a
state:

- extend the narrowest sealed base that already has the fields you need;
- implement `copyWith` and a `fromImageOptimizerState` factory (the transition
  helper every existing state provides);
- extend `props` with `[...super.props, ...]`;
- consume it from widgets with `BlocSelector`, not `BlocBuilder` — see
  `image_optimizer_page.dart`.

Output files go to `getApplicationDocumentsDirectory()`, named
`<input>_<epochMillis>.webp`.

# Lint rules that actually bite

`analysis_options.yaml` turns on ~60 rules on top of `flutter_lints`. The ones
that reject otherwise-normal code:

- `prefer_relative_imports` — relative imports inside `lib/`, never
  `package:image_optimizer/...`
- `prefer_expression_function_bodies` — `=>` bodies wherever possible
- `diagnostic_describe_all_properties` — a widget with fields must override
  `debugFillProperties` (pattern in `widgets/result_card.dart`)
- `sort_constructors_first`, `sort_pub_dependencies`, `combinators_ordering`,
  `directives_ordering` — ordering is enforced, including pubspec deps
- `require_trailing_commas`, `prefer_single_quotes`, `prefer_final_locals`,
  `omit_local_variable_types`, `always_put_control_body_on_new_line`
- `avoid_redundant_argument_values`, `unnecessary_lambdas`, `unawaited_futures`

`**/*.g.dart` and the platform folders are excluded from analysis.

# Release process

Conventional commits feed release-please (`.github/workflows/release.yaml`,
`release-type: dart`), which opens the release PR, bumps `version:` in
`pubspec.yaml`, and writes `CHANGELOG.md`. Merging it triggers three parallel
build jobs:

- **Windows** — signed MSIX plus portable zip
- **macOS** — arm64 only (`FLUTTER_MACOS_ARM64_ONLY`), signed inside-out
  (dylibs → frameworks → app, not `--deep`), notarized, DMG plus zip.
  `MACOS_CERTIFICATE_BASE64` must be a **Developer ID Application** `.p12` —
  an Apple Development or Apple Distribution certificate signs and verifies
  locally and is then rejected by the notary service. The job picks the
  identity out of the keychain by certificate kind and signs by SHA-1 hash,
  so there is no signing-identity secret to keep in sync
- **Linux** — pinned to `ubuntu-22.04` deliberately (glibc 2.35 keeps the `.deb`
  installable more widely), `.deb` plus tarball

Force a version with a `Release-As:` commit trailer.

The macOS runner has no certificate at build time — the job builds first and
signs with Developer ID afterwards. So all three Runner configurations must keep
`"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-"` in
`macos/Runner.xcodeproj/project.pbxproj`; opening the project in Xcode can
rewrite it to `Apple Development`, which fails the release build with
*No signing certificate "Mac Development" found*. Entitlements are read back off
the built app rather than from `Runner/Release.entitlements`, because Xcode
merges the `ENABLE_*` capability build settings into them.

# Repo conventions

- `.claude/skills/` and `.agents/skills/` are vendored copies of
  `dart-lang/skills`, hash-tracked in `skills-lock.json` — don't hand-edit them.
- CRLF line endings (`.vscode/settings.json`).
