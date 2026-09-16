import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';

/// Account deletion, as a full screen rather than a dialog.
///
/// A dialog would force the consequences into two lines of small text. This is
/// permanent and uncancellable, so the list of what disappears gets room to be
/// read, and the whole thing scrolls so it survives a short viewport and a
/// large system font.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _password = TextEditingController();

  bool _verifying = false;
  bool _deleting = false;
  bool _passwordConfirmed = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _confirmPassword() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final bool ok = await context.read<AuthProvider>().verifyPassword(_password.text);
    if (!mounted) return;

    setState(() {
      _verifying = false;
      _passwordConfirmed = ok;
      _error = ok ? null : 'That password is incorrect.';
    });
  }

  Future<void> _delete() async {
    final AuthProvider auth = context.read<AuthProvider>();
    final FavoritesProvider favorites = context.read<FavoritesProvider>();
    final StatsProvider stats = context.read<StatsProvider>();
    final NavigatorState navigator = Navigator.of(context);

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await auth.deleteAccount();

      // The server-side rows cascaded. Clear what lives on this handset too, so
      // the next person to use the phone inherits nothing.
      await favorites.clearLocal();
      await stats.reset();

      if (!mounted) return;
      // AuthGate rebuilds to the signed-out tree on its own; popping to the
      // root just removes this screen from under it.
      navigator.popUntil((Route<dynamic> route) => route.isFirst);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = 'Something went wrong. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final FavoritesProvider favorites = context.watch<FavoritesProvider>();

    final int favoriteCount = favorites.count;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      height: 88,
                      width: 88,
                      decoration: BoxDecoration(
                        color: AppColors.destructive.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 42,
                        color: AppColors.destructive,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Delete your account?',
                    style: text.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'This is permanent and cannot be undone. There is no way for '
                    'us to bring your account back afterwards.',
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadii.cardR,
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'What gets deleted',
                          style: text.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _Bullet('Your profile and login details'),
                        _Bullet(
                          favoriteCount == 1
                              ? 'Your 1 saved favorite breed'
                              : 'Your $favoriteCount saved favorite breeds',
                        ),
                        const _Bullet('Your activity history'),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  Text('Confirm it is you', style: text.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter your password to enable the delete button.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscure: true,
                    icon: Icons.lock_outline_rounded,
                    enabled: !_passwordConfirmed && !_deleting,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _confirmPassword(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_passwordConfirmed)
                    Row(
                      children: <Widget>[
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Password confirmed.',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    )
                  else
                    SecondaryButton(
                      label: 'Confirm password',
                      isLoading: _verifying,
                      onPressed: _verifying ? null : _confirmPassword,
                    ),

                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.error_outline_rounded,
                            size: 18, color: AppColors.destructive),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: text.bodyMedium
                                ?.copyWith(color: AppColors.destructive),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  DestructiveButton(
                    label: 'Delete my account',
                    isLoading: _deleting,
                    onPressed:
                        (_passwordConfirmed && !_deleting) ? _delete : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Cancel is a full-width, easy target: leaving should always
                  // be the simpler path of the two.
                  Center(
                    child: AppTextButton(
                      label: 'Cancel',
                      onPressed:
                          _deleting ? null : () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_deleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FDF8F0),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.destructive),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 7, right: AppSpacing.md),
            height: 6,
            width: 6,
            decoration: const BoxDecoration(
              color: AppColors.destructive,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
