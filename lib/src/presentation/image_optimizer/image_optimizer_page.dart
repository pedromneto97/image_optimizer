import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import 'cubit/image_optimizer_cubit.dart';
import 'widgets/image_optimizer_error_message.dart';
import 'widgets/input_summary_card.dart';
import 'widgets/quality_slider.dart';
import 'widgets/result_card.dart';

class ImageOptimizerPage extends StatelessWidget {
  const ImageOptimizerPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Image Optimizer')),
    body: BlocListener<ImageOptimizerCubit, ImageOptimizerState>(
      listener: (context, state) {
        // FailedToPickImage renders as nothing at all — it is not a
        // ImageOptimizerFilePicked, so both selectors below collapse — so the
        // snackbar is the only way it reaches the user.
        final message = switch (state) {
          ImageOptimizerFailure(:final exception) =>
            imageOptimizerErrorMessage(exception),
          FailedToPickImage() => 'The image could not be picked.',
          _ => null,
        };

        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Convert desktop images to WebP with the best size/quality ratio.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Row(
            spacing: 16,
            children: [
              const Expanded(child: QualitySlider()),
              Expanded(
                child:
                    BlocSelector<
                      ImageOptimizerCubit,
                      ImageOptimizerState,
                      bool
                    >(
                      selector: (state) => state is ImageOptimizerOptimizing,
                      builder: (context, isLoading) => FilledButton.icon(
                        onPressed: isLoading
                            ? null
                            : context.read<ImageOptimizerCubit>().pickImage,
                        icon: const Icon(Icons.image_search),
                        label: const Text('Pick image'),
                      ),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          BlocSelector<ImageOptimizerCubit, ImageOptimizerState, XFile?>(
            selector: (state) =>
                state is ImageOptimizerFilePicked ? state.pickedFile : null,
            builder: (context, state) => state != null
                ? InputSummaryCard(file: state)
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          BlocSelector<
            ImageOptimizerCubit,
            ImageOptimizerState,
            OptimizeImageSuccess?
          >(
            selector: (state) => state is OptimizeImageSuccess ? state : null,
            builder: (context, state) => state != null
                ? ResultCard(state: state)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
