import 'package:flutter/material.dart';
import 'package:vidyasetu/core/theme/app_theme.dart';
import 'package:vidyasetu/core/theme/glass_morphism.dart';
import 'package:vidyasetu/models/challenge_model.dart';
import 'package:vidyasetu/features/challenges/widgets/challenge_card.dart';

// ─── Form state ─────────────────────────────────────────────────────────

class _FormState {
  final int currentStep;
  final ChallengeType? selectedType;
  final String title;
  final String description;
  final String solution;
  final List<String> hints; // up to 3
  final List<Map<String, String>> testCases; // for coding
  final int difficulty;
  final List<String> tags;
  final bool isPreview;
  final bool isPublishing;
  final bool aiAssistLoading;

  const _FormState({
    this.currentStep = 0,
    this.selectedType,
    this.title = '',
    this.description = '',
    this.solution = '',
    this.hints = const ['', '', ''],
    this.testCases = const [],
    this.difficulty = 1,
    this.tags = const [],
    this.isPreview = false,
    this.isPublishing = false,
    this.aiAssistLoading = false,
  });

  _FormState copyWith({
    int? currentStep,
    ChallengeType? selectedType,
    String? title,
    String? description,
    String? solution,
    List<String>? hints,
    List<Map<String, String>>? testCases,
    int? difficulty,
    List<String>? tags,
    bool? isPreview,
    bool? isPublishing,
    bool? aiAssistLoading,
    bool clearType = false,
  }) {
    return _FormState(
      currentStep: currentStep ?? this.currentStep,
      selectedType:
          clearType ? null : (selectedType ?? this.selectedType),
      title: title ?? this.title,
      description: description ?? this.description,
      solution: solution ?? this.solution,
      hints: hints ?? this.hints,
      testCases: testCases ?? this.testCases,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      isPreview: isPreview ?? this.isPreview,
      isPublishing: isPublishing ?? this.isPublishing,
      aiAssistLoading: aiAssistLoading ?? this.aiAssistLoading,
    );
  }

  bool get canAdvance {
    switch (currentStep) {
      case 0:
        return selectedType != null;
      case 1:
        return title.trim().isNotEmpty && description.trim().isNotEmpty;
      case 2:
        return solution.trim().isNotEmpty;
      case 3:
        return true;
      default:
        return false;
    }
  }

  String get stepLabel {
    switch (currentStep) {
      case 0:
        return 'Choose Type';
      case 1:
        return 'Details';
      case 2:
        return 'Solution & Hints';
      case 3:
        return 'Finalize';
      default:
        return '';
    }
  }
}

// ─── Screen ─────────────────────────────────────────────────────────────

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _fadeAnim;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _solutionController = TextEditingController();
  final _hint1Controller = TextEditingController();
  final _hint2Controller = TextEditingController();
  final _hint3Controller = TextEditingController();
  final _tagController = TextEditingController();

  var _state = const _FormState();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _solutionController.dispose();
    _hint1Controller.dispose();
    _hint2Controller.dispose();
    _hint3Controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    _animController.reverse().then((_) {
      setState(() => _state = _state.copyWith(currentStep: step));
      _animController.forward();
    });
  }

  void _next() {
    if (_state.currentStep < 3 && _state.canAdvance) {
      _goToStep(_state.currentStep + 1);
    }
  }

  void _back() {
    if (_state.currentStep > 0) {
      _goToStep(_state.currentStep - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _aiAssist() async {
    setState(() => _state = _state.copyWith(aiAssistLoading: true));
    // TODO: Replace with actual AI service call
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_state.currentStep == 1 && _state.title.isNotEmpty) {
      _descController.text =
          'This is an AI-generated description for "${_state.title}". '
          'Solve this ${_state.selectedType?.name ?? "logic"} challenge '
          'by applying your problem-solving skills.';
      setState(() => _state = _state.copyWith(
            description: _descController.text,
            aiAssistLoading: false,
          ));
    } else if (_state.currentStep == 2) {
      _hint1Controller.text = 'AI Hint 1: Start by breaking the problem down.';
      _hint2Controller.text = 'AI Hint 2: Consider the edge cases carefully.';
      _hint3Controller.text = 'AI Hint 3: The answer involves recursion.';
      setState(() => _state = _state.copyWith(
            hints: [
              _hint1Controller.text,
              _hint2Controller.text,
              _hint3Controller.text,
            ],
            aiAssistLoading: false,
          ));
    } else {
      setState(() => _state = _state.copyWith(aiAssistLoading: false));
    }
  }

  Future<void> _publish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.backgroundSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text('Publish Challenge?',
            style: AppTheme.headerStyle(fontSize: 18)),
        content: Text(
          'Your challenge "${_state.title}" will be visible to all users.',
          style: AppTheme.bodyStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _state = _state.copyWith(isPublishing: true));
    try {
      // TODO: Replace with actual publish service call
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.accentGreen),
                const SizedBox(width: 8),
                Text('Challenge published!',
                    style: AppTheme.bodyStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppTheme.surfaceLight,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _state = _state.copyWith(isPublishing: false));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish: $e'),
            backgroundColor: AppTheme.accentMagenta,
          ),
        );
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_state.tags.contains(tag)) {
      setState(
          () => _state = _state.copyWith(tags: [..._state.tags, tag]));
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() => _state =
        _state.copyWith(tags: _state.tags.where((t) => t != tag).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundPrimary,
      body: Container(
        decoration: AppTheme.scaffoldDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppTheme.accentCyan, size: 20),
                      onPressed: _back,
                    ),
                    Expanded(
                      child: Text(
                        'CREATE CHALLENGE',
                        style: AppTheme.headerStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // AI Assist button
                    if (_state.currentStep == 1 || _state.currentStep == 2)
                      _AiAssistButton(
                        isLoading: _state.aiAssistLoading,
                        onTap: _aiAssist,
                      ),
                  ],
                ),
              ),

              // ── Step indicator ──
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: _StepIndicator(
                  currentStep: _state.currentStep,
                  totalSteps: 4,
                ),
              ),

              // ── Step label ──
              Text(
                _state.stepLabel,
                style: AppTheme.headerStyle(
                  fontSize: 14,
                  color: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(height: 16),

              // ── Step content ──
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: _buildStep(),
                  ),
                ),
              ),

              // ── Bottom navigation ──
              _BottomNav(
                currentStep: _state.currentStep,
                canAdvance: _state.canAdvance,
                isPublishing: _state.isPublishing,
                isPreview: _state.isPreview,
                onBack: _state.currentStep > 0 ? _back : null,
                onNext: _state.currentStep < 3 ? _next : null,
                onPublish: _state.currentStep == 3 ? _publish : null,
                onTogglePreview: _state.currentStep == 3
                    ? () => setState(() =>
                        _state = _state.copyWith(isPreview: !_state.isPreview))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_state.currentStep) {
      case 0:
        return _buildTypeSelection();
      case 1:
        return _buildDetailsStep();
      case 2:
        return _buildSolutionStep();
      case 3:
        return _state.isPreview ? _buildPreview() : _buildFinalizeStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Type selection ──

  Widget _buildTypeSelection() {
    return Column(
      children: ChallengeType.values.map((type) {
        final style = ChallengeTypeStyle.fromType(type);
        final selected = _state.selectedType == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () =>
                setState(() => _state = _state.copyWith(selectedType: type)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: GlassMorphism(
                borderRadius: 18,
                borderColor:
                    selected ? style.color : AppTheme.glassBorder,
                borderWidth: selected ? 1.5 : 0.8,
                glowColor: selected ? style.color : null,
                glowBlurRadius: selected ? 16 : 0,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: style.color.withAlpha(selected ? 40 : 20),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: style.color.withAlpha(60),
                                  blurRadius: 16,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(style.icon,
                          color: style.color,
                          size: selected ? 30 : 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.name[0].toUpperCase() + type.name.substring(1),
                            style: AppTheme.bodyStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? style.color
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _typeDescription(type),
                            style: AppTheme.bodyStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: style.color, size: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _typeDescription(ChallengeType type) {
    switch (type) {
      case ChallengeType.logic:
        return 'Puzzles that test logical thinking and deduction';
      case ChallengeType.coding:
        return 'Programming problems with test cases';
      case ChallengeType.reasoning:
        return 'Critical thinking and pattern recognition';
      case ChallengeType.cybersecurity:
        return 'Security challenges: CTF, crypto, forensics';
      case ChallengeType.math:
        return 'Mathematical problems and proofs';
    }
  }

  // ── Step 2: Details ──

  Widget _buildDetailsStep() {
    return Column(
      children: [
        _GlassTextField(
          controller: _titleController,
          label: 'Challenge Title',
          hint: 'Enter a catchy title...',
          onChanged: (v) =>
              setState(() => _state = _state.copyWith(title: v)),
        ),
        const SizedBox(height: 16),
        _GlassTextField(
          controller: _descController,
          label: 'Description',
          hint: 'Describe the challenge in detail...',
          maxLines: 8,
          onChanged: (v) =>
              setState(() => _state = _state.copyWith(description: v)),
        ),
      ],
    );
  }

  // ── Step 3: Solution & Hints ──

  Widget _buildSolutionStep() {
    final isCoding = _state.selectedType == ChallengeType.coding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GlassTextField(
          controller: _solutionController,
          label: 'Solution',
          hint: isCoding
              ? '// Expected solution code...'
              : 'The correct answer...',
          maxLines: isCoding ? 8 : 3,
          isCode: isCoding,
          onChanged: (v) =>
              setState(() => _state = _state.copyWith(solution: v)),
        ),
        if (isCoding) ...[
          const SizedBox(height: 20),
          _TestCasesEditor(
            testCases: _state.testCases,
            onChanged: (cases) =>
                setState(() => _state = _state.copyWith(testCases: cases)),
          ),
        ],
        const SizedBox(height: 20),
        Text('Hints (optional)',
            style: AppTheme.headerStyle(fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          'Provide up to 3 progressively helpful hints.',
          style: AppTheme.bodyStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
          ),
        ),
        const SizedBox(height: 12),
        _GlassTextField(
          controller: _hint1Controller,
          label: 'Hint 1 (Subtle)',
          hint: 'A gentle nudge...',
          onChanged: (v) {
            final hints = List<String>.from(_state.hints);
            hints[0] = v;
            setState(() => _state = _state.copyWith(hints: hints));
          },
        ),
        const SizedBox(height: 12),
        _GlassTextField(
          controller: _hint2Controller,
          label: 'Hint 2 (Moderate)',
          hint: 'A more direct hint...',
          onChanged: (v) {
            final hints = List<String>.from(_state.hints);
            hints[1] = v;
            setState(() => _state = _state.copyWith(hints: hints));
          },
        ),
        const SizedBox(height: 12),
        _GlassTextField(
          controller: _hint3Controller,
          label: 'Hint 3 (Strong)',
          hint: 'Almost gives it away...',
          onChanged: (v) {
            final hints = List<String>.from(_state.hints);
            hints[2] = v;
            setState(() => _state = _state.copyWith(hints: hints));
          },
        ),
      ],
    );
  }

  // ── Step 4: Finalize ──

  Widget _buildFinalizeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Difficulty
        Text('Difficulty', style: AppTheme.headerStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final level = i + 1;
            final selected = level <= _state.difficulty;
            return GestureDetector(
              onTap: () =>
                  setState(() => _state = _state.copyWith(difficulty: level)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  selected ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 36,
                  color: selected ? AppTheme.accentGold : AppTheme.textDisabled,
                  shadows: selected
                      ? [
                          Shadow(
                            color: AppTheme.accentGold.withAlpha(80),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            ['Beginner', 'Easy', 'Medium', 'Hard', 'Expert']
                [_state.difficulty - 1],
            style: AppTheme.bodyStyle(
              fontSize: 13,
              color: AppTheme.accentGold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Tags
        Text('Tags', style: AppTheme.headerStyle(fontSize: 14)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GlassMorphism(
                borderRadius: 12,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _tagController,
                  style: AppTheme.bodyStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add tag...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _addTag(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.accentCyan.withAlpha(60)),
                ),
                child: const Icon(Icons.add_rounded,
                    color: AppTheme.accentCyan, size: 20),
              ),
            ),
          ],
        ),
        if (_state.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _state.tags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.accentPurple.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tag,
                        style: AppTheme.bodyStyle(
                          fontSize: 12,
                          color: AppTheme.accentPurple,
                        )),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _removeTag(tag),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: AppTheme.accentPurple),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ── Preview ──

  Widget _buildPreview() {
    final typeStyle = _state.selectedType != null
        ? ChallengeTypeStyle.fromType(_state.selectedType!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text('PREVIEW',
              style: AppTheme.headerStyle(
                fontSize: 12,
                color: AppTheme.accentCyan,
              )),
        ),
        const SizedBox(height: 16),
        GlassMorphism.glow(
          glowColor: typeStyle?.color ?? AppTheme.accentCyan,
          glowBlurRadius: 16,
          borderRadius: 18,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (typeStyle != null)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: typeStyle.color.withAlpha(30),
                      ),
                      child: Icon(typeStyle.icon,
                          color: typeStyle.color, size: 22),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_state.title,
                        style: AppTheme.headerStyle(fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < _state.difficulty
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: i < _state.difficulty
                          ? AppTheme.accentGold
                          : AppTheme.textDisabled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _state.description,
                style: AppTheme.bodyStyle(color: AppTheme.textSecondary),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
              if (_state.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _state.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.glassFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.glassBorder),
                      ),
                      child: Text(tag,
                          style: AppTheme.bodyStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          )),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Private widgets ────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.totalSteps});
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepBefore = i ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepBefore < currentStep
                  ? AppTheme.accentCyan
                  : AppTheme.glassBorder,
            ),
          );
        }
        final step = i ~/ 2;
        final isActive = step == currentStep;
        final isCompleted = step < currentStep;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppTheme.accentCyan.withAlpha(30)
                : isCompleted
                    ? AppTheme.accentCyan.withAlpha(20)
                    : AppTheme.glassFill,
            border: Border.all(
              color: isActive || isCompleted
                  ? AppTheme.accentCyan
                  : AppTheme.glassBorder,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.accentCyan.withAlpha(40),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded,
                    color: AppTheme.accentCyan, size: 16)
                : Text(
                    '${step + 1}',
                    style: AppTheme.bodyStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppTheme.accentCyan
                          : AppTheme.textTertiary,
                    ),
                  ),
          ),
        );
      }),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.isCode = false,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  final bool isCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism(
      borderRadius: 14,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTheme.bodyStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              )),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: maxLines,
            style: isCode
                ? AppTheme.bodyStyle(fontSize: 13).copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  )
                : AppTheme.bodyStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: isCode
                  ? AppTheme.backgroundPrimary.withAlpha(180)
                  : AppTheme.glassFill,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestCasesEditor extends StatelessWidget {
  const _TestCasesEditor({
    required this.testCases,
    required this.onChanged,
  });

  final List<Map<String, String>> testCases;
  final ValueChanged<List<Map<String, String>>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Test Cases',
                style: AppTheme.headerStyle(fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                onChanged([
                  ...testCases,
                  {'input': '', 'expected': ''},
                ]);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.accentGreen.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: AppTheme.accentGreen, size: 14),
                    const SizedBox(width: 4),
                    Text('Add',
                        style: AppTheme.bodyStyle(
                          fontSize: 11,
                          color: AppTheme.accentGreen,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...testCases.asMap().entries.map((entry) {
          final idx = entry.key;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassMorphism.subtle(
              borderRadius: 12,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Case ${idx + 1}',
                          style: AppTheme.bodyStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentCyan,
                          )),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          final updated = List<Map<String, String>>.from(
                              testCases);
                          updated.removeAt(idx);
                          onChanged(updated);
                        },
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.accentMagenta, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Input',
                      contentPadding: const EdgeInsets.all(10),
                      filled: true,
                      fillColor: AppTheme.backgroundPrimary.withAlpha(160),
                    ),
                    style: AppTheme.bodyStyle(fontSize: 12)
                        .copyWith(fontFamily: 'monospace'),
                    onChanged: (v) {
                      final updated =
                          List<Map<String, String>>.from(testCases);
                      updated[idx] = {...updated[idx], 'input': v};
                      onChanged(updated);
                    },
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Expected output',
                      contentPadding: const EdgeInsets.all(10),
                      filled: true,
                      fillColor: AppTheme.backgroundPrimary.withAlpha(160),
                    ),
                    style: AppTheme.bodyStyle(fontSize: 12)
                        .copyWith(fontFamily: 'monospace'),
                    onChanged: (v) {
                      final updated =
                          List<Map<String, String>>.from(testCases);
                      updated[idx] = {...updated[idx], 'expected': v};
                      onChanged(updated);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _AiAssistButton extends StatelessWidget {
  const _AiAssistButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppTheme.secondaryGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.neonGlow(AppTheme.accentPurple, blur: 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.textPrimary,
                ),
              )
            else
              const Icon(Icons.auto_awesome_rounded,
                  size: 14, color: AppTheme.textPrimary),
            const SizedBox(width: 6),
            Text(
              'AI Assist',
              style: AppTheme.bodyStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.currentStep,
    required this.canAdvance,
    required this.isPublishing,
    required this.isPreview,
    this.onBack,
    this.onNext,
    this.onPublish,
    this.onTogglePreview,
  });

  final int currentStep;
  final bool canAdvance;
  final bool isPublishing;
  final bool isPreview;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onPublish;
  final VoidCallback? onTogglePreview;

  @override
  Widget build(BuildContext context) {
    return GlassMorphism.subtle(
      borderRadius: 0,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          if (onBack != null)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          const Spacer(),
          if (onTogglePreview != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: onTogglePreview,
                icon: Icon(
                  isPreview ? Icons.edit_rounded : Icons.visibility_rounded,
                  size: 18,
                ),
                label: Text(isPreview ? 'Edit' : 'Preview'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentPurple,
                  side: const BorderSide(color: AppTheme.accentPurple),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          if (onNext != null)
            Container(
              decoration: BoxDecoration(
                gradient: canAdvance
                    ? AppTheme.primaryGradient
                    : null,
                color: canAdvance ? null : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: canAdvance ? onNext : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Text('Next'),
                label: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ),
          if (onPublish != null)
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.successGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    AppTheme.neonGlow(AppTheme.accentGreen, blur: 10),
              ),
              child: ElevatedButton.icon(
                onPressed: isPublishing ? null : onPublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: isPublishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.backgroundPrimary,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(isPublishing ? 'Publishing...' : 'Publish'),
              ),
            ),
        ],
      ),
    );
  }
}
