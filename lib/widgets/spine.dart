import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/tokens.dart';

/// The signature element: a book's spine, standing on its end, filling
/// bottom-up with the ink you have put into the open read.
///
/// It used to carry graduations for completed reads as well. Two facts in
/// one 12px column read as texture rather than data — nobody decodes a
/// notch — so the read count moved to the row's meta line, where it can
/// simply say so, and the spine is left doing one job.
class Spine extends StatelessWidget {
  const Spine({
    super.key,
    required this.book,
    this.height = 66,
    this.width = 12,
  });

  final Book book;
  final double height;
  final double width;

  /// How full the spine stands. A finished book is full; a dropped book
  /// stops where the reader stopped; an unstarted book is empty.
  double get _level {
    final total = book.totalPages;
    final open = book.openSession;

    if (book.status == BookStatus.read) return 1;
    if (open == null) {
      // Dropped books keep their open session, so anything without one and
      // not marked read has no progress to show.
      return 0;
    }
    if (total == null || total <= 0) return 0;
    return (open.currentPage / total).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dropped = book.status == BookStatus.dropped;

    return Semantics(
      label: _semanticLabel(),
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: _level, end: _level),
          duration: Motion.fill,
          curve: Motion.curve,
          builder: (context, level, _) => CustomPaint(
            painter: _SpinePainter(
              level: level,
              track: c.well,
              ink: dropped ? c.inkFaint : c.accent,
              edge: c.rule,
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final total = book.totalPages;
    final open = book.openSession;
    if (open != null && total != null && total > 0) {
      return '${(_level * 100).round()} percent read';
    }
    if (book.status == BookStatus.read) return 'Finished';
    return 'Not started';
  }
}

class _SpinePainter extends CustomPainter {
  _SpinePainter({
    required this.level,
    required this.track,
    required this.ink,
    required this.edge,
  });

  final double level;
  final Color track;
  final Color ink;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(3),
    );

    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(Offset.zero & size, Paint()..color = track);

    final fillHeight = size.height * level;
    if (fillHeight > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight),
        Paint()..color = ink,
      );
    }
    canvas.restore();

    // A hairline keeps an empty spine legible against the page it sits on.
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_SpinePainter old) =>
      old.level != level ||
      old.ink != ink ||
      old.track != track ||
      old.edge != edge;
}
