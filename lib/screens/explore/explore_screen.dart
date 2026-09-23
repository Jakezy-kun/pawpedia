import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/favorite_actions.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../models/breed.dart';
import '../../providers/auth_provider.dart';
import '../../providers/breed_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/breed_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/featured_breed_card.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/random_dog_card.dart';
import '../breed_detail/breed_detail_screen.dart';
import '../breed_form/breed_form_screen.dart';
import '../shell/main_shell.dart';

/// The home tab: greeting, search entry point, group filter, Breed of the Day,
/// and the full list of breeds.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  /// Null means "All". Explore filters to one group at a time; multi-select
  /// lives on the Search tab.
  String? _selectedGroup;

  /// Opens the Add form (POST). The provider inserts the new breed, so the
  /// list below updates on its own.
  Future<void> _addBreed() async {
    final Breed? created = await BreedFormScreen.open(context);
    if (created == null || !mounted) return;

    // Make sure the new breed is actually visible under the current filter.
    if (_selectedGroup != null && _selectedGroup != created.group) {
      setState(() => _selectedGroup = null);
    }
    context.showSnack(
      '${created.name} added',
      action: SnackBarAction(
        label: 'VIEW',
        onPressed: () => BreedDetailScreen.open(context, created),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BreedProvider breeds = context.watch<BreedProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      floatingActionButton:
          breeds.canEdit && breeds.state == BreedLoadState.ready
              ? FloatingActionButton.extended(
                  onPressed: _addBreed,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add breed'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                )
              : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => breeds.load(force: true),
          child: _buildBody(context, breeds, text),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BreedProvider breeds,
    TextTheme text,
  ) {
    final List<Breed> visible = _selectedGroup == null
        ? breeds.breeds
        : breeds.filter(groups: <String>{_selectedGroup!});

    return CustomScrollView(
      // Always scrollable so pull-to-refresh works even on an error or empty
      // screen, which is exactly when a user wants to retry.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _Greeting()),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.lg,
              AppSpacing.screen,
              AppSpacing.lg,
            ),
            child: _SearchEntry(
              onTap: () =>
                  context.findAncestorStateOfType<MainShellState>()?.goToTab(1),
            ),
          ),
        ),

        if (breeds.state == BreedLoadState.ready && breeds.breeds.isNotEmpty)
          SliverToBoxAdapter(child: _GroupChips(
            counts: breeds.groupCounts,
            total: breeds.breeds.length,
            selected: _selectedGroup,
            onSelected: (String? group) =>
                setState(() => _selectedGroup = group),
          )),

        ..._buildContent(context, breeds, visible, text),

        // Clears the bottom navigation bar, and the Add button when shown.
        SliverToBoxAdapter(
          child: SizedBox(height: AppSpacing.xl + (breeds.canEdit ? 72 : 0)),
        ),
      ],
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    BreedProvider breeds,
    List<Breed> visible,
    TextTheme text,
  ) {
    switch (breeds.state) {
      case BreedLoadState.idle:
      case BreedLoadState.loading:
        return <Widget>[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            sliver: SliverList.separated(
              itemCount: 4,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int i) =>
                  i == 0 ? const FeaturedSkeleton() : const BreedRowSkeleton(),
            ),
          ),
        ];

      case BreedLoadState.error:
        return <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'We could not load breeds',
              message: breeds.error?.message ??
                  'Something went wrong. Please try again.',
              actionLabel: 'Try again',
              onAction: () => breeds.load(force: true),
            ),
          ),
        ];

      case BreedLoadState.ready:
        if (breeds.breeds.isEmpty) {
          return <Widget>[
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.pets_rounded,
                title: 'No breeds found',
                message: 'The catalogue is empty right now. Pull down to refresh.',
                actionLabel: 'Refresh',
                onAction: () => breeds.load(force: true),
              ),
            ),
          ];
        }
        return <Widget>[
          if (_selectedGroup == null && breeds.breedOfTheDay != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.lg,
                  AppSpacing.screen,
                  0,
                ),
                child: _FeaturedSection(breed: breeds.breedOfTheDay!),
              ),
            ),
          if (_selectedGroup == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xl,
                  AppSpacing.screen,
                  0,
                ),
                child: RandomDogCard(),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xl,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _selectedGroup == null
                          ? 'All breeds'
                          : '$_selectedGroup breeds',
                      style: text.titleLarge,
                    ),
                  ),
                  Text(
                    visible.length == 1 ? '1 breed' : '${visible.length} breeds',
                    style: text.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No breeds found',
                message: 'Nothing in this group yet. Try another one.',
                actionLabel: 'Show all breeds',
                onAction: () => setState(() => _selectedGroup = null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              // A builder, not a Column, so only visible rows are laid out.
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (BuildContext _, int _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (BuildContext context, int i) => BreedListCard(
                  breed: visible[i],
                  onTap: () => BreedDetailScreen.open(context, visible[i]),
                ),
              ),
            ),
        ];
    }
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AuthProvider auth = context.watch<AuthProvider>();
    final ProfileProvider profile = context.watch<ProfileProvider>();

    final String who = auth.isGuest ? 'there' : profile.displayName();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Hey $who! 🐾', style: text.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Find your perfect companion', style: text.displaySmall),
        ],
      ),
    );
  }
}

/// Looks like a search field but is a button: tapping it moves to the Search
/// tab, which owns the real input and its debounce.
class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search dog breeds',
      excludeSemantics: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardR,
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardR,
              boxShadow: AppColors.cardShadow,
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Search dog breeds',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: AppColors.badge,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.primaryDeep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({
    required this.counts,
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  final List<GroupCount> counts;
  final int total;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: counts.length + 1,
        separatorBuilder: (BuildContext _, int _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (BuildContext context, int i) {
          if (i == 0) {
            return AppFilterChip(
              label: 'All',
              count: total,
              selected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final GroupCount group = counts[i - 1];
          return AppFilterChip(
            label: group.group,
            count: group.count,
            selected: selected == group.group,
            onTap: () => onSelected(group.group),
          );
        },
      ),
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({required this.breed});

  final Breed breed;

  @override
  Widget build(BuildContext context) {
    final FavoritesProvider favorites = context.watch<FavoritesProvider>();

    return FeaturedBreedCard(
      breed: breed,
      isFavorite: favorites.isFavorite(breed.id),
      onTap: () => BreedDetailScreen.open(context, breed),
      onToggleFavorite: () => FavoriteActions.toggle(context, breed),
    );
  }
}
