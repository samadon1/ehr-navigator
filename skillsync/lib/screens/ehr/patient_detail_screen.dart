import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/fhir/patient.dart';
import '../../models/agent/cds_alert.dart';
import '../../services/ehr/fhir_query_service.dart';
import '../../services/agent/ehr_agent_service.dart';
import 'agent_chat_screen.dart';
import 'comparison_screen.dart';

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;
  final EhrAgentService agentService;
  final FhirQueryService fhirService;

  const PatientDetailScreen({
    super.key,
    required this.patient,
    required this.agentService,
    required this.fhirService,
  });

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _conditions = {};
  Map<String, dynamic> _medications = {};
  Map<String, dynamic> _allergies = {};

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        widget.fhirService.getConditions(widget.patient.id),
        widget.fhirService.getMedications(widget.patient.id),
        widget.fhirService.getAllergies(widget.patient.id),
      ]);

      if (mounted) {
        setState(() {
          _conditions = results[0];
          _medications = results[1];
          _allergies = results[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _openAgentChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentChatScreen(
          patient: widget.patient,
          agentService: widget.agentService,
        ),
      ),
    );
  }

  void _openComparison() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComparisonScreen(
          patient: widget.patient,
          agentService: widget.agentService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildPatientHeader(),
                  const SizedBox(height: 20),
                  _buildQuickStats(),
                  const SizedBox(height: 24),
                  _buildSection('Conditions', Icons.medical_services_outlined, _buildConditionsList()),
                  const SizedBox(height: 16),
                  _buildSection('Medications', Icons.medication_outlined, _buildMedicationsList()),
                  const SizedBox(height: 16),
                  _buildSection('Allergies', Icons.warning_amber_rounded, _buildAllergiesList()),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compare button
          FloatingActionButton.extended(
            heroTag: 'compare',
            onPressed: _openComparison,
            backgroundColor: Colors.purple,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Compare'),
          ),
          const SizedBox(width: 12),
          // Main AI chat button
          FloatingActionButton.extended(
            heroTag: 'chat',
            onPressed: _openAgentChat,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Ask AI'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Patient Details'),
    );
  }

  Widget _buildPatientHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _getInitials(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.patient.displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(_buildDemographics(), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                if (widget.patient.mrn != null) ...[
                  const SizedBox(height: 2),
                  Text('MRN: ${widget.patient.mrn}', style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final conditionCount = (_conditions['conditions'] as List?)?.length ?? 0;
    final medicationCount = (_medications['medications'] as List?)?.length ?? 0;
    final allergyCount = (_allergies['allergies'] as List?)?.length ?? 0;

    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.medical_services_outlined, label: 'Conditions', value: '$conditionCount', color: const Color(0xFF3B82F6))),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.medication_outlined, label: 'Medications', value: '$medicationCount', color: AppColors.success)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(icon: Icons.warning_amber_rounded, label: 'Allergies', value: '$allergyCount', color: allergyCount > 0 ? AppColors.warning : AppColors.textTertiary)),
      ],
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
          const Divider(height: 1),
          content,
        ],
      ),
    );
  }

  Widget _buildConditionsList() {
    final conditions = (_conditions['conditions'] as List?) ?? [];
    if (conditions.isEmpty) return _emptyState('No conditions on record');

    return Column(
      children: conditions.take(5).map((c) {
        final condition = c as Map<String, dynamic>;
        final isActive = condition['isActive'] == true;
        return _listItem(
          title: condition['name'] ?? 'Unknown',
          trailing: _statusChip(isActive ? 'Active' : 'Resolved', isActive ? AppColors.success : AppColors.textTertiary),
        );
      }).toList(),
    );
  }

  Widget _buildMedicationsList() {
    final medications = (_medications['medications'] as List?) ?? [];
    if (medications.isEmpty) return _emptyState('No active medications');

    return Column(
      children: medications.take(5).map((m) {
        final med = m as Map<String, dynamic>;
        return _listItem(title: med['name'] ?? 'Unknown', subtitle: med['dosage']);
      }).toList(),
    );
  }

  Widget _buildAllergiesList() {
    final allergies = (_allergies['allergies'] as List?) ?? [];
    if (allergies.isEmpty) return _emptyState('No known allergies');

    return Column(
      children: allergies.map((a) {
        final allergy = a as Map<String, dynamic>;
        final isHigh = allergy['isHighCriticality'] == true;
        return _listItem(
          title: allergy['allergen'] ?? 'Unknown',
          leading: Icon(Icons.do_not_disturb_rounded, color: isHigh ? AppColors.error : AppColors.warning, size: 18),
          trailing: isHigh ? _statusChip('HIGH', AppColors.error) : null,
        );
      }).toList(),
    );
  }

  Widget _listItem({required String title, String? subtitle, Widget? leading, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                if (subtitle != null) Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _emptyState(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _getInitials() {
    if (widget.patient.name.isEmpty) return '?';
    final name = widget.patient.name.first;
    final parts = <String>[];
    if (name.given.isNotEmpty) parts.add(name.given.first.substring(0, 1));
    if (name.family != null) parts.add(name.family!.substring(0, 1));
    return parts.join().toUpperCase();
  }

  String _buildDemographics() {
    final parts = <String>[];
    if (widget.patient.age != null) parts.add('${widget.patient.age} years');
    if (widget.patient.gender != null) {
      parts.add(widget.patient.gender!.substring(0, 1).toUpperCase() + widget.patient.gender!.substring(1));
    }
    if (widget.patient.formattedBirthDate != null) {
      parts.add('DOB: ${widget.patient.formattedBirthDate}');
    }
    return parts.join(' · ');
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
