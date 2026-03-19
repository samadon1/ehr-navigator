import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/agent/agent_state.dart';

/// Widget that shows the agent's current thinking/processing state
class AgentThinkingView extends StatelessWidget {
  final AgentState state;

  const AgentThinkingView({
    super.key,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current phase with animated indicator
                Row(
                  children: [
                    _PhaseIndicator(phase: state.phase),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.phaseDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),

                // Progress steps
                if (state.steps.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: state.steps.asMap().entries.map((entry) {
                        return _buildStep(entry.key, entry.value, state.steps.length);
                      }).toList(),
                    ),
                  ),
                ],

                // Tool calls being executed
                if (state.plannedToolCalls.isNotEmpty &&
                    state.phase == AgentPhase.executing) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: state.plannedToolCalls.map((tool) {
                      final isComplete = state.toolResults.any(
                        (r) => r.toolCallId == tool.id,
                      );
                      return _ToolChip(
                        name: _formatToolName(tool.name),
                        isComplete: isComplete,
                      );
                    }).toList(),
                  ),
                ],

                // Facts being collected
                if (state.collectedFacts.isNotEmpty &&
                    state.phase == AgentPhase.filtering) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fact_check_outlined, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Text(
                          '${state.collectedFacts.length} facts extracted',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Streaming response during synthesis
                if (state.phase == AgentPhase.synthesizing &&
                    state.response != null &&
                    state.response!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      state.response!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(int index, AgentStep step, int total) {
    final isLast = index == total - 1;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _getPhaseColor(step.phase).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getPhaseIcon(step.phase),
              size: 10,
              color: _getPhaseColor(step.phase),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.description,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatToolName(String name) {
    return name
        .replaceAll('get_', '')
        .replaceAll('check_', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w)
        .join(' ');
  }

  IconData _getPhaseIcon(AgentPhase phase) {
    switch (phase) {
      case AgentPhase.idle:
        return Icons.circle_outlined;
      case AgentPhase.discovery:
        return Icons.search_rounded;
      case AgentPhase.routing:
        return Icons.route_rounded;
      case AgentPhase.executing:
        return Icons.download_rounded;
      case AgentPhase.filtering:
        return Icons.filter_list_rounded;
      case AgentPhase.cdsChecking:
        return Icons.shield_outlined;
      case AgentPhase.synthesizing:
        return Icons.auto_awesome;
      case AgentPhase.complete:
        return Icons.check_circle_rounded;
      case AgentPhase.error:
        return Icons.error_outline_rounded;
    }
  }

  Color _getPhaseColor(AgentPhase phase) {
    switch (phase) {
      case AgentPhase.complete:
        return AppColors.success;
      case AgentPhase.error:
        return AppColors.error;
      case AgentPhase.cdsChecking:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

class _PhaseIndicator extends StatelessWidget {
  final AgentPhase phase;

  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }

  Color _getColor() {
    switch (phase) {
      case AgentPhase.complete:
        return AppColors.success;
      case AgentPhase.error:
        return AppColors.error;
      case AgentPhase.cdsChecking:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  IconData _getIcon() {
    switch (phase) {
      case AgentPhase.idle:
        return Icons.circle_outlined;
      case AgentPhase.discovery:
        return Icons.search_rounded;
      case AgentPhase.routing:
        return Icons.route_rounded;
      case AgentPhase.executing:
        return Icons.sync_rounded;
      case AgentPhase.filtering:
        return Icons.filter_list_rounded;
      case AgentPhase.cdsChecking:
        return Icons.shield_outlined;
      case AgentPhase.synthesizing:
        return Icons.auto_awesome;
      case AgentPhase.complete:
        return Icons.check_circle_rounded;
      case AgentPhase.error:
        return Icons.error_outline_rounded;
    }
  }
}

class _ToolChip extends StatelessWidget {
  final String name;
  final bool isComplete;

  const _ToolChip({required this.name, required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppColors.success : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_rounded : Icons.hourglass_empty_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
