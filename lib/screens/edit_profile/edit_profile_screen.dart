import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../core/validators.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state.dart';
import '../profile/profile_screen.dart';

/// Edit display name, start an email change, swap the avatar, and change the
/// password.
///
/// Save stays disabled until something actually differs from what is stored, so
/// the button is never a lie.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  String _originalName = '';
  String _originalEmail = '';
  bool _initialised = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _passwordSectionOpen = false;
  bool _changingPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _hydrate(Profile? profile, String email) {
    if (_initialised) return;
    _originalName = profile?.name ?? '';
    _originalEmail = email;
    _name.text = _originalName;
    _email.text = _originalEmail;
    _initialised = true;
  }

  bool get _isDirty =>
      _name.text.trim() != _originalName.trim() ||
      _email.text.trim() != _originalEmail.trim();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ProfileProvider profiles = context.read<ProfileProvider>();
    final AuthProvider auth = context.read<AuthProvider>();

    final bool nameChanged = _name.text.trim() != _originalName.trim();
    final bool emailChanged = _email.text.trim() != _originalEmail.trim();

    setState(() => _saving = true);
    try {
      if (nameChanged) {
        await profiles.updateName(_name.text.trim());
        _originalName = _name.text.trim();
      }
      if (emailChanged) {
        await auth.updateEmail(_email.text.trim());
        // Deliberately do NOT update _originalEmail: the change is not live
        // until the user clicks the link in the new mailbox, so the field
        // should keep reading as "changed".
      }

      if (!mounted) return;
      setState(() {});
      context.showSnack(
        emailChanged
            ? 'Profile updated. Check your new email for a confirmation link.'
            : 'Profile updated',
      );
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    } catch (_) {
      if (mounted) {
        context.showErrorSnack('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    final AuthProvider auth = context.read<AuthProvider>();

    if (Validators.requiredPassword(_currentPassword.text) != null) {
      context.showErrorSnack('Please enter your current password');
      return;
    }
    final String? newError = Validators.password(_newPassword.text);
    if (newError != null) {
      context.showErrorSnack(newError);
      return;
    }
    final String? confirmError =
        Validators.confirmPassword(_confirmPassword.text, _newPassword.text);
    if (confirmError != null) {
      context.showErrorSnack(confirmError);
      return;
    }

    setState(() => _changingPassword = true);
    try {
      await auth.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      setState(() => _passwordSectionOpen = false);
      context.showSnack('Password changed');
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final ProfileProvider profiles = context.read<ProfileProvider>();
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        // Avatars render at 64dp; anything larger is bandwidth and storage
        // spent on pixels nobody sees.
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploadingAvatar = true);
      await profiles.updateAvatar(File(picked.path));
      if (mounted) context.showSnack('Photo updated');
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    } catch (_) {
      if (mounted) {
        context.showErrorSnack(
          'We could not use that photo. Check the app has permission to access '
          'your camera or gallery.',
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final ProfileProvider profiles = context.read<ProfileProvider>();
    setState(() => _uploadingAvatar = true);
    try {
      await profiles.removeAvatar();
      if (mounted) context.showSnack('Photo removed');
    } on AppException catch (error) {
      if (mounted) context.showErrorSnack(error.message);
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _showAvatarSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: AppColors.primary),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.primary),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.destructive),
              title: const Text('Remove photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _removeAvatar();
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();
    final ProfileProvider profiles = context.watch<ProfileProvider>();

    if (auth.isGuest || !auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile')),
        body: SafeArea(
          child: EmptyState(
            icon: Icons.person_outline_rounded,
            title: 'Create an account to edit your profile',
            message:
                'Guests can browse and shortlist breeds, but a profile needs an '
                'account.',
            actionLabel: 'Create an account',
            onAction: () {
              Navigator.of(context).pop();
              auth.leaveGuest();
            },
          ),
        ),
      );
    }

    _hydrate(profiles.profile, auth.email ?? '');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Go back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Profile'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: AppTextButton(
                label: 'Save',
                // Disabled until a field actually differs from what is stored.
                onPressed: (_isDirty && !_saving) ? _save : null,
                color: _isDirty ? AppColors.primaryDeep : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: _AvatarEditor(
                  photoUrl: profiles.profile?.photoUrl,
                  initials: profiles.profile?.initials ?? '?',
                  busy: _uploadingAvatar,
                  onTap: _showAvatarSheet,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppTextField(
                      label: 'Display Name',
                      controller: _name,
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: Validators.name,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                      onChanged: (_) => setState(() {}),
                      helperText:
                          "You'll need to confirm this change from a link sent "
                          'to your new email address.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),

              Text('SECURITY', style: AppTextStyles.badgeLabel()),
              const SizedBox(height: AppSpacing.md),

              _PasswordSection(
                open: _passwordSectionOpen,
                busy: _changingPassword,
                currentPassword: _currentPassword,
                newPassword: _newPassword,
                confirmPassword: _confirmPassword,
                onToggle: () => setState(
                    () => _passwordSectionOpen = !_passwordSectionOpen),
                onSubmit: _changePassword,
              ),

              const SizedBox(height: AppSpacing.xl),
              Text(
                'Changing your password signs you out of nothing else — your '
                'other devices stay logged in.',
                style: text.labelMedium?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.photoUrl,
    required this.initials,
    required this.busy,
    required this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change profile picture',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 112,
          width: 112,
          child: Stack(
            children: <Widget>[
              Opacity(
                opacity: busy ? 0.5 : 1,
                child: ProfileAvatar(
                  photoUrl: photoUrl,
                  initials: initials,
                  size: 104,
                ),
              ),
              if (busy)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 17,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordSection extends StatelessWidget {
  const _PasswordSection({
    required this.open,
    required this.busy,
    required this.currentPassword,
    required this.newPassword,
    required this.confirmPassword,
    required this.onToggle,
    required this.onSubmit,
  });

  final bool open;
  final bool busy;
  final TextEditingController currentPassword;
  final TextEditingController newPassword;
  final TextEditingController confirmPassword;
  final VoidCallback onToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Semantics(
            button: true,
            expanded: open,
            label: 'Change Password',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.badge,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Change Password',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Icon(
                      open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  const Divider(),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Current password',
                    controller: currentPassword,
                    obscure: true,
                    icon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'New password',
                    controller: newPassword,
                    obscure: true,
                    hint: 'At least 8 characters',
                    icon: Icons.lock_reset_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Confirm new password',
                    controller: confirmPassword,
                    obscure: true,
                    icon: Icons.lock_reset_rounded,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmit(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Update password',
                    isLoading: busy,
                    onPressed: busy ? null : onSubmit,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
