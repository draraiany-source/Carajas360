# Fase 7 — Hosting Privacy/Terms 404 Fix

## Root cause
`firebase.json` had `hosting.public` set to `build/web`. Legal pages live in `web/privacy.html` and `web/terms.html`. A typical Flutter web build output in `build/web` does not include those static legal files, so deployed `/privacy` and `/terms` rewrites pointed at missing files → **404**.

## Fix (code/config only — no deploy in this session)
1. Created `hosting/` with `privacy.html` and `terms.html` (content from `web/`, LGPD retained).
2. Contact emails aligned with AppInfo:
   - `suporte@carajas360.com.br`
   - `privacidade@carajas360.com.br`
3. Added minimal `hosting/index.html` (Carajas 360 + links to /privacy and /terms).
4. Changed `firebase.json` `hosting.public` from `build/web` to `hosting` (rewrites for /privacy and /terms unchanged).
5. Synced `web/privacy.html` and `web/terms.html` emails to `carajas360.com.br` for consistency.

## EXTERNAL ACTION REQUIRED
Owner must run (requires Firebase owner auth):

```bash
firebase deploy --only hosting
```

**Do not** enable payments, publish the app, or start Phase 8 as part of this fix.
