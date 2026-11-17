import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_dimens.dart';

/// A form field with its label above it (never floating), used by every form
/// so spacing and alignment are identical everywhere.
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.helper,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.obscure = false,
    this.maxLines = 1,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.optional = false,
    this.prefixText,
    this.suffixText,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? hint;
  final String? helper;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  /// Password field: hides the text and shows a show/hide toggle.
  final bool obscure;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final FocusNode? focusNode;

  /// Appends "(facultatif)" to the label.
  final bool optional;
  final String? prefixText;
  final String? suffixText;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            children: [
              if (widget.optional)
                const TextSpan(
                  text: '  facultatif',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedText,
                  ),
                ),
            ],
          ),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
        ),
        const SizedBox(height: AppDimens.sm - 2),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          validator: widget.validator,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 2,
            prefixText: widget.prefixText,
            suffixText: widget.suffixText,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden
                        ? 'Afficher le mot de passe'
                        : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.mutedText,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
