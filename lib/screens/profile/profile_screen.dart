import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/network_breed_image.dart';
import '../../widgets/settings_row.dart';
import '../../widgets/stat_tile.dart';
import '../delete_account/delete_account_screen.dart';
import '../edit_profile/edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const List<String> _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _memberSince(DateTime? date) {
    if (date == null) return 'Member since today';
    return 'Member since ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _logOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log back in at any time.'),
        actions: <Widget>[
          AppTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
            color: AppColors.textSecondary,
          ),
          AppTextButton(
            label: 'Log out',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<AuthProvider>().signOut();
    } catch (_) {
      if (context.mounted) {
        context.showErrorSnack('We could not log you out. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();
    final ProfileProvider profileProvider = context.watch<ProfileProvider>();
    final FavoritesProvider favorites = context.watch<FavoritesProvider>();
    final StatsProvider stats = context.watch<StatsProvider>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.lg,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text('Profile', style: text.displaySmall),
            const SizedBox(height: AppSpacing.lg),

            if (auth.isGuest)
              _GuestCard(onCreateAccount: () => auth.leaveGuest())
            else
              _UserCard(
                profile: profileProvider.profile,
                fallbackName: auth.metadataName,
                email: auth.email ?? '',
                memberSince: _memberSince(auth.memberSince),
              ),

            const SizedBox(height: AppSpacing.lg),

            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    value: '${stats.breedsViewed}',
                    label: 'Breeds viewed',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    value: '${favorites.count}',
                    label: 'Favorites',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    value: '${stats.groupsExplored}',
                    label: 'Groups explored',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            SettingsCard(
              children: <Widget>[
                SettingsRow(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Account details',
                  subtitle: auth.isGuest ? 'Create an account to edit' : null,
                  onTap: () {
                    if (auth.isGuest) {
                      auth.leaveGuest();
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EditProfileScreen(),
                      ),
                    );
                  },
                ),
                SettingsRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  onTap: () => _showPlaceholder(
                    context,
                    'Notifications',
                    'Breed of the Day reminders and shortlist nudges are on the '
                        'roadmap. Nothing is sent to you today.',
                  ),
                ),
                SettingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Privacy',
                  onTap: () => _showPlaceholder(
                    context,
                    'Privacy',
                    'PawPedia stores only your name, email and saved breeds. '
                        'Breed information is read from a public catalogue and '
                        'is never linked to you.',
                  ),
                ),
                SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About PawPedia',
                  onTap: () => _showPlaceholder(
                    context,
                    'About PawPedia',
                    'A friendly directory of dog breeds from around the world, '
                        'made for curious kids and grown-ups alike.',
                  ),
                ),
                SettingsRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & feedback',
                  onTap: () => _showPlaceholder(
                    context,
                    'Help & feedback',
                    'Found a breed that looks wrong, or a dog we are missing? '
                        'Tell the team and we will take a look.',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            if (auth.isGuest)
              SecondaryButton(
                label: 'Exit guest mode',
                icon: Icons.logout_rounded,
                onPressed: () => auth.leaveGuest(),
              )
            else ...<Widget>[
              SecondaryButton(
                label: 'Log out',
                icon: Icons.logout_rounded,
                onPressed: () => _logOut(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: AppTextButton(
                  label: 'Delete account',
                  color: AppColors.destructive,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DeleteAccountScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          AppTextButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.profile,
    required this.fallbackName,
    required this.email,
    required this.memberSince,
  });

  final Profile? profile;
  final String fallbackName;
  final String email;
  final String memberSince;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String name = profile?.name ?? fallbackName;
    final String? photo = profile?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: <Widget>[
          ProfileAvatar(photoUrl: photo, initials: _initialsFor(name), size: 64),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name,
                  style: text.titleLarge?.copyWith(fontSize: 19),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: text.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  memberSince,
                  style: text.labelMedium?.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initialsFor(String name) =>
      Profile(id: '', name: name).initials;
}

class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.onCreateAccount});

  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
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
          Row(
            children: <Widget>[
              const ProfileAvatar(
                photoUrl: null,
                initials: '',
                icon: Icons.pets_rounded,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('Browsing as a guest',
                        style: text.titleLarge?.copyWith(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(
                      'Your favorites stay on this device.',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Create an account',
            onPressed: onCreateAccount,
          ),
        ],
      ),
    );
  }
}

/// Circular avatar that falls back to initials on a pale amber plate.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.size = 64,
    this.icon,
  });

  final String? photoUrl;
  final String initials;
  final double size;

  /// Shown instead of initials where there is no name to abbreviate, such as
  /// the guest card. An emoji here would render in the system emoji font,
  /// which on Android is blue and clashes with the amber plate.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = (photoUrl ?? '').trim().isNotEmpty;

    return Semantics(
      label: 'Profile picture',
      excludeSemantics: true,
      child: Container(
        height: size,
        width: size,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: hasPhoto
            ? NetworkBreedImage(
                url: photoUrl,
                width: size,
                height: size,
                placeholderIconSize: size * 0.4,
              )
            : icon != null
                ? Icon(icon, size: size * 0.45, color: AppColors.textPrimary)
                : Text(
                    initials,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: size * 0.34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
      ),
    );
  }
}
