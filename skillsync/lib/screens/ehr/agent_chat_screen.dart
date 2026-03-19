import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../main.dart';
import '../../models/fhir/patient.dart';
import '../../models/agent/agent_state.dart';
import '../../models/agent/cds_alert.dart';
import '../../services/agent/ehr_agent_service.dart';
import '../../widgets/ehr/agent_thinking_view.dart';
import '../../widgets/ehr/trend_chart.dart';

class AgentChatScreen extends StatefulWidget {
  final Patient patient;
  final EhrAgentService agentService;

  const AgentChatScreen({
    super.key,
    required this.patient,
    required this.agentService,
  });

  @override
  State<AgentChatScreen> createState() => _AgentChatScreenState();
}

class _AgentChatScreenState extends State<AgentChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  AgentState? _currentState;
  bool _isProcessing = false;

  final List<CdsAlert> _sessionAlerts = [];
  final Set<String> _acknowledgedAlertIds = {};

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      isUser: false,
      content: 'Ask me anything about **${widget.patient.displayName}**\'s medical records.',
      timestamp: DateTime.now(),
      isWelcome: true,
    ));
  }

  void _addSessionAlerts(List<CdsAlert>? alerts) {
    if (alerts == null || alerts.isEmpty) return;
    for (final alert in alerts) {
      if (!_sessionAlerts.any((a) => a.title == alert.title)) {
        _sessionAlerts.add(alert);
      }
    }
  }

  List<CdsAlert> get _activeAlerts {
    return _sessionAlerts.where((a) => !_acknowledgedAlertIds.contains(a.id)).toList();
  }

  void _acknowledgeAlert(CdsAlert alert) {
    setState(() => _acknowledgedAlertIds.add(alert.id));
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty || _isProcessing) return;

    final query = text.trim();
    _textController.clear();

    setState(() {
      _messages.add(_ChatMessage(isUser: true, content: query, timestamp: DateTime.now()));
      _isProcessing = true;
    });
    _scrollToBottom();

    try {
      await for (final state in widget.agentService.processQuery(widget.patient.id, query)) {
        if (mounted) {
          setState(() => _currentState = state);
          _scrollToBottom();
        }

        if (state.phase == AgentPhase.complete) {
          _addSessionAlerts(state.alerts);
          setState(() {
            _messages.add(_ChatMessage(
              isUser: false,
              content: state.response ?? 'No response generated.',
              timestamp: DateTime.now(),
              steps: state.steps,
              thinking: state.thinking,
              fetchedData: state.fetchedData,
            ));
            _currentState = null;
            _isProcessing = false;
          });
          _scrollToBottom();
        } else if (state.phase == AgentPhase.error) {
          setState(() {
            _messages.add(_ChatMessage(
              isUser: false,
              content: state.error ?? 'An error occurred',
              timestamp: DateTime.now(),
              isError: true,
            ));
            _currentState = null;
            _isProcessing = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(isUser: false, content: 'Error: $e', timestamp: DateTime.now(), isError: true));
          _currentState = null;
          _isProcessing = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_activeAlerts.isNotEmpty) _buildAlertBar(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_currentState != null ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _currentState != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: AgentThinkingView(state: _currentState!),
                  );
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          if (!_isProcessing) _buildQuickActions(),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome, size: 18, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Navigator', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  widget.patient.displayName,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBar() {
    return Container(
      color: AppColors.warning.withOpacity(0.08),
      child: Column(
        children: _activeAlerts.map((alert) => _buildAlertBanner(alert)).toList(),
      ),
    );
  }

  Widget _buildAlertBanner(CdsAlert alert) {
    // Always use warning (yellow/orange) color for alerts
    const color = AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                Text(alert.description, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(
              alert.severityDisplay.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _acknowledgeAlert(alert),
            child: Icon(Icons.close_rounded, size: 18, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    // Hide welcome message once user has sent a message
    if (message.isWelcome) {
      if (_messages.length > 1) return const SizedBox.shrink();
      return _buildWelcomeMessage(message);
    }

    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isError)
                    Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(message.content, style: TextStyle(color: AppColors.error, fontSize: 14)),
                        ),
                      ],
                    )
                  else if (isUser)
                    Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 15))
                  else
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                        strong: const TextStyle(fontWeight: FontWeight.w600),
                        listBullet: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  if (message.thinking != null && message.thinking!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildThinkingSection(message.thinking!),
                  ],
                  if (message.steps != null && message.steps!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildStepsSection(message.steps!),
                  ],
                  if (message.hasTrendData) ...[
                    const SizedBox(height: 16),
                    _buildTrendCharts(message),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildTrendCharts(_ChatMessage message) {
    final charts = <Widget>[];

    // Build vital trend charts
    if (message.vitalTrends != null) {
      final trends = message.vitalTrends!['trends'] as Map<String, dynamic>? ?? {};
      final statistics = message.vitalTrends!['statistics'] as Map<String, dynamic>? ?? {};

      // Check for blood pressure (has systolic/diastolic components)
      final systolicData = trends['8480-6'] as List<dynamic>?;
      final diastolicData = trends['8462-4'] as List<dynamic>?;

      if (systolicData != null && diastolicData != null && systolicData.isNotEmpty) {
        charts.add(
          MultiTrendChart(
            title: 'Blood Pressure',
            series: [
              TrendSeries(
                name: 'Systolic',
                color: Colors.red,
                dataPoints: systolicData.cast<Map<String, dynamic>>(),
              ),
              TrendSeries(
                name: 'Diastolic',
                color: Colors.blue,
                dataPoints: diastolicData.cast<Map<String, dynamic>>(),
              ),
            ],
            height: 180,
          ),
        );
      }

      // Build other vital charts
      for (final entry in statistics.entries) {
        // Skip blood pressure components (already handled above)
        if (entry.key == '8480-6' || entry.key == '8462-4' || entry.key == '85354-9') {
          continue;
        }

        final stat = entry.value as Map<String, dynamic>;
        final display = stat['display'] as String? ?? entry.key;
        final unit = stat['unit'] as String?;
        final dataPoints = trends[entry.key] as List<dynamic>?;

        if (dataPoints != null && dataPoints.length > 1) {
          charts.add(
            TrendChart(
              title: display,
              unit: unit,
              dataPoints: dataPoints.cast<Map<String, dynamic>>(),
              height: 160,
            ),
          );
        }
      }
    }

    // Build lab trend charts
    if (message.labTrends != null) {
      final trends = message.labTrends!['trends'] as Map<String, dynamic>? ?? {};
      final statistics = message.labTrends!['statistics'] as Map<String, dynamic>? ?? {};

      for (final entry in statistics.entries) {
        final stat = entry.value as Map<String, dynamic>;
        final display = stat['display'] as String? ?? entry.key;
        final unit = stat['unit'] as String?;
        final dataPoints = trends[entry.key] as List<dynamic>?;

        if (dataPoints != null && dataPoints.length > 1) {
          charts.add(
            TrendChart(
              title: display,
              unit: unit,
              dataPoints: dataPoints.cast<Map<String, dynamic>>(),
              height: 160,
              lineColor: stat['latestAbnormal'] == true ? Colors.orange : null,
            ),
          );
        }
      }
    }

    if (charts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.show_chart, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Trend Visualizations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        ...charts.map((chart) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: chart,
            )),
      ],
    );
  }

  Widget _buildWelcomeMessage(_ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, size: 30, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI Navigator',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: message.content,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              strong: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: WrapAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingSection(String thinking) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.psychology, size: 12, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(width: 8),
            const Text('Model thinking', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500)),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.1)),
            ),
            child: Text(
              thinking,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6D28D9), fontStyle: FontStyle.italic, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsSection(List<AgentStep> steps) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.account_tree_outlined, size: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 8),
            Text('${steps.length} steps', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
        children: [
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(steps[i].description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('Vital Trends', Icons.show_chart, 'Show me this patient\'s vital sign trends'),
      ('Lab Trends', Icons.science_outlined, 'Show me this patient\'s lab result trends'),
      ('Care Gaps', Icons.assignment_late_outlined, 'Check for overdue screenings'),
      ('Critical Labs', Icons.warning_amber_rounded, 'Show any abnormal lab results'),
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, icon, query) = actions[index];
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _handleSubmit(query),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: AppColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _focusNode.hasFocus ? AppColors.primary.withOpacity(0.5) : AppColors.border,
                  ),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Ask about this patient...',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontSize: 15),
                  onSubmitted: _handleSubmit,
                  enabled: !_isProcessing,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _isProcessing
                    ? null
                    : LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isProcessing ? AppColors.borderLight : null,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isProcessing
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isProcessing ? null : () => _handleSubmit(_textController.text),
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: _isProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary))
                        : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final bool isUser;
  final String content;
  final DateTime timestamp;
  final List<AgentStep>? steps;
  final String? thinking;
  final bool isError;
  final bool isWelcome;
  final Map<String, dynamic>? fetchedData;

  _ChatMessage({
    required this.isUser,
    required this.content,
    required this.timestamp,
    this.steps,
    this.thinking,
    this.isError = false,
    this.isWelcome = false,
    this.fetchedData,
  });

  /// Check if this message contains trend data for visualization
  bool get hasTrendData {
    if (fetchedData == null) return false;
    return fetchedData!.containsKey('get_vital_trends') ||
        fetchedData!.containsKey('get_lab_trends');
  }

  /// Get vital trends data if available
  Map<String, dynamic>? get vitalTrends =>
      fetchedData?['get_vital_trends'] as Map<String, dynamic>?;

  /// Get lab trends data if available
  Map<String, dynamic>? get labTrends =>
      fetchedData?['get_lab_trends'] as Map<String, dynamic>?;
}
