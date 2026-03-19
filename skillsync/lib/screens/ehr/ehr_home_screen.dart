import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models/fhir/patient.dart';
import '../../services/ehr/fhir_query_service.dart';
import '../../services/ehr/fhir_store.dart';
import '../../services/ehr/synthea_importer.dart';
import '../../services/model_downloader.dart';
import '../../services/agent/ehr_agent_service.dart';
import '../../widgets/ehr/patient_card.dart';
import 'patient_detail_screen.dart';

class EhrHomeScreen extends StatefulWidget {
  const EhrHomeScreen({super.key});

  @override
  State<EhrHomeScreen> createState() => _EhrHomeScreenState();
}

class _EhrHomeScreenState extends State<EhrHomeScreen> {
  final FhirStore _store = FhirStore();
  final FhirQueryService _fhirService = FhirQueryService();
  late final EhrAgentService _agentService;

  List<Patient> _patients = [];
  bool _isLoading = true;
  bool _isDownloading = false;
  String _status = 'Initializing...';
  Map<ModelConfig, bool> _modelStatus = {};
  Map<ModelConfig, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _agentService = EhrAgentService(fhirService: _fhirService);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing...';
    });

    try {
      await _store.initialize();
      await _fhirService.initialize();
      _modelStatus = await ModelDownloader.checkEhrModelsStatus();

      final hasData = await _store.hasData();
      if (!hasData) {
        setState(() => _status = 'No patient data');
      } else {
        _patients = await _fhirService.getAllPatients();
        setState(() => _status = '${_patients.length} patients');
      }

      await _initializeAgent();
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeAgent() async {
    const routingModel = 'functiongemma-270m';
    const reasoningModel = 'qwen3-0.6';
    debugPrint('Using routing: $routingModel, reasoning: $reasoningModel');

    await _agentService.initialize(
      routingModelName: routingModel,
      reasoningModelName: reasoningModel,
    );
  }

  Future<void> _createDemoData() async {
    setState(() {
      _isLoading = true;
      _status = 'Creating demo patients...';
    });

    try {
      final importer = SyntheaImporter(_store);
      final result = await importer.createDemoPatients();
      _patients = await _fhirService.getAllPatients();

      if (mounted) {
        setState(() => _status = '${result.patientsImported} patients');
        _showSnackbar('Demo data created', isSuccess: true);
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadModels() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = {for (final m in ModelDownloader.ehrModels) m: 0.0};
    });

    try {
      await ModelDownloader.downloadEhrModels(
        onProgress: (model, progress, status) {
          if (mounted) {
            setState(() {
              _downloadProgress[model] = progress;
              _status = status;
            });
          }
        },
      );

      _modelStatus = await ModelDownloader.checkEhrModelsStatus();
      await _initializeAgent();
      if (mounted) _showSnackbar('Models downloaded', isSuccess: true);
    } catch (e) {
      if (mounted) _showSnackbar('Download failed: $e', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _store.clearAll();
      setState(() {
        _patients = [];
        _status = 'Data cleared';
      });
    }
  }

  void _showSnackbar(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _openPatient(Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(
          patient: patient,
          agentService: _agentService,
          fhirService: _fhirService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          if (_isDownloading) SliverToBoxAdapter(child: _buildDownloadProgress()),
          _buildBody(),
        ],
      ),
      floatingActionButton: _patients.isEmpty && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _createDemoData,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Demo Data'),
            )
          : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('EHR Navigator'),
        ],
      ),
      actions: [
        _buildModelStatusChip(),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          position: PopupMenuPosition.under,
          onSelected: (value) {
            switch (value) {
              case 'refresh': _initialize(); break;
              case 'download': _downloadModels(); break;
              case 'clear': _clearData(); break;
            }
          },
          itemBuilder: (context) => [
            _popupItem('refresh', Icons.refresh_rounded, 'Refresh'),
            _popupItem('download', Icons.download_rounded, 'Download Models'),
            const PopupMenuDivider(),
            _popupItem('clear', Icons.delete_outline_rounded, 'Clear Data', isDestructive: true),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String label, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.error : AppColors.textPrimary;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildModelStatusChip() {
    final hasRouting = _modelStatus[ModelDownloader.functionGemma] == true;
    final hasReasoning = _modelStatus[ModelDownloader.medGemma] == true;

    final (color, label, icon) = switch ((hasRouting, hasReasoning)) {
      (true, true) => (AppColors.success, 'AI Ready', Icons.auto_awesome),
      (true, false) || (false, true) => (AppColors.warning, 'Partial', Icons.auto_awesome_outlined),
      _ => (AppColors.textTertiary, 'Search', Icons.search),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_patients.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) return _buildSectionHeader();
            final patient = _patients[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PatientCard(patient: patient, onTap: () => _openPatient(patient)),
            );
          },
          childCount: _patients.length + 1,
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Text('Patients', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_patients.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('Downloading Models', style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          for (final model in ModelDownloader.ehrModels) ...[
            Row(
              children: [
                Expanded(child: Text(model.displayName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                Text('${((_downloadProgress[model] ?? 0) * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: _downloadProgress[model] ?? 0, minHeight: 4),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: AppColors.borderLight, shape: BoxShape.circle),
              child: const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 24),
            Text('No Patients Yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Create demo patients to explore the\nEHR Navigator features',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createDemoData,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Demo Data'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _agentService.dispose();
    super.dispose();
  }
}
