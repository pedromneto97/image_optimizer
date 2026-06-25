import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

void main(List<String> args) async {
  hierarchicalLoggingEnabled = true;

  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'src/ffi.g.dart',
      extraCargoEnvironmentVariables: {'RUSTFLAGS': '-Ctarget-cpu=native'},
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
