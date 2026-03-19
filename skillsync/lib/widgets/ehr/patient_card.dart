import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/fhir/patient.dart';

class PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback? onTap;

  const PatientCard({
    super.key,
    required this.patient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildDetails(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final color = _getAvatarColor();
    final initials = _getInitials();

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final details = <Widget>[];

    if (patient.age != null) {
      details.add(_buildDetailChip('${patient.age}y'));
    }

    if (patient.gender != null) {
      final genderIcon = patient.gender?.toLowerCase() == 'male'
          ? Icons.male_rounded
          : Icons.female_rounded;
      details.add(Icon(genderIcon, size: 14, color: AppColors.textTertiary));
    }

    if (patient.mrn != null) {
      details.add(_buildDetailChip('MRN: ${patient.mrn}'));
    }

    return Row(
      children: [
        for (int i = 0; i < details.length; i++) ...[
          if (i > 0) ...[
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                color: AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ],
          details[i],
        ],
      ],
    );
  }

  Widget _buildDetailChip(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );
  }

  String _getInitials() {
    if (patient.name.isEmpty) return '?';
    final name = patient.name.first;
    final parts = <String>[];
    if (name.given.isNotEmpty) {
      parts.add(name.given.first.substring(0, 1));
    }
    if (name.family != null) {
      parts.add(name.family!.substring(0, 1));
    }
    return parts.join().toUpperCase();
  }

  Color _getAvatarColor() {
    final hash = patient.id.hashCode;
    final colors = [
      AppColors.primary,
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEC4899), // Pink
    ];
    return colors[hash.abs() % colors.length];
  }
}
