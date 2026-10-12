import 'package:flutter/material.dart';
import '../../application/weekly_collage_activity.dart';

class WeeklyActivityChart extends StatelessWidget {
  const WeeklyActivityChart({
    super.key,
    required this.activity,
    required this.labels,
  });
  final WeeklyCollageActivity activity;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totals = List.generate(
      7,
      (i) => activity.audioMs[i] + activity.videoMs[i],
    );
    final peak = totals.fold(1.0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                children: [
                  FittedBox(
                    child: Text(
                      '${(totals[i] / 60000).round()}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 76,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 22,
                          height: totals[i] > 0
                              ? (totals[i] / peak * 76).clamp(3, 76).toDouble()
                              : 3,
                          child: totals[i] == 0
                              ? ColoredBox(color: scheme.outlineVariant)
                              : Column(
                                  children: [
                                    if (activity.videoMs[i] > 0)
                                      Expanded(
                                        flex:
                                            (activity.videoMs[i] /
                                                    totals[i] *
                                                    1000)
                                                .round()
                                                .clamp(1, 1000),
                                        child: ColoredBox(
                                          color: scheme.tertiary,
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    if (activity.audioMs[i] > 0)
                                      Expanded(
                                        flex:
                                            (activity.audioMs[i] /
                                                    totals[i] *
                                                    1000)
                                                .round()
                                                .clamp(1, 1000),
                                        child: ColoredBox(
                                          color: scheme.primary,
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    child: Text(
                      labels[i],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
