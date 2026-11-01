// ProfileSetupScreen - collects swimmer profile on first launch.
// Also used when editing profile from Settings (isEditing=true shows back button).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../providers/profile_provider.dart';

/// Profile setup screen - shown once on first launch after connecting.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  /// When true, shows a back button (editing from Settings).
  final bool isEditing;

  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  String  _gender    = 'male';
  bool    _saving    = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final existing = ref.read(profileProvider);
    if (existing != null) {
      _nameCtrl.text   = existing.name;
      _ageCtrl.text    = existing.age.toString();
      _heightCtrl.text = existing.heightCm.toString();
      _weightCtrl.text = existing.weightKg.toString();
      _gender          = existing.gender;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _saveError = null; });

    try {
      final profile = UserProfile(
        name:     _nameCtrl.text.trim(),
        age:      int.parse(_ageCtrl.text.trim()),
        heightCm: int.parse(_heightCtrl.text.trim()),
        weightKg: int.parse(_weightCtrl.text.trim()),
        gender:   _gender,
      );
      await ref.read(profileProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      context.go('/main');
    } catch (e) {
      setState(() {
        _saving    = false;
        _saveError = 'Could not save profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwimTrackColors.background,
      appBar: AppBar(
        title: Text(
          'About You',
          style: SwimTrackTextStyles.screenTitle(color: Colors.white),
        ),
        automaticallyImplyLeading: widget.isEditing,
        backgroundColor: SwimTrackColors.primary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'We use this to calculate your swimming efficiency accurately.',
                style: SwimTrackTextStyles.body(),
              ),
              const SizedBox(height: 28),

              _FormField(
                label: 'Full Name',
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                hintText: 'e.g. Alex Johnson',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Name is required';
                  if (v.trim().length < 2) return 'Name is too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _FormField(
                label: 'Age',
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                hintText: '25',
                suffix: 'years',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Age is required';
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 5 || n > 100) return 'Age must be 5–100';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _FormField(
                label: 'Height',
                controller: _heightCtrl,
                keyboardType: TextInputType.number,
                hintText: '175',
                suffix: 'cm',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Height is required';
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 100 || n > 250) return 'Height must be 100–250 cm';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _FormField(
                label: 'Weight',
                controller: _weightCtrl,
                keyboardType: TextInputType.number,
                hintText: '70',
                suffix: 'kg',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Weight is required';
                  final n = int.tryParse(v.trim());
                  if (n == null) return 'Enter a valid number';
                  if (n < 20 || n > 200) return 'Weight must be 20–200 kg';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Text(
                'Gender',
                style: SwimTrackTextStyles.label(
                    color: SwimTrackColors.textSecondary),
              ),
              const SizedBox(height: 8),
              _GenderSelector(
                selected: _gender,
                onChanged: (v) => setState(() => _gender = v),
              ),

              if (_saveError != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SwimTrackColors.bad.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: SwimTrackColors.bad.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: SwimTrackColors.bad, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_saveError!,
                            style: SwimTrackTextStyles.label(
                                color: SwimTrackColors.bad)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwimTrackColors.primary,
                    disabledBackgroundColor:
                        SwimTrackColors.primary.withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: SwimTrackColors.primary.withValues(alpha: 0.3),
                  ),
                  child: _saving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('Saving…',
                                style: SwimTrackTextStyles.cardTitle(
                                    color: Colors.white)),
                          ],
                        )
                      : Text(
                          widget.isEditing ? 'Save Changes' : 'Save & Continue',
                          style: SwimTrackTextStyles.cardTitle(
                              color: Colors.white),
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

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final String? hintText;
  final String? suffix;
  final String? Function(String?)? validator;

  const _FormField({
    required this.label,
    required this.controller,
    required this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.hintText,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: SwimTrackTextStyles.label(
                color: SwimTrackColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.next,
          validator: validator,
          style: SwimTrackTextStyles.body(color: SwimTrackColors.dark),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle:
                SwimTrackTextStyles.body(color: SwimTrackColors.textHint),
            suffixText: suffix,
            suffixStyle:
                SwimTrackTextStyles.body(color: SwimTrackColors.textHint),
            filled: true,
            fillColor: SwimTrackColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: SwimTrackColors.divider, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: SwimTrackColors.divider, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: SwimTrackColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: SwimTrackColors.bad, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: SwimTrackColors.bad, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _GenderSelector({required this.selected, required this.onChanged});

  static const _options = [
    ('male',   'Male'),
    ('female', 'Female'),
    ('other',  'Other'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.asMap().entries.map((entry) {
        final idx        = entry.key;
        final value      = entry.value.$1;
        final label      = entry.value.$2;
        final isSelected = selected == value;
        final isFirst    = idx == 0;
        final isLast     = idx == _options.length - 1;

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? SwimTrackColors.primary : SwimTrackColors.card,
                borderRadius: BorderRadius.horizontal(
                  left:  isFirst ? const Radius.circular(12) : Radius.zero,
                  right: isLast  ? const Radius.circular(12) : Radius.zero,
                ),
                border: Border.all(
                  color: isSelected
                      ? SwimTrackColors.primary
                      : SwimTrackColors.divider,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: SwimTrackTextStyles.body(
                  color: isSelected
                      ? Colors.white
                      : SwimTrackColors.textSecondary,
                ).copyWith(
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}