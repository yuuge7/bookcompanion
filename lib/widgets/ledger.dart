import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared pieces of the ledger. Small, unstyled-looking on purpose: the
/// personality lives in the palette, the density and the [Spine], not in
/// decoration bolted onto controls.

/// A flat block on the ground. Value and a hairline separate it — never a
/// shadow, and never Material's elevation tint.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.gutter),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final body = Container(
      decoration: BoxDecoration(
        color: c.panel,
        borderRadius: Radii.block,
        border: Border.all(color: c.rule),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.block,
        child: body,
      ),
    );
  }
}

/// Data voice: monospace, lowercase, tracked, tabular. Every number in the
/// app is set this way so columns line up down a list.
class Meta extends StatelessWidget {
  const Meta(
    this.text, {
    super.key,
    this.color,
    this.size = 12,
    this.weight,
    this.maxLines = 1,
  });

  final String text;
  final Color? color;
  final double size;
  final FontWeight? weight;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: Faces.utility,
        fontSize: size,
        height: 1.3,
        letterSpacing: 0.6,
        fontWeight: weight,
        color: color ?? context.c.inkMuted,
        fontFeatures: kTabular,
      ),
    );
  }
}

/// A book's shelf, said quietly. Outlined, never filled — filled colour is
/// reserved for progress.
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.snug, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: Radii.chip,
        border: Border.all(color: c.rule),
      ),
      child: Meta(label, color: c.inkMuted, size: 11),
    );
  }
}

/// A rating, as five slots in ink. Deliberately not gold stars — a second
/// bright colour would compete with the spine for meaning.
///
/// Takes a whole rating only. Drawing an average this way rounded 4.7 up to
/// five filled slots, which is a picture that disagrees with the number
/// beside it; averages are shown as the figure instead.
class RatingPips extends StatelessWidget {
  const RatingPips({super.key, required this.rating, this.size = 6});

  /// 1–5, as recorded on a single read.
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final filled = rating.clamp(0, 5);
    return Semantics(
      label: '$rating out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return Container(
            width: size,
            height: size,
            margin: EdgeInsets.only(right: i == 4 ? 0 : 3),
            decoration: BoxDecoration(
              color: i < filled ? c.ink : Colors.transparent,
              border: Border.all(color: i < filled ? c.ink : c.inkFaint),
              borderRadius: const BorderRadius.all(Radius.circular(1)),
            ),
          );
        }),
      ),
    );
  }
}

/// Rating input. Keeps the familiar five-star shape, but in ink — a second
/// bright colour would compete with the spine, which is the only thing on
/// screen allowed to be the accent.
///
/// Tapping the star that is already selected clears the rating, so a read
/// can be un-rated without a separate control.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final star = i + 1;
            final on = value != null && star <= value!;
            final clears = value == star;
            return IconButton(
              icon: Icon(on ? Icons.star : Icons.star_border, size: 26),
              color: on ? c.ink : c.inkFaint,
              tooltip: clears ? 'Clear rating' : '$star out of 5',
              onPressed: () => onChanged(clears ? null : star),
            );
          }),
        ),
        Meta(
          value == null ? 'not rated' : '$value of 5',
          size: 11,
          color: value == null ? c.inkFaint : c.inkMuted,
        ),
      ],
    );
  }
}

/// A section marker: label on the left, a rule running out to the edge.
/// The rule shows where the section reaches, which is information; a bare
/// bold heading is not.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.label, {super.key, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Meta(label, color: c.ink, size: 12, weight: FontWeight.w600),
        const SizedBox(width: Space.step),
        Expanded(child: Container(height: 1, color: c.rule)),
        if (trailing != null) ...[
          const SizedBox(width: Space.step),
          trailing!,
        ],
      ],
    );
  }
}

/// Counts above labels, because in a reading log the number is the point.
/// The active tab is marked by a 2px rule sliding along a 1px baseline —
/// no pill, no ripple-filled indicator.
class LedgerTabs extends StatelessWidget {
  const LedgerTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.counts,
  });

  final TabController controller;
  final List<String> labels;
  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // The strip has to grow with the text scale — at 2x a fixed height
    // clipped the labels into the baseline rule.
    final scaler = MediaQuery.textScalerOf(context);
    final height = scaler.scale(22) * 1.1 + scaler.scale(11) * 1.3 + 26;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / labels.length;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: c.rule),
              ),
              Row(
                children: List.generate(labels.length, (i) {
                  final active = controller.index == i;
                  return Expanded(
                    child: Semantics(
                      button: true,
                      selected: active,
                      label: '${labels[i]}, ${counts[i]} books',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => controller.animateTo(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${counts[i]}',
                              style: TextStyle(
                                fontFamily: Faces.display,
                                fontSize: 22,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: active ? c.ink : c.inkFaint,
                                fontFeatures: kTabular,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.tight,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Meta(
                                  labels[i],
                                  size: 11,
                                  color: active ? c.ink : c.inkMuted,
                                  weight: active ? FontWeight.w600 : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
              AnimatedBuilder(
                animation: controller.animation ?? controller,
                builder: (context, _) {
                  final value =
                      controller.animation?.value ?? controller.index.toDouble();
                  return Positioned(
                    left: tabWidth * value,
                    width: tabWidth,
                    bottom: 0,
                    child: Container(height: 2, color: c.ink),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// An empty surface is an invitation, so it names the next move rather
/// than reporting that a list has zero items.
///
/// Anchored near the top, where the first entry would be, instead of
/// floating in the middle of a tall blank body.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      markColor: context.c.ruleStrong,
      headline: headline,
      body: body,
      actions: [
        if (actionLabel != null && onAction != null)
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

/// Errors say what happened and what to do about it, in the app's voice.
/// They never print an exception, and they offer the recovery they name.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.headline,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String headline;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return _StatePanel(
      markColor: context.c.danger,
      headline: headline,
      body: body,
      actions: [
        if (actionLabel != null && onAction != null)
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        if (secondaryLabel != null && onSecondary != null)
          OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
      ],
    );
  }
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.markColor,
    required this.headline,
    required this.body,
    required this.actions,
  });

  final Color markColor;
  final String headline;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.block,
        Space.block,
        Space.block,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 34, height: 2, color: markColor),
          const SizedBox(height: Space.gutter),
          Text(headline, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Space.snug),
          Text(
            body,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: c.inkMuted),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: Space.gutter),
            Wrap(spacing: Space.snug, runSpacing: Space.snug, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Loading is a held frame, not a spinner in the middle of nothing: the
/// rows that are about to arrive, drawn as empty rules.
class LoadingRows extends StatelessWidget {
  const LoadingRows({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Loading your library',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(count, (i) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.snug,
            ),
            child: Row(
              children: [
                Container(width: 8, height: 66, color: c.well),
                const SizedBox(width: Space.step),
                Container(width: 46, height: 66, color: c.well),
                const SizedBox(width: Space.gutter),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 13, width: 180, color: c.well),
                      const SizedBox(height: Space.snug),
                      Container(height: 11, width: 110, color: c.well),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
