import 'package:aedove/domain/entities/transfer_progress_entity.dart';
import 'package:aedove/presentation/widgets/receive/receive_section_header.dart';
import 'package:aedove/presentation/widgets/transfer/transfer_progress_card.dart';
import 'package:flutter/material.dart';

class ReceiveDownloadingSection extends StatelessWidget {
  const ReceiveDownloadingSection({super.key, required this.progressItems});

  final List<TransferProgressEntity> progressItems;

  @override
  Widget build(BuildContext context) {
    if (progressItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceiveSectionHeader(
          title: 'Downloading',
          count: progressItems.length,
          countColor: Colors.blue.withValues(alpha: 0.1),
          countTextColor: Colors.blue[700] ?? Colors.blue,
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: progressItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final progress = progressItems[index];
            return TransferProgressCard(progress: progress);
          },
        ),
      ],
    );
  }
}
