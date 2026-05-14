import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/app_theme.dart';
import '../widgets/premium_components.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _type = 'Suggestion';
  bool _submitted = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdventureBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
            children: [
              Row(
                children: [
                  GlowIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onTap: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 12),
                  Text('Feedback', style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 20),
              PremiumPanel(
                borderColor: AppColors.orange.withValues(alpha: .36),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Help improve My Yezdi', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text(
                        'Report bugs, share suggestions, or leave a rider review.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'Bug', label: Text('Bug'), icon: Icon(Icons.bug_report)),
                          ButtonSegment(value: 'Suggestion', label: Text('Idea'), icon: Icon(Icons.lightbulb)),
                          ButtonSegment(value: 'Review', label: Text('Review'), icon: Icon(Icons.star)),
                        ],
                        selected: {_type},
                        onSelectionChanged: (value) => setState(() => _type = value.first),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _messageController,
                        maxLines: 6,
                        validator: (value) => value == null || value.trim().length < 8
                            ? 'Tell us a little more'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'What should we improve for your rides?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GradientActionButton(
                        icon: Icons.send,
                        label: 'Submit feedback',
                        expanded: true,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: .06, end: 0),
              if (_submitted) ...[
                const SizedBox(height: 18),
                PremiumPanel(
                  glowColor: AppColors.green.withValues(alpha: .18),
                  borderColor: AppColors.green.withValues(alpha: .36),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppColors.green, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Feedback captured locally. Backend submission can be connected when the API is ready.',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(begin: const Offset(.96, .96)).fadeIn(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
      _messageController.clear();
    });
  }
}
