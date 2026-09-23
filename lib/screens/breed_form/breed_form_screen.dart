import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui_feedback.dart';
import '../../core/validators.dart';
import '../../models/breed.dart';
import '../../models/breed_draft.dart';
import '../../providers/breed_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/dog_photo_service.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/network_breed_image.dart';

/// Add a breed (POST /breeds) or edit one (PUT /breeds/{id}).
///
/// Edit opens with every field filled in from the breed. Validation runs on the
/// device first, with the same limits the API enforces. If the server still
/// rejects something (a duplicate name, say), its message is shown under the
/// field it belongs to.
///
/// Pops with the saved [Breed], or null if the user backed out.
class BreedFormScreen extends StatefulWidget {
  const BreedFormScreen({super.key, this.breed});

  /// The breed to edit, or null to add a new one.
  final Breed? breed;

  static Future<Breed?> open(BuildContext context, {Breed? breed}) {
    return Navigator.of(context).push<Breed>(
      MaterialPageRoute<Breed>(builder: (_) => BreedFormScreen(breed: breed)),
    );
  }

  @override
  State<BreedFormScreen> createState() => _BreedFormScreenState();
}

class _BreedFormScreenState extends State<BreedFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final BreedDraft _initial = widget.breed == null
      ? const BreedDraft(name: '')
      : BreedDraft.fromBreed(widget.breed!);

  late final TextEditingController _name =
      TextEditingController(text: _initial.name);
  late final TextEditingController _group =
      TextEditingController(text: _initial.group);
  late final TextEditingController _country =
      TextEditingController(text: _initial.originCountry);
  late final TextEditingController _lifespan =
      TextEditingController(text: _initial.averageLifespan);
  late final TextEditingController _temperament =
      TextEditingController(text: _initial.temperament);
  late final TextEditingController _picture =
      TextEditingController(text: _initial.picture);

  /// Messages from the server, keyed by API field name. Each one is cleared as
  /// soon as its field is edited.
  final Map<String, String> _serverErrors = <String, String>{};

  bool _saving = false;
  bool _suggestingPhoto = false;

  bool get _isEditing => widget.breed != null;

  BreedDraft get _draft => BreedDraft(
        name: _name.text,
        group: _group.text,
        originCountry: _country.text,
        averageLifespan: _lifespan.text,
        temperament: _temperament.text,
        picture: _picture.text,
      );

  bool get _isDirty => _draft != _initial;

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _country.dispose();
    _lifespan.dispose();
    _temperament.dispose();
    _picture.dispose();
    super.dispose();
  }

  /// A server message for [field] wins over the local rule until the field is
  /// edited again.
  String? Function(String?) _validator(
    String field,
    String? Function(String?) local,
  ) =>
      (String? value) => _serverErrors[field] ?? local(value);

  void _edited(String field) => setState(() => _serverErrors.remove(field));

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(_serverErrors.clear);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final BreedProvider breeds = context.read<BreedProvider>();
    final FavoritesProvider favorites = context.read<FavoritesProvider>();

    setState(() => _saving = true);
    try {
      final Breed saved = _isEditing
          ? await breeds.update(widget.breed!.id, _draft)
          : await breeds.create(_draft);
      if (_isEditing) unawaited(favorites.refreshSnapshot(saved));
      if (mounted) Navigator.of(context).pop(saved);
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() => _serverErrors.addAll(error.fieldErrors));
      _formKey.currentState?.validate();
      context.showErrorSnack(error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Fills the photo field from the Dog CEO API: a photo of this breed when
  /// Dog CEO knows it, otherwise any dog.
  Future<void> _suggestPhoto() async {
    final DogPhotoService photos = context.read<DogPhotoService>();
    setState(() => _suggestingPhoto = true);
    try {
      final String url = await photos.suggestPhoto(_name.text);
      if (!mounted) return;
      setState(() {
        _picture.text = url;
        _serverErrors.remove('picture');
      });
    } catch (error) {
      if (mounted) {
        context.showErrorSnack(ErrorMapper.fromGenericError(error).message);
      }
    } finally {
      if (mounted) setState(() => _suggestingPhoto = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What you have typed will not be saved.'),
        actions: <Widget>[
          AppTextButton(
            label: 'Keep editing',
            onPressed: () => Navigator.of(context).pop(false),
            color: AppColors.textSecondary,
          ),
          AppTextButton(
            label: 'Discard',
            onPressed: () => Navigator.of(context).pop(true),
            color: AppColors.destructive,
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<String> knownGroups = context
        .watch<BreedProvider>()
        .groupCounts
        .map((GroupCount g) => g.group)
        .where((String g) => g != Breed.unknownGroup)
        .toList();
    final String pictureUrl = _picture.text.trim();
    final bool showPreview =
        pictureUrl.isNotEmpty && Validators.pictureUrl(pictureUrl) == null;

    return PopScope<Breed>(
      // Backing out of a half-filled form asks first; saving pops directly.
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (bool didPop, Breed? _) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmDiscard()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Go back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isEditing ? 'Edit Breed' : 'Add Breed'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.lg,
              AppSpacing.screen,
              AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppTextField(
                    label: 'Breed name *',
                    controller: _name,
                    hint: 'e.g. Golden Retriever',
                    icon: Icons.pets_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validator('breed_name', Validators.breedName),
                    onChanged: (_) => _edited('breed_name'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Breed group',
                    controller: _group,
                    hint: 'e.g. Sporting',
                    icon: Icons.category_outlined,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validator(
                      'breed_group',
                      Validators.maxLength(Validators.breedGroupMax),
                    ),
                    onChanged: (_) => _edited('breed_group'),
                  ),
                  if (knownGroups.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        for (final String group in knownGroups)
                          ChoiceChip(
                            label: Text(group),
                            selected: _group.text.trim() == group,
                            onSelected: (_) {
                              _group.text = group;
                              _edited('breed_group');
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Country of origin',
                    controller: _country,
                    hint: 'e.g. Scotland',
                    icon: Icons.location_on_outlined,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validator(
                      'origin_country',
                      Validators.maxLength(Validators.originCountryMax),
                    ),
                    onChanged: (_) => _edited('origin_country'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Average lifespan',
                    controller: _lifespan,
                    hint: 'e.g. 10-12 years',
                    icon: Icons.favorite_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: _validator(
                      'average_lifespan',
                      Validators.maxLength(Validators.lifespanMax),
                    ),
                    onChanged: (_) => _edited('average_lifespan'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Temperament',
                    controller: _temperament,
                    hint: 'e.g. Friendly, Loyal, Playful',
                    helperText: 'Separate traits with commas.',
                    icon: Icons.mood_rounded,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validator(
                      'temperament',
                      Validators.maxLength(Validators.temperamentMax),
                    ),
                    onChanged: (_) => _edited('temperament'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Photo link',
                    controller: _picture,
                    hint: 'https://…',
                    icon: Icons.image_outlined,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    validator: _validator('picture', Validators.pictureUrl),
                    onChanged: (_) => _edited('picture'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _suggestingPhoto ? null : _suggestPhoto,
                      icon: _suggestingPhoto
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryDeep,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 20),
                      label: const Text('Suggest a photo from Dog CEO'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryDeep,
                        minimumSize: const Size(
                          AppSpacing.minTouchTarget,
                          AppSpacing.minTouchTarget,
                        ),
                      ),
                    ),
                  ),
                  if (showPreview) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: AppRadii.cardR,
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: NetworkBreedImage(
                          url: pictureUrl,
                          placeholderIconSize: 48,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: _isEditing ? 'Save changes' : 'Add breed',
                    icon: _isEditing ? Icons.check_rounded : Icons.add_rounded,
                    isLoading: _saving,
                    // Editing: nothing to save until something differs.
                    onPressed: (_isEditing && !_isDirty) ? null : _save,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '* Required',
                    style: text.labelMedium?.copyWith(fontSize: 12),
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
