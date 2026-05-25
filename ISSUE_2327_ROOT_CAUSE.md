# Root Cause of Issue #2327

In issue #2327, calling `appRouter.push(const DetailsRoute())` and immediately notifying `reevaluateListenable` in the same callback skips the push operation.

The issue stems from a race condition between the `_push` operation and `reevaluateGuards()`.
When `push()` is called, the router resolves the route by calling `_canNavigate` internally. `_canNavigate` evaluates the route guards. Since there are no guards in the reproduction case, `_canNavigate` returns a `SynchronousFuture` containing the `ResolverResult`.
However, `push()` calls `_canNavigate` with `await`:
```dart
    final result = await _canNavigate(match, onFailure: onFailure);
    if (result.continueNavigation) {
//...
```
Because of the `await`, the execution of the rest of the `_push` function (which actually adds the new page to the `_pages` stack via `_addNewPage`) is deferred to a future microtask/tick.

Meanwhile, calling `notifyListeners()` on `reevaluateListenable` synchronously triggers `reevaluateGuards()`. `reevaluateGuards` calls `_composeMatchesForReevaluate()` which accesses the current state of the route hierarchy (i.e. the current stack of pages BEFORE the `push` has finished and updated `_pages`).
```dart
  Future<void> reevaluateGuards() async {
    final matches = await _composeMatchesForReevaluate();
    if (matches.isNotEmpty && !_isReevaluating) {
      _isReevaluating = true;
      await _navigateAll(matches, isReevaluating: true);
      _isReevaluating = false;
    }
    notifyAll();
  }
```

By the time the asynchronous `push` operation continues and `_addNewPage` is invoked, `reevaluateGuards` has already captured the old matches (without the newly pushed route).
When `reevaluateGuards` subsequently executes `_navigateAll(matches, isReevaluating: true)`, it does so with the old state, and updates the state. The pending `push()` might be overridden or its state updates interrupted by the re-evaluation rebuilding the tree, effectively ignoring the route that was just pushed.
