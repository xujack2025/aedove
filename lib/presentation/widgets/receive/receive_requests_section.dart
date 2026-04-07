import 'package:aedove/domain/entities/transfer_request_entity.dart';
import 'package:aedove/presentation/widgets/receive/receive_section_header.dart';
import 'package:aedove/presentation/widgets/transfer/transfer_request_card.dart';
import 'package:flutter/material.dart';

class ReceiveRequestsSection extends StatelessWidget {
  const ReceiveRequestsSection({
    super.key,
    required this.requests,
    required this.onAcceptRequest,
    required this.onDenyRequest,
    required this.onAcceptAll,
    required this.onDenyAll,
  });

  final List<TransferRequestEntity> requests;
  final void Function(String requestId) onAcceptRequest;
  final void Function(String requestId) onDenyRequest;
  final VoidCallback onAcceptAll;
  final VoidCallback onDenyAll;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const SizedBox.shrink();
    }

    final actions = requests.length > 1
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onAcceptAll,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.done_all, size: 16),
                label: const Text('Accept All', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDenyAll,
                tooltip: 'Decline All',
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red[300],
                  size: 22,
                ),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceiveSectionHeader(
          title: 'Incoming Requests',
          count: requests.length,
          countColor: Colors.red.withValues(alpha: 0.1),
          countTextColor: Colors.red,
          trailing: actions,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final request = requests[index];
              return TransferRequestCard(
                request: request,
                onAccept: () => onAcceptRequest(request.id),
                onDeny: () => onDenyRequest(request.id),
              );
            },
          ),
        ),
      ],
    );
  }
}
