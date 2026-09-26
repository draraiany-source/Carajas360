# Fase 7 — Flutter analyze warnings audit

Generated: 2026-09-25T01:36:27.363Z  
Source: `docs/evidence/fase7_analyze.txt`  
Flutter reported: **161** issues (parser matched **161** lines).

## Severity summary (release-freeze criteria)

| Severity | Count | Notes |
|----------|------:|-------|
| **CRITICAL** | 5 | Crash risk, security, publish blockers, or clear bugs |
| **IMPORTANT** | 10 | Correctness / lifecycle / memory edge cases; post-freeze |
| **COSMETIC** | 146 | Style, deprecations (non-blocking per `analysis_options.yaml`), unused imports |

| Analyzer level | Count |
|----------------|------:|
| `warning` | 83 |
| `info` | 78 |

## CRITICAL — fix now?

**Yes** — unguarded `BuildContext` after async (dispose crash risk).

### CRITICAL items (5)

- `lib/features/monetization/monetization_screens.dart:168` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with…
- `lib/features/monetization/monetization_screens.dart:171` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with…
- `lib/features/monetization/monetization_screens.dart:255` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with…
- `lib/features/monetization/monetization_screens.dart:257` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with…
- `lib/features/monetization/opportunities_screen.dart:473` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps. Try rewriting the code to not use the 'BuildContext', or guard the use with…

## IMPORTANT (all items)

- `lib/features/admin/admin_screen.dart:654` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/admin/admin_screen.dart:659` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/auth/auth_screen.dart:678` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/chat/chat_screen.dart:212` — **deprecated_member_use**: 'bytes' is deprecated and shouldn't be used. Use readAsBytes() instead to avoid out-of-memory issues with large files. T…
- `lib/features/health/health_screen.dart:596` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/health/health_screen.dart:597` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/profile/profile_screens.dart:797` — **unnecessary_null_comparison**: The operand can't be 'null', so the condition is always 'true'. Remove the condition
- `lib/features/support/support_screens.dart:687` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/features/support/support_screens.dart:690` — **use_build_context_synchronously**: Don't use 'BuildContext's across async gaps, guarded by an unrelated 'mounted' check. Guard a 'State.context' use with a…
- `lib/shared/services/firestore_facade.dart:188` — **unnecessary_cast**: Unnecessary cast. Try removing the cast

## Rule breakdown (all 161 issues)

| Rule | Count |
|------|------:|
| `deprecated_member_use` | 78 |
| `curly_braces_in_flow_control_structures` | 57 |
| `use_build_context_synchronously` | 12 |
| `avoid_types_as_parameter_names` | 5 |
| `unnecessary_import` | 3 |
| `unused_import` | 2 |
| `prefer_interpolation_to_compose_strings` | 1 |
| `unnecessary_null_comparison` | 1 |
| `unnecessary_cast` | 1 |
| `unused_element` | 1 |

## Classification policy

- **CRITICAL**: Unguarded `use_build_context_synchronously` (widget disposed → runtime failure).
- **IMPORTANT**: Wrong `mounted` guard; `unnecessary_null_comparison` / `unnecessary_cast`; deprecated `PlatformFile.bytes` (OOM on large files).
- **COSMETIC**: `deprecated_member_use` (incl. `withOpacity`, configured as `warning` not error), braces/style lints, unused imports, tool `unused_element`.

## Release freeze action

- **Code changes this audit:** none (no 1-line safe CRITICAL fix applied).
- **Recommended post-freeze:** address CRITICAL async-context sites; batch `withValues` / deprecation migrations separately.

