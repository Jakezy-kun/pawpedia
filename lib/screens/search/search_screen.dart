import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/breed.dart';
import '../../providers/breed_provider.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_chips.dart';
import '../../widgets/breed_card.dart';
import '../../widgets/empty_state.dart';
import '../breed_detail/breed_detail_screen.dart';

/// Search by name, plus multi-select filters for breed group and origin
/// country.
///
/// Filtering runs against the catalogue `BreedProvider` already holds, so
/// results update as fast as the user can type. The 300ms debounce is still
/// here because it governs when we *would* call the API, and keeps the results
/// count from flickering on every keystroke.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _filtersOpen = false;

  // Pending selections are what the chips show; applied selections are what the
  // results use. "Apply Filters" moves one to the other, so tapping five chips
  // does not re-render the list five times.
  Set<String> _pendingGroups = <String>{};
  Set<String> _pendingCountries = <String>{};
  Set<String> _appliedGroups = <String>{};
  Set<String> _appliedCountries = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppDurations.searchDebounce, () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _cancel() {
    _debounce?.cancel();
    _controller.clear();
    _focus.unfocus();
    setState(() {
      _query = '';
      _filtersOpen = false;
    });
  }

  void _applyFilters() {
    setState(() {
      _appliedGroups = <String>{..._pendingGroups};
      _appliedCountries = <String>{..._pendingCountries};
      _filtersOpen = false;
    });
  }

  void _clearAll() {
    setState(() {
      _pendingGroups = <String>{};
      _pendingCountries = <String>{};
      _appliedGroups = <String>{};
      _appliedCountries = <String>{};
    });
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      if (!target.remove(value)) target.add(value);
    });
  }

  int get _activeFilterCount => _appliedGroups.length + _appliedCountries.length;

  @override
  Widget build(BuildContext context) {
    final BreedProvider breeds = context.watch<BreedProvider>();

    final List<Breed> results = breeds.filter(
      query: _query,
      groups: _appliedGroups,
      countries: _appliedCountries,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _SearchBar(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onQueryChanged,
              onCancel: _cancel,
            ),

            _ResultsHeader(
              count: results.length,
              filtersOpen: _filtersOpen,
              activeFilters: _activeFilterCount,
              onToggle: () => setState(() {
                _filtersOpen = !_filtersOpen;
                if (_filtersOpen) {
                  // Re-open showing what is actually applied, not a stale
                  // half-edited selection from last time.
                  _pendingGroups = <String>{..._appliedGroups};
                  _pendingCountries = <String>{..._appliedCountries};
                  _focus.unfocus();
                }
              }),
            ),

            Expanded(
              child: Stack(
                children: <Widget>[
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screen,
                      0,
                      AppSpacing.screen,
                      // Leave room for the sticky bar when it is showing.
                      _filtersOpen ? 120 : AppSpacing.xl,
                    ),
                    children: <Widget>[
                      if (_filtersOpen) ...<Widget>[
                        _FilterPanel(
                          groups: breeds.groupCounts
                              .map((GroupCount g) => g.group)
                              .toList(),
                          countries: breeds.countries,
                          selectedGroups: _pendingGroups,
                          selectedCountries: _pendingCountries,
                          onToggleGroup: (String g) =>
                              _toggle(_pendingGroups, g),
                          onToggleCountry: (String c) =>
                              _toggle(_pendingCountries, c),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (results.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxl),
                          child: EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No breeds found',
                            message: _query.isEmpty
                                ? 'No breeds match these filters. Try clearing '
                                    'one of them.'
                                : 'Nothing matches "$_query". Try a different '
                                    'spelling or clear your filters.',
                            actionLabel: _activeFilterCount > 0 || _query.isNotEmpty
                                ? 'Clear search'
                                : null,
                            onAction: _activeFilterCount > 0 || _query.isNotEmpty
                                ? () {
                                    _controller.clear();
                                    setState(() => _query = '');
                                    _clearAll();
                                  }
                                : null,
                          ),
                        )
                      else
                        for (final Breed breed in results)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: BreedListCard(
                              breed: breed,
                              onTap: () =>
                                  BreedDetailScreen.open(context, breed),
                            ),
                          ),
                    ],
                  ),

                  if (_filtersOpen)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _StickyFilterBar(
                        onApply: _applyFilters,
                        onClear: _clearAll,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
              decoration: const InputDecoration(
                hintText: 'Search by breed name',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textSecondary, size: 22),
              ),
            ),
          ),
          AppTextButton(label: 'Cancel', onPressed: onCancel),
        ],
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    required this.filtersOpen,
    required this.activeFilters,
    required this.onToggle,
  });

  final int count;
  final bool filtersOpen;
  final int activeFilters;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              count == 1 ? '1 breed found' : '$count breeds found',
              style: text.titleMedium,
            ),
          ),
          Semantics(
            button: true,
            expanded: filtersOpen,
            label: activeFilters == 0
                ? 'Filters'
                : 'Filters, $activeFilters active',
            excludeSemantics: true,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AppSpacing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        filtersOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text('Filters', style: text.titleMedium?.copyWith(fontSize: 14)),
                      if (activeFilters > 0) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$activeFilters',
                            style: text.labelMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.groups,
    required this.countries,
    required this.selectedGroups,
    required this.selectedCountries,
    required this.onToggleGroup,
    required this.onToggleCountry,
  });

  final List<String> groups;
  final List<String> countries;
  final Set<String> selectedGroups;
  final Set<String> selectedCountries;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<String> onToggleCountry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('BREED GROUP', style: AppTextStyles.badgeLabel()),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String group in groups)
                AppFilterChip(
                  label: group,
                  selected: selectedGroups.contains(group),
                  showCheckWhenSelected: true,
                  onTap: () => onToggleGroup(group),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ORIGIN COUNTRY', style: AppTextStyles.badgeLabel()),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String country in countries)
                AppFilterChip(
                  label: country,
                  selected: selectedCountries.contains(country),
                  showCheckWhenSelected: true,
                  onTap: () => onToggleCountry(country),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickyFilterBar extends StatelessWidget {
  const _StickyFilterBar({required this.onApply, required this.onClear});

  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The shell's nav bar already clears the gesture bar, but this sits above
      // it inside the tab, so it takes its own bottom padding too.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(child: PrimaryButton(label: 'Apply Filters', onPressed: onApply)),
          const SizedBox(width: AppSpacing.sm),
          AppTextButton(label: 'Clear All', onPressed: onClear),
        ],
      ),
    );
  }
}
