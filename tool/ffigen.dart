import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final header = packageRoot.resolve('rust/bindings.h');

  await FfiGenerator(
    input: Input(entryPoints: [header], include: (uri) => uri == header),
    output: Output(
      dart: DartOutput(path: packageRoot.resolve('lib/src/ffi.g.dart')),
    ),
    visitors: [
      Visitor(
        func: (node) => node.isIncluded = node.name == 'optimize_image_ffi',
        struct: (node) => node.isIncluded = node.name == 'OptimizeImageOutput',
      ),
    ],
  ).generate();
}
