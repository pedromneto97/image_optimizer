import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  hierarchicalLoggingEnabled = true;

  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    await RustBuilder(
      assetName: 'src/ffi.g.dart',
      extraCargoEnvironmentVariables: input.config.code.targetOS != OS.macOS
          ? const {'RUSTFLAGS': '-Ctarget-cpu=native'}
          : const {},
    ).run(
      input: input,
      output: output,
      logger: Logger('RustBuilder')
        ..level = .ALL
        // Only used while building the Rust code
        // ignore: avoid_print
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
