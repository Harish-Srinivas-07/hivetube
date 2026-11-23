import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/hive_logo.dart';
import '../../widgets/ui/ui.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final name = _name.text.trim();
    if (_busy || name.isEmpty || name.length > 30) return;
    setState(() => _busy = true);
    FocusScope.of(context).unfocus();
    try {
      final db = ref.read(dbProvider);
      await db.transaction(() async {
        await db.profileDao.setProfile(name: name);
        await db.setValue('userName', name);
        await db.setValue('onboarded', 'true');
      });
      if (!mounted) return;
      onboardingComplete = true;
      context.go('/home');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valid =
        _name.text.trim().isNotEmpty && _name.text.trim().length <= 30;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.searchMaxWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: HiveLogo()),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    "What's your name?",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We'll use it for your profile",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: 30,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _next(),
                    decoration: InputDecoration(
                      hintText: 'Name',
                      counterText: '',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadius.pillBorder,
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.destructive(
                    label: 'Next',
                    onPressed: valid && !_busy ? _next : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
