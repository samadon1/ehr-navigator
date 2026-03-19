import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../main.dart';
import '../../models/fhir/patient.dart';
import '../../services/agent/comparison_service.dart';
import '../../services/agent/ehr_agent_service.dart';
import '../../services/ehr/fhir_query_service.dart';

class ComparisonScreen extends StatefulWidget {
  final Patient patient;
  final EhrAgentService agentService;

  const ComparisonScreen({
    super.key,
    required this.patient,
    required this.agentService,
  });

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  ComparisonService? _comparisonService;
  ComparisonState? _state;
  bool _isInitializing = true;
  bool _isRunning = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      _comparisonService = ComparisonService(
        fhirService: FhirQueryService(),
        agentService: widget.agentService,
      );

      await _comparisonService!.initialize(
        onProgress: (progress, status) {
          debugPrint('Comparison init: $status ($progress)');
        },
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _initError = e.toString();
        });
      }
    }
  }

  Future<void> _runComparison(String query) async {
    if (query.trim().isEmpty || _isRunning || _comparisonService == null) return;

    _textController.clear();
    setState(() {
      _isRunning = true;
      _state = null;
    });

    try {
      await for (final state in _comparisonService!.compare(widget.patient.id, query)) {
        if (mounted) {
          setState(() {
            _state = state;
            _isRunning = state.isRunning;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.compare_arrows, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Compare Approaches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text(
                  widget.patient.displayName,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isInitializing)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading comparison models...', style: TextStyle(color: AppColors.textSecondary)),
                    SizedBox(height: 8),
                    Text('This may take a moment', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ],
                ),
              ),
            )
          else if (_initError != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Failed to initialize', style: TextStyle(color: AppColors.error)),
                    const SizedBox(height: 8),
                    Text(_initError!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else ...[
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.purple.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.science_outlined, size: 18, color: Colors.purple[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Comparing: Agent (tools) vs LLM (context stuffing) vs RAG (embeddings)',
                      style: TextStyle(fontSize: 12, color: Colors.purple[700]),
                    ),
                  ),
                ],
              ),
            ),

            // Results area
            Expanded(
              child: _state == null
                  ? _buildWelcome()
                  : _buildResults(),
            ),

            // Input area
            _buildInputArea(),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withOpacity(0.2), Colors.blue.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.compare_arrows, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Compare AI Approaches',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ask a question to see how Agent, LLM, and RAG\napproaches compare side-by-side',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            children: [
              _buildSuggestionChip('What medications is the patient taking?'),
              _buildSuggestionChip('Is diabetes controlled?'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String query) {
    return ActionChip(
      label: Text(query, style: const TextStyle(fontSize: 12)),
      onPressed: () => _runComparison(query),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: AppColors.border),
    );
  }

  Widget _buildResults() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildResultCard('Agent', _state!.agent, Colors.green, Icons.auto_awesome)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildResultCard('LLM Direct', _state!.llm, Colors.orange, Icons.chat_bubble_outline)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildResultCard('RAG', _state!.rag, Colors.blue, Icons.search)),
      ],
    );
  }

  Widget _buildResultCard(String title, ApproachResult result, Color color, IconData icon) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                      if (result.isComplete)
                        Text(
                          '${result.duration.inMilliseconds}ms',
                          style: TextStyle(fontSize: 11, color: color.withOpacity(0.8)),
                        ),
                    ],
                  ),
                ),
                if (result.isComplete)
                  Icon(Icons.check_circle, size: 18, color: color)
                else
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: result.error != null
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.error!,
                              style: const TextStyle(fontSize: 12, color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    )
                  : result.response.isEmpty
                      ? Center(
                          child: Text(
                            result.isComplete ? 'No response' : 'Processing...',
                            style: const TextStyle(color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MarkdownBody(
                              data: result.response,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 13, height: 1.5),
                                strong: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            // Show retrieved chunks for RAG
                            if (result.approach == 'rag' && result.retrievedChunks != null) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Retrieved ${result.retrievedChunks!.length} chunks:',
                                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              ...result.retrievedChunks!.take(3).map((chunk) => Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                                    ),
                                    child: Text(
                                      chunk,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  )),
                            ],
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Ask a question to compare approaches...',
                hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onSubmitted: _runComparison,
              enabled: !_isRunning,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: _isRunning
                  ? null
                  : const LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: _isRunning ? AppColors.borderLight : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isRunning ? null : () => _runComparison(_textController.text),
                borderRadius: BorderRadius.circular(12),
                child: Center(
                  child: _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
                        )
                      : const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _comparisonService?.dispose();
    super.dispose();
  }
}
