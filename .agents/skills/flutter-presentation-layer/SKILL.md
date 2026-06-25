---
name: flutter-presentation-layer
description: "**WORKFLOW SKILL** — Opinionated conventions for the presentation layer in Flutter Clean Architecture (pages, cubits, widgets, localization)."
---

# Flutter Presentation Layer (Clean Architecture)

Purpose: Provide a concise, opinionated set of conventions and quick prompts for implementing the presentation layer (UI + state) in a Flutter Clean Architecture project.

Principles
- Each UI *page* lives in its own folder so all page-specific artifacts are colocated.
- Each `Cubit` has a single responsibility: one cubit per action/intent (fetch, post, delete, etc.).
- Widgets live as close as possible to where they're used. Only genuinely shared components go into a global `widgets` folder.
- Keep `build()` methods clean: extract widget-building functions into private class methods or small private widgets.
- All user-facing strings must come from the localization system (ARB, `S`, `AppLocalizations`, etc.).
- For CRUD-like flows, split by intent explicitly: one cubit to list items, one to add/create item, one to delete item, and one to remove item from a local collection/state (if this action differs from backend delete).

Folder layout (recommended)

Use a feature-first layout. Example for a `user` feature with a `list` page:

- `lib/features/user/presentation/user_list/`
  - `user_list_page.dart`    # page entry (Widget)
  - `cubit/`
    - `user_list/`
      - `user_list_cubit.dart`   # cubit with single responsibility (e.g., fetch list)
      - `user_list_state.dart`   # states for the cubit 
  - `widgets/`               # page-scoped widgets used only by this page
    - `user_row.dart`
    - `user_loading.dart`

Shared UI components (only for true reuse)

- `lib/shared/widgets/`      # cross-feature shared widgets (buttons, inputs, avatars)
- `lib/core/localization/`   # localization ARB files and generated accessors

Cubit conventions

- Name: `<feature>_<page>_<action>_cubit.dart` OR for simpler cases `<page>_cubit.dart` with clearly separated methods. The important rule is one cubit per action/intent.
- Each cubit should:
  - Represent a single asynchronous intent (fetch, create, delete, update).
  - Expose a minimal API: one method to trigger the action and one public state stream.
  - Map domain errors to UI-friendly states. Do not embed domain logic—call usecases.

Examples:
- `user_list_cubit` — only responsible for fetching the list of users.
- `user_create_cubit` — only responsible for sending a create-user request and reporting success/failure.
- `item_list_cubit` — only responsible for listing items.
- `item_add_cubit` — only responsible for adding a new item.
- `item_delete_cubit` — only responsible for deleting an item in the backend/source of truth.
- `item_remove_cubit` — only responsible for removing an item from current UI state/local cache when modeled as a distinct action.

Practical SRP split for Cubits

When the page supports multiple intents, avoid a “god cubit”. Prefer one cubit per intent:

- `ListItemsCubit`: loads and refreshes item collections.
- `AddItemCubit`: handles create/add submission flow.
- `DeleteItemCubit`: executes delete use case against remote/local source of truth.
- `RemoveItemCubit`: removes an element from an in-memory list/UI state when this is a separate intent from delete.

This separation keeps each cubit focused, easier to test, and aligned with the Single Responsibility Principle (SRP).

Widget placement and composition

- Keep small, page-private widgets under the page's `widgets/` folder.
- Only move a widget to `lib/shared/widgets/` when at least two pages use it and its contract is stable.
- Prefer small focused widgets instead of large build methods with many nested conditionals.

Clean `build()` pattern

Bad:

class UserListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(body: ButtonPrimary(onPressed: () {
      // handle click
    }, ...))
  }
}

Good:

class UserListPage extends StatefulWidget { ... }

class _UserListPageState extends State<UserListPage> {
  void _onClick() {
    // handle click
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: ButtonPrimary(onPressed: _onClick, ...));
}

- Extract callbacks private methods instead of inline functions inside `build()`.
- Extract complex UI sections into small widgets to keep `build()` focused on composition.
- Avoid functions that return widgets with complex logic; prefer small widgets that can be tested in isolation.
- For conditional UI, consider using separate widgets for each state (loading, empty, data) instead of nested conditionals in `build()`.

Strings & Localization

- All visible strings must come from the project's localization accessor (`S.of(context)`, `AppLocalizations.of(context)`, or the project's convention).
- Add keys to ARB files during scaffolding; include a comment describing the context for translators.
- Tests should verify that pages reference localization keys (not hardcoded strings).

Testing hints

- Write `Cubit` unit tests that assert state transitions for success/failure cases.
- Add widget tests that:
  - Pump the page with mocked cubits and verify correct localized text is displayed.
  - Verify that page-scoped widgets render expected states (loading, empty, data).

Quick prompts (examples you can paste into chat to generate scaffolding)

- "Scaffold a `user_list` page with a `user_list_cubit` that fetches users, a `widgets/user_row.dart`, and add localization keys `user_list.title` and `user_list.empty`." 
- "Generate `user_create_cubit` that posts a new user and returns success/failure states; include unit tests for success and server-error mapping."

Checklist (pre-PR)

- Page folder exists and contains `page.dart`, `cubits/`, and `widgets/` if needed.
- Cubit implements a single responsibility and is covered by unit tests.
- No hardcoded strings remain in the page; all visible text uses localization keys.
- Shared widgets only live in `lib/shared/widgets/` and are used by at least two pages.
- Build methods are small; UI complexity is extracted to private methods or widgets.
