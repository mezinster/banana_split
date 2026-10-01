import 'package:banana_split_flutter/widgets/share_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is the widget\'s rectangle in global coordinates',
      (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: const EdgeInsets.only(left: 40, top: 100),
          child: Align(
            alignment: Alignment.topLeft,
            child: Builder(builder: (context) {
              captured = context;
              return const SizedBox(width: 48, height: 24);
            }),
          ),
        ),
      ),
    );

    expect(shareOriginOf(captured), const Rect.fromLTWH(40, 100, 48, 24));
  });
}
