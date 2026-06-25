import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/data/repositories/ffi_image_optimizer_repository.dart';
import 'src/domain/usecases/optimize_image.dart';
import 'src/presentation/image_optimizer/cubit/image_optimizer_cubit.dart';
import 'src/presentation/image_optimizer/image_optimizer_page.dart';

void main() {
  runApp(const ImageOptimizerApp());
}

class ImageOptimizerApp extends StatelessWidget {
  const ImageOptimizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Optimizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (_) => ImageOptimizerCubit(
          optimizeImage: OptimizeImage(FfiImageOptimizerRepository()),
        ),
        child: const ImageOptimizerPage(),
      ),
    );
  }
}
