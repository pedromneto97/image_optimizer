import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/image_optimizer_cubit.dart';

class QualitySlider extends StatelessWidget {
  const QualitySlider({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocSelector<ImageOptimizerCubit, ImageOptimizerState, int>(
        selector: (state) => state.minimumQuality,
        builder: (context, minimumQuality) => Column(
          children: [
            Text('Minimum quality: $minimumQuality'),
            Slider(
              value: minimumQuality.toDouble(),
              max: 100,
              divisions: 100,
              label: minimumQuality.toString(),
              onChanged: (value) => context
                  .read<ImageOptimizerCubit>()
                  .updateMinimumQuality(value.toInt()),
            ),
          ],
        ),
      );
}
