import 'package:flutter/material.dart';

import '../../domain/entities/download_history_filter.dart';

class DownloadHistoryFilterRow extends StatelessWidget {
  const DownloadHistoryFilterRow({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final DownloadHistoryFilter selected;
  final ValueChanged<DownloadHistoryFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Audio'),
            selected: selected == DownloadHistoryFilter.audio,
            onSelected: (_) => onSelect(DownloadHistoryFilter.audio),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ChoiceChip(
            label: const Text('Video'),
            selected: selected == DownloadHistoryFilter.video,
            onSelected: (_) => onSelect(DownloadHistoryFilter.video),
          ),
        ),
      ],
    );
  }
}
