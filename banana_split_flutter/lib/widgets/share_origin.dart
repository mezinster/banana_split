import 'package:flutter/widgets.dart';

/// The on-screen rectangle of [context]'s widget, for share_plus's
/// `sharePositionOrigin`.
///
/// iOS anchors the share sheet's popover to it. iPads always needed one; since
/// iOS 26 iPhones do too, and share_plus 9 refuses to present the sheet without
/// a non-empty origin ("sharePositionOrigin: argument must be set") — the app
/// showed "Error sharing file" instead. Pass the context of the control the
/// user tapped (wrap it in a [Builder] if needed). Null when that widget isn't
/// laid out; elsewhere the origin is ignored.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
