import 'package:flutter/material.dart';

/// Hand-built palette and scales for the "Ledger" direction.
///
/// Nothing here is generated from a seed colour — each value was picked
/// against the others. The rule that keeps the app coherent: [accent] means
/// reading progress and completed reads, and nothing else. Navigation,
/// buttons and headings are ink, never accent.
class LedgerColors {
  const LedgerColors({
    required this.ground,
    required this.panel,
    required this.well,
    required this.plate,
    required this.rule,
    required this.ruleStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.accentQuiet,
    required this.onInk,
    required this.danger,
  });

  /// The paper the whole app is printed on. Book rows sit straight on it —
  /// there is no card between a row and the page.
  final Color ground;

  /// A block that has to lift slightly off the paper: a stat figure, the
  /// open-read panel on a book.
  final Color panel;

  /// Recessed area — search field, spine track, progress track.
  final Color well;

  /// A cover with no image. On paper it prints darker than the page; at
  /// night it has to lift off the ground instead, or the letter on it
  /// disappears into a black rectangle.
  final Color plate;

  /// Hairline between rows.
  final Color rule;

  /// Hairline that has to carry weight (active tab, focused field).
  final Color ruleStrong;

  /// Primary text, and the fill of solid buttons.
  final Color ink;

  /// Authors, meta lines, inactive tabs.
  final Color inkMuted;

  /// Placeholders, disabled, empty pips.
  final Color inkFaint;

  /// Reading progress and completed reads. Nothing else.
  final Color accent;

  /// Accent at low emphasis — read notches over a filled spine.
  final Color accentQuiet;

  /// Text on top of [ink].
  final Color onInk;

  /// Destructive actions and error states only.
  final Color danger;

  static const light = LedgerColors(
    ground: Color(0xFFE9ECE5),
    panel: Color(0xFFF3F5F0),
    well: Color(0xFFD8DDD4),
    plate: Color(0xFFD3D9CF),
    rule: Color(0xFFBBC2B8),
    ruleStrong: Color(0xFF59625C),
    ink: Color(0xFF141A18),
    inkMuted: Color(0xFF4F5853),
    inkFaint: Color(0xFF87908A),
    accent: Color(0xFF95293C),
    accentQuiet: Color(0xFFF3F5F0),
    onInk: Color(0xFFF3F5F0),
    danger: Color(0xFF95293C),
  );

  /// Not an OLED black with one hot accent — that pairing is the other
  /// stock look. The night ground stays a lifted slate-green so the hue
  /// still reads, and the accent stays a wine rather than a pink.
  static const dark = LedgerColors(
    ground: Color(0xFF1E2622),
    panel: Color(0xFF27302C),
    well: Color(0xFF151B18),
    plate: Color(0xFF303A35),
    rule: Color(0xFF38423E),
    ruleStrong: Color(0xFF8B948F),
    ink: Color(0xFFE8EBE7),
    inkMuted: Color(0xFFA0A8A3),
    inkFaint: Color(0xFF6C746F),
    accent: Color(0xFFB4485C),
    accentQuiet: Color(0xFF27302C),
    onInk: Color(0xFF1E2622),
    danger: Color(0xFFCF6274),
  );
}

/// 4px base grid. Named for the role, not the pixel count.
abstract final class Space {
  static const hair = 2.0;
  static const tight = 4.0;
  static const snug = 8.0;
  static const step = 12.0;
  static const gutter = 16.0;
  static const block = 24.0;
  static const section = 32.0;
}

/// Small and consistent: never a pill, never zero.
abstract final class Radii {
  static const cover = BorderRadius.all(Radius.circular(2));
  static const chip = BorderRadius.all(Radius.circular(3));
  static const field = BorderRadius.all(Radius.circular(6));
  static const block = BorderRadius.all(Radius.circular(10));
}

/// Two animations in the whole app: the spine filling, and the tab rule
/// sliding. Both are feedback, neither is decoration.
abstract final class Motion {
  static const fill = Duration(milliseconds: 220);
  static const tab = Duration(milliseconds: 160);
  static const curve = Curves.easeOutCubic;
}

/// Minimum touch target, applied to every tappable thing.
const double kTapTarget = 48.0;

/// On-device Android families. No downloaded fonts — this app makes no
/// network calls, and a font fetch would be its first.
abstract final class Faces {
  /// Titles and screen headers.
  static const display = 'sans-serif-condensed';

  /// Authors and prose.
  static const body = 'Roboto';

  /// Every number, date, count and status label.
  static const utility = 'monospace';
}

/// Digits that line up in a column, everywhere they appear.
const kTabular = <FontFeature>[FontFeature.tabularFigures()];

extension LedgerTheme on BuildContext {
  LedgerColors get c => Theme.of(this).brightness == Brightness.dark
      ? LedgerColors.dark
      : LedgerColors.light;
}
