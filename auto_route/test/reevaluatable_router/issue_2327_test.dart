import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../main_router.dart';
import '../router_test_utils.dart';

void main() {
  testWidgets('Pushing a route and triggering reevaluation synchronously should push the route',
      (WidgetTester tester) async {
    final reevaluationNotifier = ValueNotifier(false);
    final router = RootStackRouter.build(routes: [
      AutoRoute(page: FirstRoute.page, initial: true),
      AutoRoute(page: SecondRoute.page),
    ])
      ..ignorePopCompleters = true;

    await pumpRouterApp(tester, router, reevaluationNotifier: reevaluationNotifier);

    expectTopPage(router, FirstRoute.name);

    // Simulate the race condition described in issue 2327
    unawaited(router.push(const SecondRoute()));
    reevaluationNotifier.value = true; // immediately notify

    await tester.pumpAndSettle();

    // EXPECTATION: The second route should be successfully pushed.
    // However, due to the bug, it is skipped/interrupted. This test should fail
    // if the fix is not implemented, correctly verifying the bug reproduction.
    expectTopPage(router, SecondRoute.name);
  });
}
