import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../core/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/empty_state.dart';
import 'check_inbox_screen.dart';

enum _Mode { login, signUp }

/// One screen for both logging in and signing up, switched by a segmented
/// toggle.
///
/// There is no Google or Apple button here by design — PawPedia authenticates
/// with email and password only, plus guest mode.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  _Mode _mode = _Mode.login;
  bool _busy = false;
  String? _formError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _isSignUp => _mode == _Mode.signUp;

  void _switchMode(_Mode mode) {
    if (_mode == mode) return;
    setState(() {
      _mode = mode;
      _formError = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AuthProvider auth = context.read<AuthProvider>();
    if (!auth.accountsAvailable) {
      setState(() => _formError =
          'Accounts are not set up yet. Add your Supabase keys to .env, or '
          'continue as a guest.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_isSignUp) {
        final bool needsConfirmation = await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
        if (!mounted) return;
        if (needsConfirmation) {
          // No session yet: the user has to click the emailed link first.
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CheckInboxScreen(email: _email.text.trim()),
            ),
          );
        }
        // Otherwise AuthGate swaps us to the main shell on its own.
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _formError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _formError = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await context.read<AuthProvider>().continueAsGuest();
  }

  Future<void> _forgotPassword() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final TextEditingController controller =
        TextEditingController(text: _email.text.trim());

    final String? email = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Enter your email and we will send you a link to set a new '
              'password.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: 'Email',
              controller: controller,
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: <Widget>[
          AppTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            color: AppColors.textSecondary,
          ),
          AppTextButton(
            label: 'Send link',
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          ),
        ],
      ),
    );

    controller.dispose();
    if (email == null || email.isEmpty) return;
    if (Validators.email(email) != null) {
      if (mounted) context.showErrorSnack('Please enter a valid email address');
      return;
    }

    try {
      await auth.sendPasswordReset(email);
      if (mounted) {
        context.showSnack('If that email has an account, a reset link is on its way.');
      }
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            // Keyboard insets are added to the padding so the focused field is
            // always reachable and the form never overflows.
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.md,
              AppSpacing.screen,
              AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (Navigator.of(context).canPop()) ...<Widget>[
                      CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        semanticLabel: 'Go back',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    const BrandHeader(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  _isSignUp ? 'Create your account' : 'Welcome back',
                  style: text.displaySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isSignUp
                      ? 'Save favorites and sync them across devices.'
                      : 'Log in to pick up where you left off.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),

                _ModeToggle(mode: _mode, onChanged: _switchMode),
                const SizedBox(height: AppSpacing.xl),

                if (!auth.accountsAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: InfoBanner(
                      message:
                          'Accounts are not configured yet. You can still browse '
                          'every breed as a guest.',
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (_isSignUp) ...<Widget>[
                        AppTextField(
                          key: const ValueKey<String>('name'),
                          label: 'Name',
                          controller: _name,
                          hint: 'Riley Parker',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          validator: Validators.name,
                          autofillHints: const <String>[AutofillHints.name],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      // Keyed so that Name appearing above them in Sign up
                      // mode cannot shift each field onto its neighbour's
                      // state — that is how Email inherited Password's
                      // obscured text.
                      AppTextField(
                        key: const ValueKey<String>('email'),
                        label: 'Email',
                        controller: _email,
                        hint: 'you@example.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                        autofillHints: const <String>[AutofillHints.email],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        key: const ValueKey<String>('password'),
                        label: 'Password',
                        controller: _password,
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline_rounded,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        // At sign-in an existing password just has to be
                        // present; telling someone their stored password is
                        // "too short" would be nonsense.
                        validator: _isSignUp
                            ? Validators.password
                            : Validators.requiredPassword,
                        autofillHints: <String>[
                          _isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                      ),
                    ],
                  ),
                ),

                if (!_isSignUp)
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppTextButton(
                      label: 'Forgot password?',
                      onPressed: _busy ? null : _forgotPassword,
                      color: AppColors.primaryDeep,
                    ),
                  ),

                if (_formError != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _FormError(message: _formError!),
                ],

                SizedBox(height: _isSignUp ? AppSpacing.xl : AppSpacing.md),
                PrimaryButton(
                  label: _isSignUp ? 'Create account' : 'Log in',
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: AppTextButton(
                    label: 'Continue as Guest',
                    onPressed: _busy ? null : _continueAsGuest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The white-pill-on-pale-amber segmented control.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.badge.withValues(alpha: 0.5),
        borderRadius: AppRadii.buttonR,
      ),
      child: Row(
        children: <Widget>[
          _Segment(
            label: 'Log in',
            selected: mode == _Mode.login,
            onTap: () => onChanged(_Mode.login),
          ),
          _Segment(
            label: 'Sign up',
            selected: mode == _Mode.signUp,
            onTap: () => onChanged(_Mode.signUp),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: AppSpacing.minTouchTarget,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected ? AppColors.cardShadow : null,
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: AppRadii.buttonR,
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.destructive),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }
}
