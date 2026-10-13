import 'package:flutter/material.dart';
import '../core/owner_l10n.dart';
import '../core/owner_state.dart';

/// Localizes a label from a fixed Russian canonical key.
/// Domain entities (restaurant names, user names, server names) remain unchanged.
class OwnerText extends StatelessWidget {
  final String label;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  const OwnerText(this.label, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  @override
  Widget build(BuildContext context) {
    final language = OwnerScope.of(context).language;
    return Text(
      OwnerL10n.tr(language, label),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }
}
