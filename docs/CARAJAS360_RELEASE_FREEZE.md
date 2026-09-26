# CARAJAS 360 — Release Freeze (F7)

**Status:** ACTIVE  
**Base:** commit `1c47a74` + app version **1.0.0+402**  
**Effective from:** Fase 7 (F7) RC build path

## Policy

Release freeze is active from F7. Only the following change classes are allowed:

- Critical bug fixes
- Security fixes
- Finance / payments safety (guards, kill switch, ledger integrity) — **without enabling payments**
- LGPD / privacy compliance fixes
- Store listing / compliance fixes
- Build / release engineering fixes (signing, versionCode, CI, store packages)

**Not allowed:** new features, UX expansions, monetization experiments, or any change that turns on real payments.

## Payments

**Payments remain OFF.**

- Flutter: `productionPaymentsEnabled` default `false` (`MonetizationConfig`)
- Functions env: `PAYMENTS_ENABLED` must stay unset/`false` unless explicitly authorized later
- Functions env: `PRODUCTION_PAYMENTS_ENABLED` must stay unset/`false`
- Platform config: `financialKillSwitch` available for incident response

Do **not** set `PAYMENTS_ENABLED=true` or `PRODUCTION_PAYMENTS_ENABLED=true` as part of F7 work.

## Version

- Target RC build number: **1.0.0+402**
- Note: F7 RC never successfully distributed **401**; bump to **402** is the only version change allowed under this freeze for this build path.

## Scope reminder

Do not add features. Prefer minimal diffs. Prefer evidence under `docs/evidence/` for pre-build verification artifacts.
