import 'package:flutter/material.dart';
import '../../models/agent/cds_alert.dart';

/// Widget for displaying a Clinical Decision Support alert
class CdsAlertCard extends StatelessWidget {
  final CdsAlert alert;
  final bool compact;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const CdsAlertCard({
    super.key,
    required this.alert,
    this.compact = false,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getAlertColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getAlertColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getAlertIcon(),
            size: 18,
            color: _getAlertColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _getAlertColor(),
                  ),
                ),
                if (alert.description.isNotEmpty)
                  Text(
                    alert.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          _buildSeverityBadge(context),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Card(
      color: _getAlertColor().withOpacity(0.05),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              color: _getAlertColor().withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    _getAlertIcon(),
                    color: _getAlertColor(),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.typeDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getAlertColor(),
                          ),
                        ),
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _getAlertColor(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSeverityBadge(context),
                ],
              ),
            ),

            // Description
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                alert.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

            // Recommendations
            if (alert.recommendations.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommendations:',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...alert.recommendations.map((rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(rec)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],

            // Actions
            if (onDismiss != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('Acknowledge'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getAlertColor(),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        alert.severityDisplay,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getAlertColor() {
    switch (alert.severity) {
      case CdsSeverity.critical:
        return Colors.red;
      case CdsSeverity.high:
        return Colors.orange;
      case CdsSeverity.moderate:
        return Colors.amber.shade700;
      case CdsSeverity.low:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon() {
    switch (alert.type) {
      case CdsAlertType.drugInteraction:
        return Icons.medication;
      case CdsAlertType.allergyAlert:
        return Icons.warning_amber;
      case CdsAlertType.careGap:
        return Icons.event_busy;
      case CdsAlertType.abnormalResult:
        return Icons.science;
      case CdsAlertType.dosageWarning:
        return Icons.scale;
      case CdsAlertType.contraindication:
        return Icons.block;
      case CdsAlertType.other:
        return Icons.info;
    }
  }
}
