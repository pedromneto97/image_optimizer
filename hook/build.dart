import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  hierarchicalLoggingEnabled = true;

  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'src/ffi.g.dart',
      extraCargoEnvironmentVariables: {'RUSTFLAGS': '-Ctarget-cpu=native'},
      // ...maybe enable some Cargo features or something in here too
    ).run(
      input: input,
      output: output,
      logger: Logger('RustBuilder')
        ..level = .ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
