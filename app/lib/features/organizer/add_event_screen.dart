import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/category_labels.dart';
import '../../core/error_text.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'event_image_upload.dart';
import 'organizer_providers.dart';
import 'venue_picker.dart';

enum _VenueMode { existingPlace, droppedPin }

/// The Organizer submission form (PLAN.md §4 Phase 2). Everything it produces
/// lands as `status='pending'` — approval is a Curator action in the Supabase
/// dashboard, so this screen never pretends the event is live.
class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({super.key});

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  _VenueMode _venueMode = _VenueMode.existingPlace;
  PlaceOption? _place;
  LatLng? _pin;
  EventCategory? _category;
  DateTime? _startsAt;
  DateTime? _endsAt;
  XFile? _imageFile;
  Uint8List? _imageBytes;

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(eventCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.organizerAddEvent)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.organizerPendingNote,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.organizerTitle),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.organizerErrorTitleRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration:
                    InputDecoration(labelText: l10n.organizerDescription),
              ),
              const SizedBox(height: 16),
              categories.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, _) => AppErrorText(l10n.pinsLoadError),
                data: (list) => DropdownButtonFormField<EventCategory>(
                  initialValue: _category,
                  decoration:
                      InputDecoration(labelText: l10n.organizerCategory),
                  items: [
                    for (final category in list)
                      DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 12, color: category.color),
                            const SizedBox(width: 8),
                            Text(categoryLabel(l10n, category.slug)),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) => value == null
                      ? l10n.organizerErrorCategoryRequired
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Text(l10n.organizerVenue,
                  style: Theme.of(context).textTheme.titleMedium),
              // RadioGroup ancestor: RadioListTile's own groupValue/onChanged
              // are deprecated in this Flutter version.
              RadioGroup<_VenueMode>(
                groupValue: _venueMode,
                onChanged: (mode) => setState(() => _venueMode = mode!),
                child: Column(
                  children: [
                    RadioListTile<_VenueMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.organizerVenueExisting),
                      value: _VenueMode.existingPlace,
                    ),
                    RadioListTile<_VenueMode>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.organizerVenuePin),
                      value: _VenueMode.droppedPin,
                    ),
                  ],
                ),
              ),
              if (_venueMode == _VenueMode.existingPlace)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront),
                  title: Text(_place?.name ?? l10n.organizerPickPlace),
                  subtitle: _place?.address == null
                      ? null
                      : Text(_place!.address!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await pickExistingPlace(context);
                    if (picked != null) setState(() => _place = picked);
                  },
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_location_alt_outlined),
                  title: Text(_pin == null
                      ? l10n.organizerPickOnMap
                      : '${l10n.organizerCoordinates}: '
                          '${_pin!.latitude.toStringAsFixed(5)}, '
                          '${_pin!.longitude.toStringAsFixed(5)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await Navigator.of(context).push<LatLng>(
                      MaterialPageRoute(
                        builder: (_) => PinPickerScreen(initial: _pin),
                      ),
                    );
                    if (picked != null) setState(() => _pin = picked);
                  },
                ),
              const SizedBox(height: 16),
              _DateTimeField(
                label: l10n.organizerStartsAt,
                value: _startsAt,
                locale: l10n.localeName,
                onChanged: (value) => setState(() => _startsAt = value),
              ),
              const SizedBox(height: 8),
              _DateTimeField(
                label: l10n.organizerEndsAt,
                value: _endsAt,
                locale: l10n.localeName,
                clearLabel: l10n.organizerClear,
                onChanged: (value) => setState(() => _endsAt = value),
              ),
              const SizedBox(height: 24),
              Text(l10n.organizerImage,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_imageBytes != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(_imageBytes == null
                          ? l10n.organizerAddImage
                          : l10n.organizerReplaceImage),
                      onPressed: _busy
                          ? null
                          : () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: l10n.organizerAddImage,
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed:
                        _busy ? null : () => _pickImage(ImageSource.camera),
                  ),
                  if (_imageBytes != null)
                    IconButton(
                      tooltip: l10n.organizerRemoveImage,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _imageFile = null;
                                _imageBytes = null;
                              }),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                AppErrorText(_error!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.organizerSubmit),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await pickEventImage(source);
      if (file == null) return;
      // Bytes, not a File path: Image.memory renders identically on web,
      // where dart:io does not exist.
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = file;
        _imageBytes = bytes;
      });
    } catch (_) {
      if (mounted) showErrorSnack(context, l10n.organizerImageFailed);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final venueOk = _venueMode == _VenueMode.existingPlace
        ? _place != null
        : _pin != null;
    if (!venueOk) {
      setState(() => _error = l10n.organizerErrorVenueRequired);
      return;
    }
    final startsAt = _startsAt;
    if (startsAt == null) {
      setState(() => _error = l10n.organizerErrorStartRequired);
      return;
    }
    if (_endsAt != null && !_endsAt!.isAfter(startsAt)) {
      setState(() => _error = l10n.organizerErrorEndBeforeStart);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Upload only once the rest of the form is valid, so an abandoned draft
      // never leaves an orphaned object in the bucket.
      String? imageUrl;
      final file = _imageFile;
      if (file != null) {
        final userId = ref.read(currentUserProvider)!.id;
        imageUrl = await uploadEventImage(file, userId);
      }
      await submitEvent(
        ref,
        EventDraft(
          title: _title.text,
          description: _description.text,
          categoryId: _category!.id,
          placeId: _venueMode == _VenueMode.existingPlace ? _place!.id : null,
          lat: _venueMode == _VenueMode.droppedPin ? _pin!.latitude : null,
          lng: _venueMode == _VenueMode.droppedPin ? _pin!.longitude : null,
          startsAt: startsAt,
          endsAt: _endsAt,
          imageUrl: imageUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      showInfoSnack(context, l10n.organizerSubmitted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.organizerSubmitFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Date + time in one row. Two pickers rather than one combined widget:
/// Flutter has no Material date-and-time picker, and an Event Night regularly
/// starts on one calendar day at a time that belongs to the previous one
/// (ADR 0004) — so the date has to be chosen explicitly, never inferred.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.locale,
    required this.onChanged,
    this.clearLabel,
  });

  final String label;
  final DateTime? value;
  final String locale;
  final ValueChanged<DateTime?> onChanged;
  final String? clearLabel;

  @override
  Widget build(BuildContext context) {
    final formatted = value == null
        ? null
        : DateFormat.yMMMEd(locale).add_Hm().format(value!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.schedule),
      title: Text(label),
      subtitle: formatted == null ? null : Text(formatted),
      trailing: value != null && clearLabel != null
          ? IconButton(
              tooltip: clearLabel,
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            )
          : const Icon(Icons.chevron_right),
      onTap: () async {
        final now = DateTime.now();
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 1)),
          lastDate: now.add(const Duration(days: 730)),
        );
        if (date == null || !context.mounted) return;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(value ?? now),
        );
        if (time == null) return;
        onChanged(DateTime(
            date.year, date.month, date.day, time.hour, time.minute));
      },
    );
  }
}
