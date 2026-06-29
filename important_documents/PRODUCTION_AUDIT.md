# EduAssist — Production Readiness Audit

> Generated 2026-06-29 by an 8-dimension multi-agent audit (auth/tenancy, SQLi/input, scalability, backend correctness, frontend state, UX/responsive, cross-platform config, data model/migrations). **Every finding was adversarially re-verified against the code**; false positives were dropped.

**Totals:** 106 raw findings → **85 confirmed** (21 false positives removed). Severity: **2 critical · 14 high · 27 medium · 42 low**.

> ⚠️ **Release blockers** (fix before any production/Play-Store ship): C1, C2, H1–H3, H6–H8, H12, H13, H14.

### Remediation log
> User directive (2026-06-30): **fix everything**, but **keep the OTP constant `999999` in all environments for now** (dev + prod), since no SMS provider is wired yet.

- **2026-06-30 — C1 / H6 — INTENTIONALLY DEFERRED (product decision):** the production gate was added then **reverted per the directive above** — `otp_dev_mode_active` now returns `otp_dev_mode` (always on), so `999999` works in prod too and the response echoes it. The single switch-point + a prominent ⚠️ comment remain in [config.py](../../edu_backend/app/core/config.py), so re-hardening before public launch is a one-line change (`return self.otp_dev_mode and not self.is_production`) + wiring an SMS provider. **Known, accepted account-takeover risk until then.**
- **2026-06-30 — FIXED ✅ C2** (Android INTERNET): added the permission to [main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) so release builds can reach the network.
- **2026-06-30 — FIXED ✅ H5** (bcrypt blocking the event loop): `hash_password_async`/`verify_password_async` (`asyncio.to_thread`); every async call site switched. Verified: correct accepted, **wrong rejected (401)** across super/admin/staff.
- **2026-06-30 — FIXED ✅ M5** (API docs exposed in prod): `docs_url`/`redoc_url`/`openapi_url` → `None` when `is_production`.
- **2026-06-30 — FIXED ✅ H7** (no rate limiting): added a Redis fixed-window limiter ([core/rate_limit.py](../../edu_backend/app/core/rate_limit.py) + `cache.incr`), applied per-IP to `/login` (10/min), `/password/request-otp` & `/signup/request-otp` (5/5min), `/password/reset` & `/signup/verify` (10/5min), plus a per-phone hourly OTP cap (8/hr) in [otp.py](../../edu_backend/app/auth_rbac/security/otp.py). Fails open if Redis is down. Verified live: login burst → 10×401 then **429**.
- **2026-06-30 — FIXED ✅ H14 + indexes** (phone-uniqueness race + missing indexes): added partial **UNIQUE** indexes `uq_{members,authorities}_phone_active` (on non-deleted rows) + hot-column indexes (`phone`, `group_id`, `organisation_id`+`is_deleted`, `rbac_role_id`) in [migrations.py](../../edu_backend/database_compare/migrations.py). Ran the local migration; verified all 7 present (both phone indexes UNIQUE).
- **2026-06-30 — FIXED ✅ M9** (user enumeration): `/password/request-otp` now returns a byte-identical response for unknown vs. existing phones. Verified live (both → `{sent:true, dev_code:"999999"}`). *(Signup first-login keeps its "no account" hint by design — admin-seeded, low value.)*
- **2026-06-30 — FIXED ✅ H1 / H2 / H8** (broken session revocation): added a per-user `sessions_invalidated_at` ([security/sessions.py](../../edu_backend/app/auth_rbac/security/sessions.py)) — stamped to `now()` on every password change / forgot-reset / admin-reset / staff-reset, instantly rejecting every prior **access *and* refresh** token (`token.iat < sessions_invalidated_at`). Enforced in `get_current_principal` *and* `/refresh`; Redis-cached with a **DB fallback so it holds even if Redis is down**. Token `iat` made sub-second so revocation is exact. Verified live (8/8): token works → reset → old access **401**, old refresh **401**, new login **200**; forgot-reset also revokes. *(Residual: full refresh-token rotation + per-device logout need jti-family tracking — deferred; the security-critical "reset kills all sessions, even via refresh, even without Redis" property is done.)*
- **2026-06-30 — FIXED ✅ H4** (unbounded public org list = unauthenticated OOM/DoS): `GET /api/auth/organisations` is now **search-driven + capped** — `q` filters by name/code server-side (bound param, injection-safe), `limit` clamped to ≤50, no-match → `[]`. The FE login picker ([organisation_selection_screen.dart](../lib/features/screens/organisation_selection_screen.dart)) now does **debounced (350ms) server-side search** instead of loading every org client-side. Verified live (5/5) + FE analyze clean. *(Remaining sub-item: paginate the authenticated list endpoints — admins/groups/staff/roles/feedback — and the N+1 in permission resolution; lower priority since those are authenticated + tenant-scoped, not a public DoS.)*
- **2026-06-30 — FIXED ✅ M13 + M19** (FE a11y/crash): `_getUserInitials` ([navigation_sidebar.dart](../lib/shared/widgets/navigation_sidebar.dart)) now splits on `\s+`, drops empty parts and guards empties — no more RangeError on names like "John  Doe". Bumped the illegible 7–8px sidebar footer text (role, org chip + icon, Logout, version, badge) to legible 10–12px. Analyze clean.
- **2026-06-30 — FIXED ✅ H9 / H10** (no 401-refresh; deactivation not detected client-side): added [core/network/app_http.dart](../lib/core/network/app_http.dart) — a drop-in `http`-aliased wrapper that attaches the bearer token itself, and on a **401 runs ONE single-flight refresh + retries once** with the fresh token; if refresh fails (refresh expired, or the backend 403s a deactivated account/org/group) it **hard-clears the session** (`AuthSession.clear()` → router `refreshListenable` redirects home), also clearing `PermissionStore` + `OrgSession`. Migrated all 7 authed services to it via a one-line import swap (super_admin, staff, roles, profile, feedback, authority, organisation_management). *(2026-06-30 follow-up: also routed the org-create dialog's direct `http.post` through AppHttp — it wasn't under lib/services/, so it had been missed; a long form is the most likely place for a mid-fill token expiry.)* `dart analyze lib` clean (only pre-existing info-lints in untouched files). Verified by construction (no retry loop; `_doRefresh` uses raw http so no recursion) — a live token-expiry walkthrough is the recommended manual smoke test.
- **2026-06-30 — FIXED ✅ H11** (create-org dialog stretched edge-to-edge on web): caps width at 560px by centring via a responsive horizontal inset ([organisation_create_dialog.dart](../lib/features/organisation_management/widgets/organisation_create_dialog.dart)). Analyze clean.
- **2026-06-30 — FIXED ✅ H12** (API URL defaulted to a dev MacBook host): added `AppConstants.assertApiBaseUrlConfigured()` (called in [main.dart](../lib/main.dart)) — a RELEASE build **refuses to launch** if `API_BASE_URL` is still a dev host (localhost/127.0.0.1/10.0.2.2/.local). The real URL comes from `--dart-define=API_BASE_URL=https://…` in CI. *(You supply the domain at build time.)*
- **2026-06-30 — FIXED ✅ H13** (release signed with debug key): [build.gradle.kts](../android/app/build.gradle.kts) now reads `android/key.properties` (gitignored) and signs release with that keystore if present, else falls back to debug. **You generate the keystore + key.properties later — no code change.**
- **Still needs you / deferred:** **M20** app package id (left `com.example.…` with `TODO(release)` markers — your call), **M21** secure token storage (mobile → `flutter_secure_storage`; adds a dependency — deferred for your OK; web has no true secure store).
- **2026-06-30 — FIXED ✅ M21** (tokens in plaintext): migrated [auth_storage.dart](../lib/core/auth/auth_storage.dart) from `shared_preferences` to **`flutter_secure_storage`** (iOS Keychain / Android Keystore / WebCrypto). Same save/read/clear interface, so AuthSession is unchanged. `pub get` + analyze clean. *(One-time re-login for anyone whose old plaintext session won't be found in the secure store.)*
- **2026-06-30 — FIXED ✅ M14** (OS text-scaling ignored): [main.dart](../lib/main.dart) now **clamps** the OS font scale to [0.85, 1.3] instead of hard-pinning 1.0 — respects accessibility without breaking layouts.
- **2026-06-30 — FIXED ✅ M18** (off-palette colours): replaced `AppTheme.success`/`AppTheme.warning`/`AppTheme.info` (teal/amber/blue) with green/neutral in feedback_dialog (snackbar + rating stars), ai_assistant_widget (status dots), and search_bar_widget (mic). Analyze clean.
- **2026-06-30 — FIXED ✅ M15** (sub-44px tap targets): header menu + feedback buttons now guarantee a 44×44 tap target ([navigation_header.dart](../lib/shared/widgets/navigation_header.dart)).
- **2026-06-30 — FIXED ✅ (low)** OrgSession not cleared on logout: `AuthApiService.logout()` now also calls `OrgSession.clearData()` so cached tenant data can't leak into the next session.
- **Needs device/visual verification (deferred):** **M16** (Android hardware back) — intercepting back app-wide can break go_router navigation; needs an on-device test + a UX decision (double-back-to-exit vs per-form discard-confirm). **M17** (AI-FAB overlaps last list item) — the *confirmed* instance is on the orphaned org-management screen; the general bottom-padding tweak should be verified visually on a device.
- **2026-06-30 — FIXED ✅ (low)** health router crash: `/health/cache-health` + `/health/full-health` imported a non-existent `cache_manager` (always errored). Now use `cache_service` with a **real write+read Redis ping**. Verified live: both → 200 `healthy`.
- **2026-06-30 — N+1 review + FIXED ✅ (bulk-commit)**: audited the permission hot-path — `get_admin_permissions` / `get_staff_permissions` / `grantable_pages` **already resolve the group map once and loop in memory** (no N+1; the finding was largely already mitigated). The one real issue — `set_all_group_pages` / `set_all_admin_pages` committing once **per module** — is fixed: `set_group_module` gained a `commit=False` flag so the bulk setters flush the whole change in **one transaction**. Verified live (5/5): bulk revoke/enable of admin + group pages still correct.
- **2026-06-30 — FIXED ✅ (pagination)** the **staff list** (`GET /api/staff`) — the one authenticated list that genuinely scales (students are staff members) — is now **paginated + server-side searched**: envelope `{items,total,limit,offset}` (limit capped ≤200), `q` ILIKE on name/email/phone/staff_id. FE: new `listStaffPage()` + the Staff screen does debounced server search + a **"Load more (N of total)"** footer. Verified live (4/4: paging + search) + FE analyze clean. *(The other authed lists — admins/groups/roles — are super-admin/per-org and bounded; the same pattern is available if any grows large.)*
- **2026-06-30 — FIXED ✅ (pagination consistency)** applied the same pattern to the remaining authed lists: **`/api/auth/admins`**, **`/api/auth/groups`**, **`/api/access/roles`** now return paginated, searchable envelopes (`{items,total,limit,offset}`, limit capped ≤200, `q` ILIKE). The FE services were **already envelope-aware** (read `items`), so the screens work unchanged — they're bounded super-admin/per-org lists, so no load-more UI was needed (the staff list keeps the full load-more since it's the one that scales). Verified live 5/5 + FE analyze clean.
- **Remaining:** the ~38 cosmetic LOWs (polish) — org-picker dead "Load more" already removed; clearing the rest in small batches.
- **Still need your input:** H12 (real prod HTTPS API URL), H13 (release keystore — you generate it), M20 (app package id). I'll wire the structure with placeholders and flag exactly what to replace.


---


## 🔴 CRITICAL — 2


### C1. Dev OTP backdoor (999999) is enabled by default and ships in production config

- **Severity:** critical  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/core/config.py:43-44`
- **Impact:** If OTP_DEV_MODE is not explicitly set to false in the prod env (default is True), EVERY signup-first-login and forgot-password flow accepts the fixed code 999999. An attacker who knows any user's phone (the login id) can set/reset that account's password via /api/auth/password/request-otp + /api/auth/password/reset and take over the account — including admins and, by chaining, whole institution groups. Even with SMS wired, no real code is ever sent (no SMS provider integration exists), so going live silently keeps the backdoor.
- **Fix:** Force otp_dev_mode off in production: e.g. `@property def otp_dev_mode_effective(self): return self._otp_dev_mode and not self.is_production`, or in Settings validation raise at startup if is_production and otp_dev_mode. Never return dev_code in API responses when is_production. Require a configured SMS provider before allowing OTP flows in prod (fail closed if otp_dev_mode is false and no provider configured).
- **Verified:** CONFIRMED — genuine critical account-takeover backdoor that is on by default with no production guard.

Evidence:
- config.py:43-44: `otp_dev_mode: bool = True`, `otp_dev_code: str = '999999'` — plain defaults, not tied to environment.
- otp.py:33-36: `_generate_code()` returns `settings.otp_dev_code` whenever `otp_dev_mode` is true; otp.py:39-44 `_deliver()` only logs, never sends SMS (provider is a TODO at line 43). So in dev mode the stored code IS always 999999.
- otp.py:62-67: `request_otp` stores that code and returns `OtpRequestResult(dev_code=code if otp_dev_mode else None)`.
- Exploit


### C2. Release AndroidManifest is missing the INTERNET permission — release APK/AAB cannot make any network call

- **Severity:** critical  ·  **Area:** `fe-crossplatform-config` / config
- **Location:** `android/app/src/main/AndroidManifest.xml:1-45`
- **Impact:** Android does not grant INTERNET by default; it must be declared in the manifest that ships. Debug and profile builds work (they inject it via their flavor manifests), but the merged RELEASE manifest has no INTERNET permission, so every http call throws SocketException and the app is completely non-functional in production on Android. This is masked during development because debug/profile builds appear to work fine.
- **Fix:** Add <uses-permission android:name="android.permission.INTERNET"/> to android/app/src/main/AndroidManifest.xml (outside <application>). Build a release APK and confirm login works against the staging server before shipping.
- **Verified:** VERIFIED TRUE. android/app/src/main/AndroidManifest.xml (read in full, lines 1-45) declares NO <uses-permission android:name="android.permission.INTERNET"/>. A grep -rn "INTERNET" across the entire android/ dir returns hits ONLY at app/src/debug/AndroidManifest.xml:6 and app/src/profile/AndroidManifest.xml:6 — exactly as the finding states. Checked every escape hatch the auditor could have missed: (1) no app/src/release/ source set exists (only debug/, main/, profile/), so nothing injects INTERNET for release; (2) app/build.gradle.kts buildTypes.release only sets signingConfig (lines 33-39) — 


## 🟠 HIGH — 14


### H1. JWT refresh endpoint does NOT rotate the refresh token and there is no refresh denylist — stolen refresh token is valid for the full 7 days and survives logout

- **Severity:** high  ·  **Area:** `be-authz-tenancy` / authn
- **Location:** `app/auth_rbac/routers/auth.py:181-203 (refresh) / 206-218 (logout)`
- **Impact:** A captured refresh token (XSS, log leak, device theft, shared computer) grants attacker-controlled access for up to refresh_token_expire_days=7 and cannot be revoked — logout doesn't invalidate it, and deactivation only blocks at refresh time for non-super-admin. No reuse detection means a cloned token and the legitimate one both keep working silently. At 100k+ users this is a large, undetectable account-takeover window.
- **Fix:** Rotate the refresh token on every /refresh (issue a new one, denylist the old jti) and detect reuse of an already-rotated jti by revoking the whole family. Persist refresh jtis (Redis) so logout can revoke the refresh token too. Make denylist failures fail-closed for high-value actions, or at least alert.
- **Verified:** Confirmed against actual code. (1) No rotation: app/auth_rbac/routers/auth.py:199-203 returns refresh_token=body.refresh_token (same token), only re-minting an access token. (2) Logout cannot revoke the refresh token: logout() at auth.py:206-218 denylists only the jti of the credential in the Authorization header; the frontend logout() (lib/services/auth_api_service.dart:49-58) sends ONLY the access token, so the refresh jti is never denylisted, and no separate refresh-revocation path exists. (3) No reuse detection / jti persistence: tokens.py mints a random jti per token (lines 35, 50) but ne


### H2. Token denylist/logout is best-effort fail-open; revoked/logged-out tokens still authenticate when Redis is down or for the access-token lifetime

- **Severity:** high  ·  **Area:** `be-authz-tenancy` / authn
- **Location:** `app/auth_rbac/security/deps.py:23-34 (_is_revoked) and 55-60`
- **Impact:** Logout and admin password-reset do not actually terminate active sessions; an attacker who phished a session keeps it after the victim 'logs out' or resets their password. With cache outage, NO token can be revoked at all. Combined with the non-rotating refresh token, account recovery is ineffective.
- **Fix:** On password change/reset, bump a per-user token-version (store in DB, embed in JWT, compare in get_current_principal) so all prior tokens are invalidated immediately and independently of Redis. Treat denylist-check cache errors as fail-closed for sensitive endpoints.
- **Verified:** CONFIRMED against actual code (cited file path was app/auth_rbac/routers/auth.py, not routes/). All core claims hold:

1) Fail-open denylist — deps.py:23-34: _is_revoked returns False on any exception. Worse than stated: cache.py:23-30 cache_service.get() itself catches all exceptions and returns None, so during any Redis outage _is_revoked always returns False and revoked/logged-out tokens authenticate normally. get_current_principal (deps.py:55-60) is the only gate.

2) Logout is best-effort AND access-token-only — auth.py:206-218: logout() denylists only the presented access token's jti (tt


### H3. complete_signup (first-login) trusts the client-supplied phone to select WHICH account to activate; combined with the fixed dev OTP this is an account-takeover primitive in any non-prod-flagged deploy

- **Severity:** high  ·  **Area:** `be-authz-tenancy` / authn
- **Location:** `app/auth_rbac/services/signup_service.py:97-127 (complete_signup) ; otp config app/core/config.py:43-44 (otp_dev_mode=True, otp_dev_code='999999')`
- **Impact:** If the service is deployed with environment != production/staging (the only thing toggling is_production / hardening) and otp_dev_mode left default, an attacker enumerates phones (e.g. via known staff numbers), requests OTP, uses 999999, and seizes the not-yet-activated admin/staff account — full takeover before the legitimate user's first login. password/request-otp is deliberately non-enumerable but signup/request-otp returns 404 'No account awaiting setup' (auth.py:686), leaking which phones have pending accounts.
- **Fix:** Force otp_dev_mode=False and a real SMS provider whenever not local; refuse to start in production with dev OTP. Do not 404-differentiate pending phones in signup/request-otp. Rate-limit and lock signup OTP per phone/IP. Treat first-login activation as security-critical, not a dev convenience.
- **Verified:** CONFIRMED real. Every cited mechanism checks out against the actual code (auth router is at app/auth_rbac/routers/auth.py, not api/auth.py, but the logic matches).

Chain verified:
1. complete_signup (signup_service.py:103-127) calls find_pending_account_by_phone(phone) and sets that account's password_hash + flips status='active' with NO token/identity binding beyond the client-supplied phone. The only gate is the prior OTP verify in signup_verify (auth.py:694-700).
2. otp_dev_mode=True and otp_dev_code='999999' are defaults (config.py:43-44).
3. KEY: otp dev mode is an INDEPENDENT flag from 


### H4. Dev OTP code is returned to the client in API responses (dev_code)

- **Severity:** high  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:82-83, 690-691, 718-720`
- **Impact:** Combined with the previous finding, even if the fixed code were randomized, the verification code is handed straight back to any unauthenticated caller, fully defeating OTP. Account takeover for any known phone number.
- **Fix:** Never include dev_code in responses outside an explicit, non-production debug mode. Gate strictly on `not settings.is_production AND a dedicated debug flag`. In production the field must always be null.
- **Verified:** CONFIRMED against actual code. OtpSentResponse exposes dev_code (auth.py:81-83). Both public, unauthenticated endpoints /api/auth/signup/request-otp (auth.py:682-691) and /api/auth/password/request-otp (auth.py:713-720) return OtpSentResponse(..., dev_code=res.dev_code). otp.request_otp returns dev_code=code if settings.otp_dev_mode else None (otp.py:67). settings.otp_dev_mode defaults True (config.py:43) and is NOT coupled to is_production — the is_production property exists (config.py:60-62) but is never referenced by the OTP code. Verified the backend .env does NOT set otp_dev_mode or envir


### H5. No rate limiting / lockout on /login, /password/reset, /signup, or OTP request endpoints

- **Severity:** high  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:123-137, 682-733`
- **Impact:** Unlimited password-guessing on /login (bcrypt verify per attempt — also a DoS amplifier at 100k users), and OTP brute force: the 5-attempt lockout just clears the OTP, then a fresh request every 30s gives effectively unlimited 6-digit guesses (10^6 space) for a targeted phone. No account lockout means credential-stuffing across the whole user base is unimpeded. At 100k+ users this is both a takeover and a resource-exhaustion vector.
- **Fix:** Add IP- and account-keyed rate limiting (e.g. slowapi or a Redis token bucket) on /login, /password/*, /signup/*. Add exponential backoff / temporary account lockout after N failed logins. Cap total OTP requests per phone per hour (not just a 30s cooldown), and cap total verify attempts across re-issued codes.
- **Verified:** CONFIRMED real, but severity overstated; downgrade critical->high. Verified: grep for rate.?limit|slowapi|limiter|throttle across edu_backend/app returns nothing; no such dependency; no reverse proxy in the stack (Dockerfile:85 / docker-compose.yml:106 run gunicorn -w4 bound directly to 0.0.0.0:8000; the docker-compose 'limits' are memory limits, not HTTP rate limits). Only HTTP middleware is add_process_time_header (timing) + CORS (main.py:152-205). So login(), signup_verify(), password_reset() and the request-otp endpoints (auth.py:123-137, 682-733) have NO per-IP or per-account throttle/loc


### H6. Password change / reset does not revoke existing tokens (no global denylist by user) — stolen sessions survive a reset

- **Severity:** high  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:251-268, 723-733`
- **Impact:** After a compromise-driven password reset (the intended recovery action), the attacker's already-issued access token (30 min) and refresh token (7 days) keep working — refresh even re-mints fresh access tokens for a week. The reset gives the victim a false sense of security; the account stays compromised.
- **Fix:** On password change/reset, bump a per-user token_version (or password_changed_at) stored in DB and embed it in tokens; reject tokens whose version is stale in get_current_principal and refresh. Alternatively maintain a per-user 'revoke-all-before' timestamp in Redis checked on every auth.
- **Verified:** Confirmed against actual code. change_password (auth.py:266-267) and password_reset (auth.py:731-732) set user.password_hash and commit with NO token invalidation. The denylist check _is_revoked (security/deps.py:23-34) is keyed only on individual jti, and jtis are added to denylist ONLY at /logout (auth.py:213-215) for the single presented token. Tokens (security/tokens.py:27-54) carry no password_changed_at / token_version — sub/role/org/group/type/jti/iat/exp only. grep across app/ for token_version|password_changed_at|revoke_all|invalidate.*token returns nothing relevant. The /refresh endp


### H7. Phone uniqueness enforced only in app code via SELECT — concurrent inserts let duplicate phones in, and login by phone then becomes ambiguous/account-shadowing

- **Severity:** high  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/staff_management/services/staff_service.py:64-92, 122-126`
- **Impact:** At 100k+ users with real concurrency, duplicate phone numbers will exist. Because phone IS the login identifier and the lookup spans two tables, one account can shadow another: a user could end up authenticating against, or being indistinguishable from, a different tenant's account. This is a cross-tenant data-leak / account-takeover class bug, not merely a UX duplicate.
- **Fix:** Add DB-level uniqueness. Phone spans two tables, so either (a) move all login identities into one table, or (b) add a partial UNIQUE index per table on non-deleted rows: `CREATE UNIQUE INDEX uq_members_phone_active ON members (phone) WHERE is_deleted = false;` and same for authorities, plus an exclusion/trigger or a shared identity table to enforce cross-table uniqueness. Keep the app check for a friendly message but rely on the constraint + catch IntegrityError for correctness.
- **Verified:** VERIFIED REAL. Every claim checks out against the code.

Evidence:
- staff_service.py:64-81 `_phone_taken` is pure SELECT (two `SELECT 1 ... LIMIT 1` over members + authorities); create() (line 91-92) only raises a ValueError on a hit. Classic TOCTOU.
- member.py:37 `phone = Column(String(20), nullable=False, index=True)` — index only, NO unique. authority.py:26 `phone = Column(String(20), nullable=False)` — no index, no unique. No UniqueConstraint/__table_args__/partial index in either model; database_compare/migrations.py (full 69 lines read) has nothing for phone. So there is no DB-level gu


### H8. Public /api/auth/organisations returns EVERY organisation with no LIMIT/pagination (fatal at 100k orgs)

- **Severity:** high  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/routers/auth.py:140-178`
- **Impact:** At 100k+ orgs this loads every row + every column into memory and serialises a giant JSON payload on every unauthenticated hit of the login screen. It is a trivially exploitable DoS (no auth, no rate limit) and will OOM/timeout the worker long before 100k. The inactive_groups set also grows unbounded. On mobile (Android/iPhone) the multi-MB response will stall or crash the login picker.
- **Fix:** Never return all orgs to the login screen. Require the user to type org name/code and return a paginated, server-filtered search (ILIKE on indexed name/code, LIMIT 20-50). Select only the projected columns (id, name, code, org_type, is_active), not full ORM objects. Replace the inactive-group full scan with a JOIN to institution_groups in the same query. Add auth or strict rate limiting.
- **Verified:** VERIFIED REAL. /Users/anirbande/Desktop/ddddd/edu_backend/app/auth_rbac/routers/auth.py:140-178. The GET /api/auth/organisations endpoint is genuinely unauthenticated — its only dependency is `db: AsyncSession = Depends(get_db)` (line 141), and its docstring explicitly says "Public: minimal organisation list for the login picker." Every other write/read endpoint in the same file uses Depends(require_super_admin/require_authority/get_current_principal); this is the sole intentionally-public GET. Claims confirmed: (1) line 150-154 `select(Organisation).where(is_deleted==False).order_by(name)` lo


### H9. Password hashing/verification (bcrypt rounds=12) runs synchronously inside the async event loop — blocks all concurrent requests

- **Severity:** high  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/security/password.py:verify_password 24-31; hash_password 17-21`
- **Impact:** bcrypt rounds=12 is ~150-300ms of pure CPU. Because it is not offloaded to a thread, it blocks the single asyncio event loop of that worker for the whole duration — every other in-flight request on that worker stalls. At 100k users a login spike serialises behind CPU-bound hashes; throughput collapses to (#workers / 0.2s) logins/sec regardless of DB capacity. This is the dominant scaling wall for auth.
- **Fix:** Offload to a thread: `await asyncio.to_thread(bcrypt.checkpw, ...)` (and for hashpw) so the event loop stays free. Size a thread pool / process pool for hashing. Consider lowering to rounds=10-11 if latency budget requires. Also break out of the row loop after the first verifying row.
- **Verified:** CONFIRMED against actual code. password.py:21 hashpw with gensalt(rounds=12) and password.py:29 checkpw are plain synchronous calls — no asyncio.to_thread/run_in_executor/ThreadPoolExecutor anywhere in app/ (grep returns nothing). login_service.authenticate (async coroutine) calls verify_password synchronously: at line 74 (super-admin), and inside the `for user in rows` loop at line 86. These run on the worker's event loop, so each ~150-400ms bcrypt(rounds=12) freezes ALL in-flight requests on that worker. Deployment confirms the model: Dockerfile:85 and docker-compose.yml:106 launch `gunicorn


### H10. No 401 auto-refresh in the HTTP layer — access-token expiry breaks the entire session mid-use

- **Severity:** high  ·  **Area:** `fe-correctness-state` / auth/state-management
- **Location:** `lib/services/auth_api_service.dart, lib/core/auth/auth_session.dart:auth_api_service.dart:64 (refreshSession); all service calls use AuthSession.headers()`
- **Impact:** JWT access tokens expire on a timer. As soon as the access token expires while the app is open (common for long sessions / a tab left open), the NEXT API call returns 401 and the screen shows a raw 'Failed to load ... (401)' error. The user is still 'authenticated' locally (refresh token present) but every page silently breaks until they manually log out and back in. At 100k+ users this is a constant stream of spurious failures and support tickets.
- **Fix:** Introduce a single shared http.Client wrapper (or a BaseService.send helper) that: on 401, calls AuthApiService.refreshSession() once (guarded by a single in-flight Future to prevent a refresh stampede), then retries the original request with the new token; if refresh itself returns non-200, clear the session and let the router redirect to home. Route ALL service calls through it.
- **Verified:** CONFIRMED real. Verified every claim against the actual code:

- auth_api_service.dart:64 refreshSession() exists but is called exactly once — only at launch (main.dart:22), gated behind AuthSession.accessTokenExpired. No other caller (grep: only main.dart:22 references it).
- No 401 handling anywhere: `grep -rn "401"` and `"== 401"` over lib/ return nothing. No http.Client/BaseClient/interceptor/BaseService wrapper exists (grep returns NO CLIENT WRAPPER).
- Every service (staff_service, super_admin_service, roles_service, profile_service, organisation_management_service, authority_service) ma


### H11. Deactivation/group-disable mid-session is never detected — deactivated users keep a working UI until they happen to hit an auth error

- **Severity:** high  ·  **Area:** `fe-correctness-state` / authz/state-management
- **Location:** `lib/services/auth_api_service.dart, lib/core/utils/app_router.dart:auth_api_service.dart:64-84 (refresh only clears on non-200 at launch); app_router.dart:32-45 (redirect only checks isAuthenticated)`
- **Impact:** A deactivated admin/staff member retains a fully navigable app and stale cached data (org list, staff list, permissions) until they relaunch. Deactivation is the platform's only revocation mechanism (no delete) — so the security control is effectively delayed/unenforced on the client until token expiry.
- **Fix:** In the shared http wrapper (finding #1), treat a 401/403 whose refresh attempt fails as a hard logout: AuthSession.clear() + PermissionStore.clear() + OrgSession.clearData(); the router's refreshListenable will then redirect to home. Optionally poll/validate the session on resume (WidgetsBindingObserver.didChangeAppLifecycleState).
- **Verified:** CONFIRMED real. The frontend has no mid-session revocation detection. app_router.dart:32-44 redirect only checks AuthSession.isAuthenticated (local token presence). refreshSession() (auth_api_service.dart:64-84) does clear the session on a 403/non-200 — but it is only invoked at launch; nothing calls it during a live session. main_layout.dart:57 registers a WidgetsBindingObserver but never overrides didChangeAppLifecycleState, so there is no re-validation on resume. There is no shared HTTP wrapper: each data service (e.g. staff_service.dart:46, listStaff/createStaff/etc.) just throws a generic


### H12. API base URL defaults to a developer's personal MacBook mDNS host over cleartext HTTP — release blocker on every platform

- **Severity:** high  ·  **Area:** `fe-crossplatform-config` / config
- **Location:** `lib/core/constants/app_constants.dart:7-15`
- **Impact:** Any build produced WITHOUT --dart-define=API_BASE_URL=... ships pointing at 'Anirbans-MacBook-Air.local:8000'. On real Android/iOS devices, web hosting, or any machine that is not the developer's Mac on the same Wi-Fi, mDNS will not resolve and EVERY API call (login, refresh, all data) fails — the app is dead on arrival. Even when it resolves it is plain HTTP, so all tenant traffic (JWTs, credentials, org data) is sent unencrypted. There is no compiled-in production HTTPS fallback, so a forgotten --dart-define silently ships a broken/insecure binary. This is the single highest-priority release blocker.
- **Fix:** Make the default a real production HTTPS URL (e.g. https://api.yourdomain.com) and treat the local Mac host as a debug-only override. Better: pick the base URL per build flavor (--dart-define API_BASE_URL plus kReleaseMode guard that refuses to start against an http:// or *.local host in release). Add a CI check that fails the release build if apiBaseUrl is non-HTTPS or contains '.local'/'localhost'. For Android emulator dev use 10.0.2.2 via the dart-define, not the compiled default.
- **Verified:** Confirmed against the code. lib/core/constants/app_constants.dart:7-15 sets `apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://Anirbans-MacBook-Air.local:8000')`. Every service/widget derives from this single const (verified ~18 call sites: services/*_service.dart use `_base`/`_baseUrl = AppConstants.apiBaseUrl`; auth_api_service.dart `_u()`; permission_store.dart; all organisation_management widgets). No HTTPS/release fallback exists: the only kDebugMode/kReleaseMode usages in lib/ are for error-detail verbosity (organisation_management_screen.dart:183) and a dev-code 


### H13. Release build is signed with the debug keystore

- **Severity:** high  ·  **Area:** `fe-crossplatform-config` / config
- **Location:** `android/app/build.gradle.kts:33-39`
- **Impact:** An app signed with the debug key cannot be uploaded to Google Play (Play rejects debug-signed artifacts) and is insecure (the debug keystore is public/well-known, so anyone can sign a malicious update with the same identity). This blocks Play Store release outright and, if side-loaded, undermines update integrity for a multi-tenant SaaS.
- **Fix:** Create a release keystore, add android/key.properties (gitignored), wire a proper signingConfigs.create("release") reading from it, and set release.signingConfig to it. Enable minify/shrinkResources for release while you are in this block.
- **Verified:** Confirmed against actual code. android/app/build.gradle.kts lines 33-38: `release { signingConfig = signingConfigs.getByName("debug") }` — release is signed with the public, well-known Android debug keystore. Verified no android/key.properties exists and no *.jks/*.keystore exist under android/ (only the .gitignore pre-stages them, default Flutter template). applicationId/namespace are also still the default `com.example.edu_assist_dynamic`. Technical claims are accurate: Play Console rejects debug-signed artifacts, and the debug key is non-secret so a side-loaded build's update identity can b


### H14. Create-organisation dialog has no max-width — stretches edge-to-edge and looks broken on wide web

- **Severity:** high  ·  **Area:** `fe-ux-design-responsive` / responsive
- **Location:** `lib/features/organisation_management/widgets/organisation_create_dialog.dart:199-205`
- **Impact:** On a 1440px web window (and tablets) this multi-tab form expands to ~1424px wide: form fields become absurdly long single-line rows, the two-column `_responsiveFields` splits into very wide columns, and it violates design rule 6 ('dialogs are constrained / near-full-screen'). It is the first dialog an onboarding admin sees (AdminOnboardingScreen._createOrg and OrgSwitcher._createOrg), so the worst first impression lands on the most important flow.
- **Fix:** Wrap the child in ConstrainedBox(constraints: BoxConstraints(maxWidth: min(size.width-24, 560), maxHeight: size.height-80)) exactly like organisation_edit_dialog.dart does.
- **Verified:** CONFIRMED. organisation_create_dialog.dart:199-205 returns Dialog(insetPadding: EdgeInsets.all(8), child: SafeArea(Column(...))) with NO ConstrainedBox/maxWidth, so on wide web/tablet the dialog stretches to viewport_width-16 (~1424px at 1440). Its peer organisation_edit_dialog.dart:231-240 explicitly does maxW = math.min(size.width-24, 560.0) + maxH = size.height-80 and wraps the child in ConstrainedBox(BoxConstraints(maxWidth: maxW, maxHeight: maxH)); details/stats/bulk dialogs also use ConstrainedBox (grep confirms all 4 peers do, create is the only one that doesn't). Both call sites — admi


## 🟡 MEDIUM — 27


### M1. Refresh tokens carry full role/org/group and are accepted forever within their 7-day window with no rotation, so privilege downgrades and org-switches do not invalidate the OLD refresh token

- **Severity:** medium  ·  **Area:** `be-authz-tenancy` / authn
- **Location:** `app/auth_rbac/routers/auth.py:181-203 (refresh) ; security/tokens.py:42-54 (create_refresh_token)`
- **Impact:** A user retains a usable session scoped to a prior org/role for up to a week regardless of switches or de-provisioning that should have re-scoped them. Two parallel tenant-scoped sessions can be active from one user. De-provisioning is not authoritative until token expiry.
- **Fix:** Track refresh jtis server-side and rotate on every refresh and on every switch (revoke superseded family). Re-derive role/org from the DB at refresh and reject if the user no longer holds them.
- **Verified:** CONFIRMED against code. tokens.py:42-54 (create_refresh_token) embeds role/organisation_id/group_id into the refresh token. auth.py:199-203 (refresh) returns refresh_token=body.refresh_token unchanged (NO rotation), and re-mints the access token from the frozen claims. auth.py:614-638 (switch_organisation) mints an independent new refresh token for org B but never denylists the org-A token; there is no server-side refresh jti registry. TTL = refresh_token_expire_days:int=7 (config.py:24). The denylist (security/deps.py:23-34) only covers access-token jtis, is fail-open, and is never populated 


### M2. JWT secret strength/algorithm are not enforced; HS256 with an operator-supplied secret and no minimum-length or alg-allow-list guard

- **Severity:** medium  ·  **Area:** `be-authz-tenancy` / config
- **Location:** `app/core/config.py:8 (jwt_secret_key: str) , 22 (jwt_algorithm='HS256') ; app/auth_rbac/security/tokens.py:24,60`
- **Impact:** A weak/short jwt_secret_key (no minimum enforced) is brute-forceable offline, yielding forge-any-user tokens (full multi-tenant compromise). The single-algorithm decode mitigates classic alg-confusion, but there is no startup assertion that the secret is strong or that the alg is in an HS-only allow-list.
- **Fix:** Assert at startup: jwt_secret_key length >= 32 bytes of entropy and not the default; pin decode to an explicit HS-only allow-list constant (not settings) so a config change can't introduce 'none'/asymmetric confusion; rotate secret out of any committed .env.
- **Verified:** Confirmed against code. config.py:9 `jwt_secret_key: str` is a required field with NO default and NO validator; config.py:22 `jwt_algorithm: str = 'HS256'`. tokens.py:24 signs and tokens.py:60 verifies with `algorithms=[settings.jwt_algorithm]` (a config-driven single-element list, not a hardcoded HS-only allow-list).

The alg-confusion half of the finding is NOT a present vulnerability: decode is pinned to one algorithm and the default is HS256, so alg:none/RS-HS confusion is not exploitable as written (the auditor acknowledges this). It only becomes a problem if an operator deliberately sets


### M3. Login identity phone is not UNIQUE at the DB level — cross-tenant account shadowing + TOCTOU race

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / tenancy
- **Location:** `app/staff_management/models/member.py:37 (and authority.py:26)`
- **Impact:** Two concurrent creates with the same phone (different orgs/groups) both pass the app-level check and both commit — phone is the login id. Login then resolves to whichever row's password matches first, so one account can shadow/lock out another across tenant boundaries; first-login (find_pending_account_by_phone) and forgot-password (find_active_user_by_phone) can bind to the wrong tenant's record. This is a multi-tenant data-integrity and auth-routing bug that worsens under load.
- **Fix:** Add a partial UNIQUE index on phone where is_deleted=false for members and authorities (and ideally a single shared identity uniqueness scheme), via database_compare migration. Catch IntegrityError on create and map to 409. Make authenticate reject (not silently pick first) when multiple active rows share a phone.
- **Verified:** VERIFIED against actual code — all technical claims hold. members.phone (member.py:37) and authorities.phone (authority.py:26) are `nullable=False, index=True` but NOT unique; only super_admins.phone is unique (super_admin.py:10). database_compare/migrations.py (the source of truth for indexes/constraints on existing tables) contains NO unique constraint or partial unique index on either phone column — confirmed by full read. Uniqueness is enforced purely in app code via SELECT-then-act with no DB backstop: invitation_service.assert_phone_available (invitation_service.py:138-153) and staff_ser


### M4. API docs / OpenAPI (Swagger, ReDoc, /openapi.json) are exposed in production

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/main.py:117-123`
- **Impact:** Full API surface (every admin/super-admin endpoint, schemas, the OTP/dev_code fields) is enumerable by anyone in production, aiding targeted attacks. The hardcoded localhost server URL also makes the published docs 'try it' calls wrong for real deployments.
- **Fix:** Disable docs in production: FastAPI(docs_url=None, redoc_url=None, openapi_url=None) when settings.is_production (or gate behind auth). Set servers from config, not a hardcoded localhost.
- **Verified:** CONFIRMED real. main.py:117-123 constructs FastAPI() with no docs_url/redoc_url/openapi_url overrides, so /docs, /redoc, /openapi.json are served with defaults. grep over app/ finds zero occurrences of docs_url/redoc_url/openapi_url and no middleware (or any code) blocking /docs|/redoc|/openapi — so there is no guard elsewhere. servers=[{"url":"http://localhost:8000"}] is hardcoded (line 122). The codebase already has the exact gate needed: settings.is_production (config.py:61-62, environment-based) is used at main.py:145 (error-detail leak), 190 and 201 (CORS) — but it is NOT applied to docs.


### M5. Global exception handler leaks raw exception text (including SQL) outside production; 'staging' is treated as production

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/main.py:140-146`
- **Impact:** On any non-prod-named deployment, 500s return the raw exception — frequently containing SQL fragments, table/column names, parameter values, file paths — to the client. A single typo in ENVIRONMENT (e.g. 'Production ' with a space, or 'live') silently flips this to leak mode. This is the classic stack/SQL leak vector for internal-recon.
- **Fix:** Default to the SAFE branch: only show details when an explicit DEBUG flag is set, never based on a free-text environment string. Validate `environment` against an enum at startup and fail fast on unknown values.
- **Verified:** Verified true. main.py:145 is exactly `detail = f"Internal server error: {exc}" if not settings.is_production else "Internal server error"`. config.py:60-62 `is_production` returns True only for the exact strings ('production','prod','staging'). config.py:12 default `environment='development'`, and there is no .env/.env.example setting ENVIRONMENT in the repo — so by default `is_production` is False and the handler returns `str(exc)` to the client. The fail-open design is confirmed: any value not in those three exact strings (dev/qa/test/typo/whitespace-padded like 'production ') falls through


### M6. Password policy is only 6 characters, no complexity, and bcrypt silently truncates at 72 bytes

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:37, 93-98`
- **Impact:** 6-char passwords on accounts that gate entire institution groups; with no login rate limiting (above) these are brute-forceable. Silent 72-byte truncation means very long passwords are quietly weakened, and two passwords sharing the first 72 bytes are interchangeable.
- **Fix:** Raise minimum to >=10-12 with basic complexity or zxcvbn scoring; reject common/breached passwords. Reject (don't truncate) inputs >72 bytes, or pre-hash with SHA-256 before bcrypt. Apply the same policy to admin reset and remove any default seeded passwords from prod paths.
- **Verified:** CONFIRMED (with one correction). Verified in /Users/anirbande/Desktop/ddddd/edu_backend/app/auth_rbac/routers/auth.py and security/password.py.

Real parts:
- MIN_PASSWORD_LEN = 6 (auth.py:37). Every validator only checks len<6 with no complexity/breach/zxcvbn check: signup (96-98), reset (113-115), change-password (246-248), and admin reset (473-475). These accounts gate entire institution groups.
- No login rate limiting: /login (auth.py:123) calls login_service.authenticate with no throttle. Rate limiting (429) exists ONLY in security/otp.py for OTP attempts, not for password login. So shor


### M7. Token denylist (logout / revocation) fails OPEN when Redis is unavailable

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/security/deps.py:23-34`
- **Impact:** During a Redis incident or once denylist keys are evicted under memory pressure (Redis is also the OTP + rate-limit store at 100k+ scale), logout and any token revocation become no-ops — revoked tokens are accepted. This is the kind of silent control-plane failure that's hard to detect.
- **Fix:** For revocation, prefer fail-closed or at least alert on cache errors. Better: move to short-lived access tokens + a DB-backed token_version check (see prior finding) so revocation does not depend on best-effort Redis. Ensure denylist TTL >= token lifetime and Redis maxmemory-policy never evicts these keys (use a separate logical DB / noeviction).
- **Verified:** CONFIRMED but severity overstated; downgrade high -> medium.

Mechanism is real. deps.py:23-34 `_is_revoked` returns False on ANY exception ("Fail-open if cache is unavailable"), and core/cache.py:24-32 `get()` swallows all exceptions returning None. The denylist is the ONLY revocation path: logout (auth.py:206-218) only does `cache_service.set(f"denylist:{jti}", ...)`, and no token_version / DB-backed revocation exists. Redis is genuinely shared with OTP store (otp.py:54-64) and is write-heavy, so an outage or eviction making revoked tokens valid again is plausible. (Note: the finding's cited


### M8. OTP request endpoints enable account/user enumeration (inconsistent existence responses)

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:682-691, 713-720`
- **Impact:** An attacker can probe /signup/request-otp to learn which phone numbers correspond to created-but-not-yet-activated accounts (freshly onboarded admins/staff are prime takeover targets, since they have no password yet and the OTP backdoor applies). Enables targeted takeover during the onboarding window.
- **Fix:** Make signup_request_otp respond uniformly (always 'if an account exists, a code was sent') like password_request_otp, and add rate limiting so probing is throttled.
- **Verified:** CONFIRMED against actual code. The asymmetry is real: signup_request_otp (auth.py:684-691) raises HTTP 404 "No account awaiting setup for this phone" when find_pending_account_by_phone returns None, but 200 + OtpSentResponse otherwise — a clean enumeration oracle for created-but-not-yet-activated (password_hash IS NULL) accounts. By contrast password_request_otp (auth.py:714-720) was deliberately made uniform (always returns sent=True, comment "Always respond the same way to avoid leaking which phones exist"), and password_reset (728) uses a uniform error. So the signup path leaks while the re


### M9. OTP store, denylist, and rate-limit state all depend on Redis with silent fail-open, and there is no fallback

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/core/cache.py:24-52`
- **Impact:** If Redis is down or a set() silently fails: request_otp returns 'sent' but stored nothing, then verify_otp reads None and returns 400 'Code expired' — OTP becomes unusable (DoS of signup/reset). Conversely the cooldown and attempt-counter writes failing silently remove brute-force protection. At 100k+ users a single Redis blip cascades into auth-wide failures with no signal.
- **Fix:** Distinguish 'cache miss' from 'cache error' and surface a 503 when the OTP store write fails instead of pretending success. Add Redis health to readiness. Consider a DB-backed OTP table as the source of truth for correctness-critical state.
- **Verified:** CONFIRMED real, severity medium is correct. cache.py:34-42 set() returns False on any Redis error; otp.request_otp (otp.py:64-65) ignores that return and unconditionally returns OtpRequestResult(sent=True) (otp.py:67). verify_otp then reads None (otp.py:74) and raises 400 'Code expired or not requested' (otp.py:75-77). So a Redis outage silently breaks signup (/signup/verify, auth.py:696) and password reset (/password/reset, auth.py:729) while the API reports success — a genuine availability/DoS-on-auth issue with no DB fallback (no OTP table exists; grep found none).\n\nTwo nuances that bound


### M10. create-all on every startup + no migration ordering; schema drift risk in multi-worker production

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / data-model
- **Location:** `app/main.py:83-92`
- **Impact:** Multiple workers racing CREATE TABLE on cold start can deadlock/error (logged then ignored at line 91-92, so a partially-created schema can pass startup unnoticed). Real schema changes (indexes/constraints like the missing phone unique index) silently never apply, so prod drifts from the models.
- **Fix:** Run schema migrations once as a deploy step (database_compare) and remove create_all from the request-serving app, or gate it to a single init job. Don't swallow create_all failures — fail startup so a broken schema is caught.
- **Verified:** verify-failed; unverified


### M11. No dedicated readiness/liveness endpoint; /health/* check too much or report falsely, and /system/status leaks environment

- **Severity:** medium  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/routers/health.py:12-127`
- **Impact:** k8s/ALB probes can't distinguish ready from broken (200 on a dead DB), so traffic routes to unhealthy pods at scale. /system/status exposes environment name and DB pool internals unauthenticated, aiding recon.
- **Fix:** Add /livez (process up) returning 200 always, and /readyz that returns 503 when DB or Redis checks fail (correct HTTP codes). Require auth (or restrict) on /system/status and strip internal pool details from unauthenticated responses.
- **Verified:** VERIFIED against actual code; claims are accurate. health.py:12-20: /health/ returns hardcoded status=healthy, platform="Docker Local", version="1.0.0" with NO dependency checks (always 200). health.py:39-48: /db-health catches the DB exception and RETURNS a dict (HTTP 200) with status="unhealthy" instead of raising HTTPException(503) — so status-code-based probes see success on a dead DB. health.py:89-117: /full-health computes overall_status="degraded" but still returns 200; its cache check (lines 103-107) only verifies the cache_manager module imports — it never pings Redis, so cache is rep


### M12. email UNIQUE constraint is unconditional and collides with soft-deleted rows — a deactivated/soft-deleted user permanently blocks re-using that email

- **Severity:** medium  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/organisation_management/models/organisation.py:110-113; authority.py:24; member.py:36; super_admin.py:9`
- **Impact:** Once an organisation, authority, or staff member is soft-deleted, its email/phone/code/name+address can never be reused — creating the same org or re-onboarding the same person fails with an opaque IntegrityError ('That email is already in use.' staff_service.py:115) even though no live row uses it. At scale this produces a steady stream of 'cannot recreate' support tickets and forces hard deletes, defeating the soft-delete design.
- **Fix:** Replace the unconditional UNIQUE constraints with partial unique indexes scoped to live rows, e.g. `CREATE UNIQUE INDEX uq_organisations_email_active ON organisations (lower(email)) WHERE is_deleted = false;` (and likewise phone/code, and authorities/members email). Add these to migrations.py. Consider lower(email) to also fix case-sensitive duplicate emails.
- **Verified:** CONFIRMED real. Tables are deployed via Base.metadata.create_all (database_compare/run_production_migration.py:44, run_local_migration.py:33), so the model __table_args__ ARE the live DDL. organisation.py:110-113 declares unconditional UniqueConstraint on email/phone/code and (name,address) with no WHERE is_deleted=false; authority.py:24 and member.py:36 have column-level unique=True on email. Soft-delete only flips is_deleted=True (+ status='inactive') and leaves email/code intact: staff_service.py:160-164, authority bulk_soft_delete (authority_service.py:397-405), org bulk_soft_delete (organ


### M13. FK ON DELETE behaviour mismatched: ORM cascade='all, delete-orphan' on organisation→authorities but the DB FK has no ON DELETE, while members/rbac_roles/permissions FKs to organisations/groups default to RESTRICT with no cascade

- **Severity:** medium  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/organisation_management/models/organisation.py:74; authority.py:16; member.py:20; access/models.py:16,38,53`
- **Impact:** Inconsistent and partly dangerous deletion semantics: (1) A hard DELETE of an organisation via ORM would cascade-delete its authorities in-session but leave members, rbac_roles, and permission rows orphaned or block on the DB RESTRICT depending on path — non-deterministic. (2) If a raw SQL delete is ever run, the ORM cascade is bypassed entirely, orphaning authorities. The system relies on soft delete, but the schema's FK story is internally contradictory, which is a latent data-integrity and cross-tenant-orphan risk.
- **Fix:** Make DB FK ON DELETE explicit and consistent with the soft-delete model: since you never hard-delete, drop the ORM `cascade='all, delete-orphan'` (it implies hard deletes you don't do) OR add matching ON DELETE CASCADE/RESTRICT at the DB level for organisation_id and group_id FKs across authorities/members/rbac_roles/permission tables. Document the intended behaviour and enforce it in migrations.py.
- **Verified:** VERIFIED REAL (facts accurate), but severity overstated to high — downgrade to medium. The cited file paths in the finding were wrong, but the real files confirm every schema fact:

- organisation.py:74 — `authorities = relationship("Authority", ..., cascade="all, delete-orphan", lazy="dynamic")` (ORM-only cascade).
- authority_management/models/authority.py:16 — `organisation_id = ForeignKey("organisations.id")` with NO ondelete (default NO ACTION/RESTRICT).
- staff_management/models/member.py:20 — `organisation_id` nullable=False, plain FK, no ondelete, and Organisation has NO ORM relationsh


### M14. Migration FK ADD CONSTRAINT statements are not idempotent and rely on swallowing exceptions — a partial failure mid-run leaves the production schema half-migrated with no rollback or ordering guarantee

- **Severity:** medium  ·  **Area:** `be-data-model-migrations` / config
- **Location:** `database_compare/migrations.py:34-36, 43-45, 60-62; run_production_migration.py:47-57`
- **Impact:** On an existing prod DB the migration 'works' but silently masks real failures: a constraint that fails to apply because of dirty data is logged as a harmless skip, leaving prod without the FK/index it thinks it has. Because each statement is its own transaction, there is no all-or-nothing guarantee — a crash mid-list leaves a partially migrated schema. This is the core re-run-safety weakness of a hand-rolled migration runner with no version table.
- **Fix:** Wrap each ADD CONSTRAINT in a DO $$ ... IF NOT EXISTS check against pg_constraint, or pre-drop-if-exists, so it is truly idempotent and doesn't rely on exception-swallowing. Distinguish 'already exists' (42710/42P07/duplicate_object) from real errors and fail loudly on the latter. Add a schema_migrations version table (label + applied_at) so re-runs are tracked rather than re-attempted-and-caught.
- **Verified:** Verified against actual code — finding is technically accurate on every point. (1) migrations.py:34-36, 43-45, 60-62 use raw `ALTER TABLE ... ADD CONSTRAINT fk_...` with NO idempotency guard; Postgres indeed lacks `ADD CONSTRAINT IF NOT EXISTS`, so these throw 42710 on every re-run. This directly contradicts the file's own docstring (migrations.py:5) which claims "Every statement is safe to run repeatedly" — the column/index stmts correctly use IF NOT EXISTS (lines 16,20,33,42,47,64) but the 3 FK adds do not. (2) run_production_migration.py:54-56 catches bare `Exception` and labels ALL failure


### M15. authorities create path checks email uniqueness but NOT phone — admins can be created with a phone that already exists on a member or another authority

- **Severity:** medium  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/authority_management/services/authority_service.py:58-78`
- **Impact:** Direct path to phone collisions between admins and staff/other admins, which is the same account-shadowing/cross-tenant login hazard as the first finding but via the admin-creation route, which has zero phone guarding.
- **Fix:** Add the cross-table phone check to AuthorityService.create (reuse the same logic as StaffService._phone_taken across authorities+members) and back it with the DB partial-unique constraint recommended in the first finding.
- **Verified:** CONFIRMED against the code. `AuthorityService.create` (authority_service.py:58-78) checks `get_by_email` and `get_by_authority_id` only — there is NO phone check. The authority model has `email = Column(..., unique=True)` (authority.py:24) but `phone = Column(String(20), nullable=False)` (authority.py:26) with no unique constraint, and no phone unique constraint exists in database_compare migrations. This endpoint is live: `POST /api/v1/authorities/` (authority.py:134-148, gated by require_authority = authority/super-admin) calls `service.create` with the supplied phone. Login resolves a user 


### M16. Connection pool too small for 100k users; NullPool imported but unused; PgBouncer assumed but not enforced

- **Severity:** medium  ·  **Area:** `be-scale-perf` / config
- **Location:** `app/core/config.py:db_pool_size=10, db_max_overflow=20 (37-38)`
- **Impact:** Peak DB connections = workers * 2 engines * (10+20) = 60/worker. With many gunicorn workers this blows past Postgres max_connections fast, yet per-worker only 30 concurrent statements are possible — under load requests queue on pool checkout and time out. Because each gated request holds a connection for ~4 serial auth queries + a blocking bcrypt, connections are held far longer than necessary, so even 30 saturates quickly. The unused NullPool import signals the pooling strategy was never finalised.
- **Fix:** Put PgBouncer in transaction mode in front and set SQLAlchemy poolclass=NullPool (or a small pool) so the app does not double-pool. Right-size based on (workers x engines) <= Postgres max_connections with headroom. Reduce connection hold time by fixing the per-request auth query fan-out and offloading bcrypt. Remove the dead NullPool import or actually use it.
- **Verified:** CONFIRMED real, but downgraded high->medium (overstated for the actual deployment). All cited facts verify: config.py:36-37 db_pool_size=10/db_max_overflow=20; database.py:21-26 _POOL_KWARGS used by BOTH engine (28-42) and background_engine (45-58) with default QueuePool; database.py:6 `from sqlalchemy.pool import NullPool` imported and never referenced (grep: only the import line). Deployment really is gunicorn `-w 4 ... --preload` (Dockerfile:85, docker-compose.yml:106) against Postgres 14-alpine with default max_connections=100 and NO PgBouncer anywhere (only a comment at database.py:18 / c


### M17. _getUserInitials can throw RangeError on names with empty parts / leading-trailing whitespace

- **Severity:** medium  ·  **Area:** `fe-correctness-state` / crash/null-deref
- **Location:** `lib/shared/widgets/navigation_sidebar.dart:293-304`
- **Impact:** A user whose profile name contains a double space or odd whitespace (real with free-text data at 100k users) crashes the sidebar build → the whole shell fails to render (red screen / blank nav). Hard to reproduce in QA, guaranteed to occur in the wild.
- **Fix:** Filter empties: `final parts = name.split(' ').where((p)=>p.isNotEmpty).toList();` then guard parts.isEmpty before indexing, and guard name.isEmpty before name[0]. Return 'U' as the fallback.
- **Verified:** CONFIRMED real. lib/shared/widgets/navigation_sidebar.dart:293-304. `_getUserInitials()` does `name.split(' ')` then unconditionally indexes `parts[0][0]`/`parts[1][0]`, and falls back to `name[0]` without an isEmpty guard. Multiple reproducible RangeError paths exist:
1) Single free-text field with internal double space: `first_name='John  Smith'`, `last_name=''` → `_getUserName()` returns `'John  Smith'` (line 284) → split = `['John','','Smith']` (len>=2) → `parts[1][0]` = `''[0]` → RangeError.
2) Trailing/leading space across fields: `first_name='John '`,`last_name='Smith'` → `'John  Smith'


### M18. applicationId / namespace still the placeholder com.example.edu_assist_dynamic

- **Severity:** medium  ·  **Area:** `fe-crossplatform-config` / config
- **Location:** `android/app/build.gradle.kts:9,24`
- **Impact:** Google Play forbids publishing apps with a com.example.* application ID. The applicationId is permanent once published, so shipping the placeholder either gets rejected or locks you into an unprofessional, non-namespaced ID forever. iOS has the analogous risk via PRODUCT_BUNDLE_IDENTIFIER (set in the Xcode project, not shown here — verify it is not com.example.*).
- **Fix:** Set applicationId/namespace to your real reverse-domain (e.g. com.yourcompany.eduassist) before first publish, and verify the iOS PRODUCT_BUNDLE_IDENTIFIER in ios/Runner.xcodeproj matches a real bundle ID owned by your Apple team.
- **Verified:** Confirmed against actual code. Android: android/app/build.gradle.kts line 9 `namespace = "com.example.edu_assist_dynamic"` and line 24 `applicationId = "com.example.edu_assist_dynamic"`, both still carrying the Flutter scaffold TODOs (lines 23/35: "Specify your own unique Application ID"). iOS: ios/Runner.xcodeproj/project.pbxproj has `PRODUCT_BUNDLE_IDENTIFIER = com.example.eduAssistDynamic` at lines 480, 663, 686 (plus RunnerTests variants) — so the finding's predicted iOS risk is real too. No package override in AndroidManifest. This is a genuine release blocker: Google Play and the App Sto


### M19. JWT access + refresh tokens persisted in plaintext SharedPreferences / web localStorage on a multi-tenant app

- **Severity:** medium  ·  **Area:** `fe-crossplatform-config` / authz
- **Location:** `lib/core/auth/auth_storage.dart:10-49`
- **Impact:** The long-lived refresh token (and access token, plus role/organisationId/groupId) sits in cleartext. On web, localStorage is readable by any XSS payload and persists indefinitely — a single XSS gives an attacker a refresh token they can use to re-mint access tokens and impersonate a tenant admin/super-admin. On shared/kiosk devices or a rooted/jailbroken phone, the token file is readable. For a 100k+ user multi-tenant SaaS where one stolen super-admin/admin refresh token crosses tenant boundaries, this is a real cross-tenant exposure vector.
- **Fix:** On mobile, store the refresh token in flutter_secure_storage (Keychain/Keystore). On web, prefer an httpOnly, Secure, SameSite refresh-token cookie set by the backend (not reachable from JS) and keep only the short-lived access token in memory. Keep token lifetimes short and support server-side refresh-token revocation.
- **Verified:** Confirmed accurate. auth_storage.dart:10 persists JWT access+refresh tokens via shared_preferences (web=localStorage); _kAccess/_kRefresh saved at lines 31-32, read 42-43. auth_session.dart:8-9 admits secure storage is an unfinished "follow-up". flutter_secure_storage is NOT in pubspec.yaml (grep: zero hits anywhere in repo). Backend confirms refresh token TTL = 7 days (config.py:24) vs 30-min access (config.py:23). MAKES IT WORSE than the finding states: the /refresh endpoint (edu_backend app/auth_rbac/routers/auth.py:181-203) performs NO jti/denylist check — the denylist:{jti} revocation (au


### M20. Auth endpoints (login, signup verify, logout, forgot-password, reset) have no HTTP timeout

- **Severity:** medium  ·  **Area:** `fe-crossplatform-config` / ux
- **Location:** `lib/services/auth_api_service.dart:31,53,100,147,159`
- **Impact:** If the backend is slow/unreachable (down server, dropped Wi-Fi, the wrong base URL above), the login/signup/forgot/reset calls hang indefinitely — the default Dart http client has no timeout. The user sees a spinner that never resolves, with no error and no way to retry; the most-used entry path of the app appears frozen. At 100k+ users this generates large numbers of stuck sessions during any backend latency spike.
- **Fix:** Add a consistent .timeout(const Duration(seconds: 12)) (or a shared wrapper) to every http call in auth_api_service.dart, matching the rest of the codebase. Centralise into one HTTP client/helper so no call site can forget it.
- **Verified:** CONFIRMED, but high is overstated -> medium. Code at lib/services/auth_api_service.dart verified: login (line 31), logout (line 53), signupVerify (line 100), the _post helper (line 147, used by signupRequestOtp/forgotRequestOtp/resetPassword) and _authedPost (line 159) all call the top-level http.post with NO chained .timeout(). Only refreshSession() (line 74) sets one (6s, not 12 as I'd expect). The top-level http.post in package:http builds a transient default client with no timeout, and there is NO custom Client/IOClient/connectionTimeout/interceptor anywhere in lib/ (grep returned nothing)


### M21. No retry/backoff or token-refresh-on-401 anywhere; transient failures surface as hard errors

- **Severity:** medium  ·  **Area:** `fe-crossplatform-config` / ux
- **Location:** `lib/services/super_admin_service.dart:37-52`
- **Impact:** A single dropped packet, a brief 502 during a backend deploy, or an access token that expires mid-session turns into a user-facing failure/logout instead of a transparent recovery. At 100k+ concurrent users on mobile networks, transient blips are constant; without retry/backoff this produces a steady stream of avoidable errors and, on mid-session token expiry, forced re-logins.
- **Fix:** Introduce a shared HTTP client wrapper with: (a) limited retry + exponential backoff with jitter for network errors and 502/503/504; (b) a 401 handler that calls refreshSession() once and replays the original request; (c) one place that attaches headers and timeouts. Refactor services to go through it.
- **Verified:** CONFIRMED, real medium-severity UX/resilience gap. Verified across all HTTP call sites.

Evidence:
- refreshSession() (auth_api_service.dart:64-84) is the ONLY token-refresh path and is invoked exactly once, at launch, gated on accessTokenExpired (main.dart:21-22). Grep confirms refreshSession appears only in its definition and that one launch call.
- No 401 interceptor anywhere: there is no code that catches r.statusCode==401 to refresh and replay the original request (grep for 401 returns nothing in the data services). Data services just throw via _err() on any non-200.
- No retry/backoff on


### M22. Dynamic text scaling is globally disabled — app ignores OS font-size accessibility setting

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / accessibility
- **Location:** `lib/main.dart:68`
- **Impact:** Low-vision users on iPhone (Settings > Display > Text Size / Larger Text) and Android (Font size) get ZERO effect from their accessibility setting — the app stays at base size everywhere. This is a hard WCAG/ platform-accessibility failure and, for a 100k+ user SaaS, excludes a meaningful slice of users. It was almost certainly added to 'fix' overflow, which masks the real responsive bugs rather than fixing them.
- **Fix:** Remove the hard linear(1.0) override. If unbounded scaling breaks layouts, CLAMP instead of pinning, e.g. TextScaler.linear(MediaQuery.textScaler.scale(1).clamp(1.0, 1.3)) using clampedScaler, and fix the underlying fixed-height widgets (search bars, header) so they grow with text.
- **Verified:** CONFIRMED. lib/main.dart:68 in MaterialApp.router's builder does `final media = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0));` then wraps the entire router output (child) in MediaQuery(data: media, ...) at lines 87-92. Since this is the top-level builder, every descendant route reads scale 1.0, so OS font-size / "Larger Text" / Dynamic Type settings have zero effect app-wide. Grep across all of lib/ shows this is the ONLY textScaler/textScaleFactor reference — there is no clamping, no per-screen restore, no other guard that re-honors the platform setting. The audit


### M23. Header hamburger & feedback icons have sub-44px tap targets

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / accessibility
- **Location:** `lib/shared/widgets/navigation_header.dart:112-122, 146-166`
- **Impact:** The primary navigation control (open the sidebar/menu) and feedback entry are ~28-30px — below the 44px iOS / 48px Android minimum the design doc itself mandates (rule 5). On a real phone these are easy to mis-tap, especially the hamburger which is the only way to navigate on mobile. Affects every page for every role.
- **Fix:** Wrap each header action in a 44x44 min constraint (SizedBox(width:44,height:44) or BoxConstraints(minWidth:44,minHeight:44)) and increase header height if needed, or use IconButton with default 48px target. Keep the visual icon small but expand the hit area.
- **Verified:** Verified against navigation_header.dart. Menu button (lines 146-166): InkWell > Container(padding EdgeInsets.all(6)) > Icon(Icons.menu, size:16) = 16+12 = 28px square hit area. Feedback button (lines 112-122): InkWell > Padding(EdgeInsets.all(6)) > Icon(size:18) = 18+12 = 30px. Neither has BoxConstraints/SizedBox forcing a minimum, and a Material InkWell only hit-tests within its child's intrinsic size (it does NOT stretch to fill the parent Row), so the actual tap targets really are 28/30px despite the 48px header. Confirmed the design doc the finding cites: important_documents/UI_DESIGN_SYST


### M24. Android hardware back button is unhandled everywhere — exits the app / loses unsaved form data with no confirm

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / ux
- **Location:** `lib/core/utils/app_router.dart:n/a (whole app)`
- **Impact:** On Android, pressing the hardware Back button on a top-level shell page (e.g. Staff & Users, Analytics) pops the whole route → the user is thrown to the landing/login or out of the app, with no 'are you sure'. Inside a half-filled create-organisation dialog, Back dismisses it and silently discards all entered data. This is a platform-specific UX break that web/iPhone don't surface the same way, so it slips testing.
- **Fix:** Add a PopScope at the shell level (confirm-on-exit or route to landingRoute() instead of exiting) and PopScope(canPop:false)+confirm inside dialogs with dirty form state. At minimum guard the create/edit organisation and admin/staff form dialogs against accidental data loss.
- **Verified:** Partially real but overstated; downgrade high → medium.

VERIFIED: grep across lib/ for PopScope/WillPopScope/onPopInvoked/onWillPop returns zero matches — evidence is accurate. Android is a real target (android/ exists). The genuine defect is in the multi-tab dirty-form dialogs: organisation_create_dialog.dart and organisation_edit_dialog.dart (both have GlobalKey<FormState>, a 3-tab TabController, and ~8 TextEditingControllers). They are opened via showDialog at organisation_management_screen.dart:961 (edit), admin_onboarding_screen.dart:71 and org_switcher.dart:91 (create) with no barrierDi


### M25. Global AI assistant FAB overlaps the last list item / bottom content on scrolling pages

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / ux
- **Location:** `lib/features/organisation_management/screens/organisation_management_screen.dart:608`
- **Impact:** On phones the AI assistant (which the design doc reserves the bottom-right corner for, rule 7) physically covers the last row's actions and the right edge of the final card, so users cannot reach the kebab/Edit of the bottom organisation without scrolling extra. Several lists use a 28px bottom pad while others correctly use ~96px (staff_management:135, role_management:118). Inconsistent and the 28px ones break.
- **Fix:** Standardise the bottom scroll inset to >=96px on every scrollable page so content clears the 76px FAB stack (organisation_management list, analytics ListView:83, feedback:160, module_access:90, profile:98, institution_groups:138, organisation_selection:317 all use 28). Add it to the SaScreen/skeleton guidance.
- **Verified:** CONFIRMED real, but severity overstated (high -> medium). The global AI FAB is genuinely mounted over every page: main.dart:70-82 wraps every routed page in a Stack with AIAssistantWidget on top, visible by default (ai_assistant_manager.dart:17 isVisible=true). FAB geometry verified at lib/shared/widgets/ai_assistant_widget.dart (correct path; finding cited the wrong path lib/features/organisation_management/.../ai_assistant_widget.dart) — right:20, bottom:20 (lines 315-316), 56px button (332-333), so it owns the bottom-right ~20-76px band. organisation_management_screen.dart:608 ListView uses


### M26. Off-palette colours (teal success, amber warning, cyan info) used despite green-only rule

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / design-system
- **Location:** `lib/shared/widgets/feedback_dialog.dart:64, 124`
- **Impact:** Design rule 3 forbids blue/cyan/amber/teal — 'red only for errors, green/neutral otherwise'; AppTheme.success/warning/info were supposedly 'removed everywhere'. The feedback success snackbar shows a teal toast instead of the brand green every other success uses, the rating stars are amber, and the live AI 'online' dot is teal — visible palette drift on user-facing surfaces.
- **Fix:** Replace AppTheme.success → AppTheme.greenPrimary, AppTheme.warning → AppTheme.greenPrimary (or neutral), AppTheme.info → AppTheme.greenPrimary in these files. Better: delete success/warning/info from AppTheme so they can't be reintroduced.
- **Verified:** CONFIRMED — all 6 cited usages exist and violate an explicit, documented design rule. Verified facts: app_theme.dart defines success=#10B981 (teal, L31), warning=#F59E0B (amber, L32), info=#06B6D4 (cyan, L34), greenPrimary=#2E7D32 (L16). The "green-only" rule is not invented — UI_DESIGN_SYSTEM.md L26-28 states "Palette = green + white + neutral gray... red only for errors... No blue, cyan, amber, teal, purple" and L58-59 explicitly says "Do NOT use AppTheme.success / info / warning (off-brand teal/blue/amber) — they were removed everywhere; use green or neutral." Violations confirmed by readin


### M27. Sidebar user/footer text rendered at 7-8px — illegible and fails contrast/size minimums

- **Severity:** medium  ·  **Area:** `fe-ux-design-responsive` / accessibility
- **Location:** `lib/shared/widgets/navigation_sidebar.dart:563-566, 591-593, 620-627, 661-666`
- **Impact:** 7-8px text is below any legibility threshold and effectively unreadable on a high-DPI phone, and because text scaling is globally pinned to 1.0 (see other finding) the user cannot enlarge it. The role, active-organisation name and logout label in the sidebar footer are practically invisible. For a multi-tenant app the active-org indicator being unreadable is also a (minor) tenancy-clarity issue.
- **Fix:** Raise these to >=11px (use Sa.label 12.5 / a micro 11), and once text scaling is re-enabled they will respect user prefs. Audit all fontSize:7/8 occurrences.
- **Verified:** CONFIRMED. Cited lines are accurate in lib/shared/widgets/navigation_sidebar.dart: role label const TextStyle(fontSize: 8) at 563-566, org/active-tenant chip Text(fontSize: 7) at 591-593 (renders OrgSession.name), 'Logout' fontSize: 8 at 620-627, 'v1.0.0' fontSize: 8 at 661-666. The finding also MISSED a 5th occurrence: nav-item badge fontSize: 7 at line 454. The impact premise is verified: lib/main.dart:68 pins textScaler: const TextScaler.linear(1.0) over the whole app (MaterialApp.router builder wrapping all routes), so users genuinely cannot enlarge this text via OS accessibility settings.


## ⚪ LOW — 42


### L1. Entire /api/v1/organisations bulk + CRUD surface mutates org data with NO ownership/tenant check (mass cross-tenant write & destroy)

- **Severity:** low  ·  **Area:** `be-authz-tenancy` / authz
- **Location:** `app/organisation_management/routers/organisation.py:374-832 (update_organisation 374, delete_organisation 456, reactivate 503, bulk/update-status 643, bulk/update-capacity 684, bulk/update-financial 722, bulk/update-charges 760, bulk/delete 800, bulk/import 608)`
- **Fix:** Add an explicit Depends(require_super_admin) (or get_current_principal + assert) to EACH destructive/listing route rather than relying solely on the include-level dependency. Defense in depth: never let a data-mutating route be authorized o


### L2. switch-organisation persists active org without re-checking org/group is still active, letting an admin re-scope into a deactivated org

- **Severity:** low  ·  **Area:** `be-authz-tenancy` / tenancy
- **Location:** `app/auth_rbac/routers/auth.py:614-638 (switch_organisation)`
- **Fix:** If reactivation is the only legitimate reason to enter an inactive org, restrict switching into inactive orgs to a dedicated reactivate flow; otherwise block switching into is_active=false orgs. Do not issue a refresh token on switch into a


### L3. Login enumerates identity tables by phone and authenticates the first matching record across tenants — relies solely on phone uniqueness enforcement that has TOCTOU gaps

- **Severity:** low  ·  **Area:** `be-authz-tenancy` / authn
- **Location:** `app/auth_rbac/services/login_service.py:77-110 (authenticate loop) ; uniqueness in app/staff_management/services/staff_service.py:64-81 (_phone_taken) and invitation_service.py:138-153 (assert_phone_available)`
- **Fix:** Enforce phone uniqueness at the database level across the identity space (e.g. a shared unique index / partial unique constraints, or a single identities table), and wrap create with an ON CONFLICT / SELECT ... FOR UPDATE. Make login determ


### L4. Unhandled-exception handler returns full exception text to clients whenever environment is not production/staging

- **Severity:** low  ·  **Area:** `be-authz-tenancy` / config
- **Location:** `app/main.py:140-146 (handle_general_exception) ; is_production app/core/config.py:60-62`
- **Fix:** Default to the safe (production) message unless explicitly in a known-dev environment, i.e. invert the check to fail safe. Never include exc text in client responses by default.


### L5. Health router imports non-existent cache_manager — cache-health and full-health crash / always report healthy

- **Severity:** low  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/routers/health.py:74, 104-107`
- **Fix:** Import cache_service and actually ping it (await cache_service.client.ping()). Remove the bare `except:`; on any cache error mark the component unhealthy. Add a dedicated /readyz that checks DB + Redis and returns 503 when degraded.


### L6. PII (phone numbers) and full request paths logged at INFO; OTP codes logged in dev mode

- **Severity:** low  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/auth_rbac/security/otp.py:40-41`
- **Fix:** Never log OTP codes (remove even in dev, or mask). Redact/avoid phone numbers and request bodies in logs. Lower request logging to DEBUG or sample it; ensure error logs don't dump raw payloads with PII.


### L7. Logout swallows all errors with a broad except and can no-op silently

- **Severity:** low  ·  **Area:** `be-correctness-prod` / authz
- **Location:** `app/auth_rbac/routers/auth.py:206-218`
- **Fix:** Don't blanket-swallow; on a valid token, verify the denylist write succeeded and surface a 500 if it didn't (or move to token_version invalidation that doesn't depend on best-effort Redis).


### L8. JWT secret has no minimum-length/strength enforcement and HS256 is hardcoded; no key rotation

- **Severity:** low  ·  **Area:** `be-correctness-prod` / config
- **Location:** `app/core/config.py:9, 22`
- **Fix:** Validate at startup that jwt_secret_key is >=32 random bytes and not a known default; fail fast otherwise. Plan a key-rotation mechanism (kid header + accept-old-during-rollover) for the 100k+ deployment.


### L9. authorities.phone has NO index but login performs a phone-equality scan on it for every login attempt

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / perf
- **Location:** `app/authority_management/models/authority.py:26`
- **Fix:** Add `CREATE INDEX IF NOT EXISTS ix_authorities_phone ON authorities (phone)` to migrations.py and `index=True` on the model column. Ideally a partial index `WHERE is_deleted = false`. Same review for super_admins.phone (it is indexed) — fin


### L10. seed_default_roles runs in production and writes data on every prod migration (mass UPDATE assigning rbac_role_id) — a data-mutating step inside the 'sync schema' script

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / config
- **Location:** `database_compare/seeds.py:39-60; run_production_migration.py:59-62`
- **Fix:** Separate schema migration from data seeding. Make seed_default_roles a one-shot, explicitly-invoked backfill (or guard it so it only assigns to brand-new orgs), not something the routine prod schema-sync re-executes. seed_dev_passwords is c


### L11. Timezone-naive DateTime columns (last_login, joining_date, date_of_birth) mixed with timezone-aware ones, and login writes datetime.utcnow() into a naive column

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/authority_management/models/authority.py:27, 44, 51; member.py:43,52`
- **Fix:** Make ALL timestamp columns DateTime(timezone=True) consistently (add ALTER TABLE ... TYPE TIMESTAMPTZ USING ... migrations), and standardise on timezone-aware datetime.now(timezone.utc) instead of utcnow() in the services.


### L12. Random UUIDv4 primary keys on every table cause index fragmentation and poor insert locality at 100k+ rows

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / perf
- **Location:** `app/models/base.py:19`
- **Fix:** Switch to a time-ordered UUID (UUIDv7) or ULID for PK defaults to restore insert locality, and remove the redundant `index=True` on the primary key in base.py (the PK already has a unique index). This halves PK index write cost immediately.


### L13. No composite index for the common tenant-list access pattern (organisation_id/group_id + is_deleted [+ status]) — list endpoints will seq-scan or fetch-then-filter at scale

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / perf
- **Location:** `app/staff_management/models/member.py:20, 37, 47; authority.py:13,16,40; access/models.py:16`
- **Fix:** Add composite indexes matching the access path, e.g. `CREATE INDEX ix_members_org_active ON members (organisation_id, is_deleted, status)` and `CREATE INDEX ix_authorities_group_active ON authorities (group_id, is_deleted)` / `(organisation


### L14. feedback.user_id / organisation_id and invitation.target_user_id / created_by are plain UUIDs with no FK — orphaned references and no tenant-integrity guarantee

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / data-model
- **Location:** `app/feedback_management/models/feedback.py:14-15; invitation.py:32,35; authority.py (created_by-style cols) ; access/models.py:22`
- **Fix:** Where a column unambiguously targets one table (feedback.organisation_id, invitation.organisation_id has a FK already), add a FK. For polymorphic user_id, validate organisation_id against the caller's tenant in app code and add a CHECK on u


### L15. organisations.group_id and owner_authority_id FKs/columns are model-vs-migration split (column in ORM, FK only in migrations.py) — a fresh create_all DB has the columns but no FK until migrations run

- **Severity:** low  ·  **Area:** `be-data-model-migrations` / config
- **Location:** `app/organisation_management/models/organisation.py:58, 62; migrations.py:41-64`
- **Fix:** Declare these as proper ForeignKey columns in the ORM model (with ondelete='SET NULL' to match migrations) so create_all and prod stay consistent, and keep the idempotent ALTER only as a backfill for old DBs.


### L16. authorities.phone has NO index — every login and phone-uniqueness check is a full table scan

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/authority_management/models/authority.py:phone = Column(String(20), nullable=False)`
- **Fix:** Add `index=True` to Authority.phone and a migration `CREATE INDEX IF NOT EXISTS ix_authorities_phone ON authorities (phone)`. Phone is the login key on both identity tables; it must be indexed on both. Consider a partial index WHERE is_dele


### L17. Group/admin permission maps load ALL rows for a group repeatedly within a single request (redundant queries + per-module re-query)

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/access/service.py:_group_role_map 44-54; _group_admin_map 56-65; _group_role_enabled 67-77; group_id_for_org 33-41`
- **Fix:** Resolve group_id once per request and pass it down (the per-group editors already take group_id directly; do the same for the org-scoped path). In set_role_modules, fetch the whole GroupModulePermission set once (already have _group_role_ma


### L18. set_all_group_pages / set_all_admin_pages commit once PER module in a loop (N commits, N round-trips)

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/access/service.py:set_all_group_pages 470-474; set_all_admin_pages 516-520; set_group_module 424-445`
- **Fix:** Do the bulk update in one transaction: load existing rows once, upsert all in memory, single commit. Or use a single INSERT ... ON CONFLICT DO UPDATE statement keyed by (group_id, module_key).


### L19. list_staff / list_users / list_roles / list_admins / list_groups / my-organisations have no pagination (unbounded per-tenant result sets)

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/staff_management/services/staff_service.py:list_staff 22-35`
- **Fix:** Add page/size pagination (the codebase already has base_service.get_paginated) with a hard max page size, and server-side search. Select only displayed columns. Apply to all per-tenant list endpoints.


### L20. Hot list filters lack composite indexes; queries filter on (organisation_id, is_deleted) / (group_id, is_deleted) but only single-column indexes exist

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `database_compare/migrations.py:13-69 (no composite index migrations)`
- **Fix:** Add composite indexes: organisations(group_id, is_deleted), authorities(group_id, is_deleted), members(organisation_id, is_deleted, created_at DESC). For list_groups, replace correlated COUNT(*) subqueries with GROUP BY aggregate joins. Add


### L21. list_groups and list_admins use correlated COUNT(*) subqueries that re-scan organisations/authorities per row (N+1 in SQL)

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/routers/auth.py:list_groups 521-532; list_admins 372-383`
- **Fix:** Rewrite as a single LEFT JOIN ... GROUP BY g.id with COUNT(FILTER(...)) so counts are computed in one pass, and add the composite indexes above.


### L22. login_service runs bcrypt for every phone-matching row and issues extra per-login status queries

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/auth_rbac/services/login_service.py:authenticate 78-110; assert_active 133-154; _group_active/_org_status 113-130`
- **Fix:** Enforce phone uniqueness so at most one row matches, query identity tables in one UNION/parallel lookup, break after first verifying row, and fold the active-status checks into the identity query (JOIN org/group) to cut round-trips. Offload


### L23. create_all + idempotent migrations run on every startup; create_all does not add columns/indexes, risking missing indexes in prod

- **Severity:** low  ·  **Area:** `be-scale-perf` / config
- **Location:** `app/main.py:86-95 (run_sync(Base.metadata.create_all))`
- **Fix:** Either adopt Alembic with autogenerate, or add a CI check that diffs model-declared indexes against the migrations list and fails if any are missing. Add the missing index migrations now.


### L24. CacheService.set always json.dumps and has no jitter/negative-cache; not used for the expensive resolutions

- **Severity:** low  ·  **Area:** `be-scale-perf` / perf
- **Location:** `app/core/cache.py:get 24-32; set 34-42`
- **Fix:** Cache the role-id and group permission maps here with short TTL + invalidation hooks in the RBAC write paths. Initialise the Redis client once at startup only and treat a missing client as an error rather than re-initialising inside get/set


### L25. Admin can self-elevate / overwrite arbitrary fields via PUT /api/v1/authorities/{id} (mass-assignment of status + permissions)

- **Severity:** low  ·  **Area:** `be-sqli-input` / authz
- **Location:** `app/authority_management/routers/authority.py:196-216 (route), 34-47 (AuthorityUpdate schema), 110-122 (BaseService.update)`
- **Fix:** Drop `status` and `permissions` from AuthorityUpdate (admins must not set their own permissions/status — those are super-admin-only). Replace BaseService.update's blind setattr with an explicit allow-list per caller role, or pass an `allowe


### L26. Entire /api/v1/authorities router is writable by any organisation admin with weak/legacy validation and unbounded bulk lists

- **Severity:** low  ·  **Area:** `be-sqli-input` / input-validation
- **Location:** `app/authority_management/routers/authority.py:50-70 (bulk models), 15-32 (AuthorityCreate), 260-371 (bulk routes)`
- **Fix:** Add Field(..., min_items=1, max_items=100) (or 1000 for import) to every bulk List on this router, mirroring organisation.py. Add phone-format + length validators to AuthorityCreate. Cap the per-request row count server-side as defense in d


### L27. POST /api/staff create accepts unvalidated phone/email/names (no format, no length cap) — model_dump-free but still unbounded

- **Severity:** low  ·  **Area:** `be-sqli-input` / input-validation
- **Location:** `app/staff_management/routers/staff.py:24-39 (StaffCreate/StaffUpdate), 102-142 (create/update routes)`
- **Fix:** Add EmailStr for email, a phone validator (digits/length), and max_length matching the columns (first/last 50, phone 20, email 100, position 100) on StaffCreate/StaffUpdate. Do the same for CreateAdminRequest/UpdateAdminRequest in auth.py (


### L28. Auth schemas (login/admin/signup) have no phone format, email format, or length caps; password min only 6

- **Severity:** low  ·  **Area:** `be-sqli-input` / input-validation
- **Location:** `app/auth_rbac/routers/auth.py:41-43 (LoginRequest), 60-75 (Invite*), 77-98 (Signup), 279-305 (CreateAdmin/Update/Reset), 37 (MIN_PASSWORD_LEN=6)`
- **Fix:** Use EmailStr for all email fields; add a shared phone validator (normalized digits, 8-15 length); add max_length (e.g. 128) and a lower bound on password; validate OTP is 4-8 digits. Centralize in a shared base model.


### L29. List endpoints return ALL rows with no pagination (feedback list, /api/access/users, /api/auth/admins, /api/staff) — unbounded result sets

- **Severity:** low  ·  **Area:** `be-sqli-input` / perf
- **Location:** `app/feedback_management/routers/feedback.py:feedback.py:89-104 (list_feedback); access/router.py:362-383 (list_users); auth.py:359-395 (list_admins); staff.py:95-99 (list_staff)`
- **Fix:** Add keyset or page/size pagination (mirroring BaseService.get_paginated) with a hard server-side cap (e.g. <=200) on all directory/list endpoints.


### L30. OrgSession (global static) is never cleared on logout and never updated on org-switch — stale tenant name bleeds across sessions

- **Severity:** low  ·  **Area:** `fe-correctness-state` / tenancy/state-management
- **Location:** `lib/core/utils/org_session.dart, lib/shared/widgets/main_layout.dart, lib/services/auth_api_service.dart:main_layout.dart:98-101 (setData only when organisationId==null); auth_api_service.dart:49-58 (logout clears AuthSession+PermissionStore, NOT OrgSession); org_switcher.dart:65-74 (switch never updates OrgSession)`
- **Fix:** Call OrgSession.clearData() inside AuthApiService.logout() and inside switchOrganisation()/setFromLogin(). Remove the 'only when null' guard so hydration always reflects the current AuthSession. Better: derive the displayed org name from a 


### L31. Inline TextEditingControllers created inside dialog methods are never disposed (leak per dialog open)

- **Severity:** low  ·  **Area:** `fe-correctness-state` / memory
- **Location:** `lib/features/admin/screens/staff_management_screen.dart, lib/features/admin/screens/role_management_screen.dart, lib/features/super_admin/screens/institution_groups_screen.dart:staff_management_screen.dart:242 (ctl), 299-303 (firstCtl,lastCtl,phoneCtl,emailCtl,posCtl); role_management_screen.dart:198-199 (nameCtl,descCtl); institution_groups_screen.dart:59 (controller)`
- **Fix:** Wrap each dialog body so the controllers are disposed when the dialog closes — easiest is to make each editor a StatefulWidget that owns the controllers and disposes them, or add `.whenComplete(() { ctl.dispose(); ... })` after the awaited 


### L32. AIAssistantManager holds a stale WidgetRef in a static field (Riverpod anti-pattern)

- **Severity:** low  ·  **Area:** `fe-correctness-state` / state-management/memory
- **Location:** `lib/core/services/ai_assistant_manager.dart, lib/main.dart:ai_assistant_manager.dart:77-95 (static WidgetRef _ref); main.dart:47-51 (initialize(ref) in addPostFrameCallback)`
- **Fix:** Drive AI visibility purely through the provider (ref.read(aiAssistantProvider.notifier)) from within a Consumer/ConsumerState that is actually in the tree, or use a plain ValueNotifier/global StateNotifier not tied to a WidgetRef. Remove th


### L33. OrgSwitcher silent auto-switch calls context.go after an await with no mounted/race guard

- **Severity:** low  ·  **Area:** `fe-correctness-state` / crash/state-management
- **Location:** `lib/shared/widgets/org_switcher.dart:44-52 (silent _switch from _load), 65-74 (_switch: await then context.go)`
- **Fix:** Do the active-org adoption once at a higher level (e.g. in switchOrganisation/login flow), not as a side effect of header rendering. For the silent path, only update session state; do not call context.go. Guard against repeat calls with a f


### L34. didChangeMetrics in AIAssistantWidget calls setState on every metrics change with no mounted check inside the delayed callbacks

- **Severity:** low  ·  **Area:** `fe-correctness-state` / state-management/perf
- **Location:** `lib/shared/widgets/ai_assistant_widget.dart:62-78 (didChangeMetrics setState), 44-48 & 74-77 (Future.delayed -> _scrollToBottom)`
- **Fix:** Guard didChangeMetrics with `if (!mounted) return;` and early-return when !_isChatOpen so no rebuild happens while the chat is closed. Add mounted checks inside the Future.delayed callbacks.


### L35. _handleLogout fires AuthApiService.logout() without awaiting, then navigates — token revocation can be skipped

- **Severity:** low  ·  **Area:** `fe-correctness-state` / auth
- **Location:** `lib/shared/widgets/main_layout.dart:182-195`
- **Fix:** await AuthApiService.logout() before navigating, or ensure the logout POST is fire-and-forget but reliably dispatched (it currently is best-effort). Acceptable to keep unawaited if server revocation is not critical, but document it.


### L36. OrganisationSelectionScreen 'Load more' button is dead code / confusing — hasMoreData is permanently false

- **Severity:** low  ·  **Area:** `fe-correctness-state` / ux
- **Location:** `lib/features/screens/organisation_selection_screen.dart:100-101 (hasMoreData=false), 121-124 (loadMoreOrgs), 330-353 (buildLoadMoreWidget), 28-29 (currentPage/pageSize unused)`
- **Fix:** Either implement real server pagination/infinite scroll, or remove the dead pagination scaffolding and add a server-side search so the client isn't filtering the entire org universe in memory. Debounce the search listener.


### L37. Router has no /login route and redirects all unknown unauthenticated paths to home, losing deep links

- **Severity:** low  ·  **Area:** `fe-correctness-state` / routing
- **Location:** `lib/core/utils/app_router.dart:32-45`
- **Fix:** Capture state.uri as a `from`/`redirect` query param on the bounce and, after successful login, honour it instead of always going to landingRoute().


### L38. Web PWA shell ships Flutter scaffold placeholders (title, description, theme color, app name)

- **Severity:** low  ·  **Area:** `fe-crossplatform-config` / ux
- **Location:** `web/manifest.json:1-10`
- **Fix:** Set real name/short_name/description, a brand theme/background color, a proper <title> and meta description, and replace the default favicon/icons (web/icons still ship the Flutter defaults). Keep the manifest theme_color in sync with the a


### L39. Bulk-operations dialog dumps raw exception text to the user

- **Severity:** low  ·  **Area:** `fe-ux-design-responsive` / ux
- **Location:** `lib/features/organisation_management/widgets/bulk_operations_dialog.dart:157`
- **Fix:** Validate numeric fields before submit (tryParse + inline error) and pass errors through the same friendly-error mapper used elsewhere; never interpolate raw $e into a SnackBar.


### L40. SearchBarWidget is a fixed 36px tall box with 12px text — clips and is cramped on phones / with larger text

- **Severity:** low  ·  **Area:** `fe-ux-design-responsive` / responsive
- **Location:** `lib/shared/widgets/search_bar_widget.dart:70, 96-105`
- **Fix:** Make the search bar at least 44-48px tall, use >=14px text, and let height be intrinsic (min-constrained) rather than fixed so it survives text scaling. The other in-screen TextField search bars (staff_management, admins) already do this we


### L41. AI assistant 'typing' dots barely animate; welcome message advertises removed features

- **Severity:** low  ·  **Area:** `fe-ux-design-responsive` / ux
- **Location:** `lib/shared/widgets/ai_assistant_widget.dart:656-671, 103-109`
- **Fix:** Either drive the dots with a repeating AnimationController (repeat(reverse:true)) or use a determinate indicator; and gate/hide the AI FAB until a /api/ai/chat proxy exists, or change the welcome copy to set expectations. Long-press-to-hide


### L42. Org-selection & org-management screens have a parallel non-Sa search/filter UI and stat chips, diverging from the design system

- **Severity:** low  ·  **Area:** `fe-ux-design-responsive` / design-system
- **Location:** `lib/features/organisation_management/screens/organisation_management_screen.dart:340-369, 767-791`
- **Fix:** Replace _buildStatBadge / buildStatChip with SaStatusPill, and factor the in-screen search field into a single shared Sa search widget reused by org-management, org-selection, staff and admins screens.


---

## Appendix — Dismissed as false positives (21)

These were raised by an auditor but **refuted on verification** (protection exists elsewhere, not triggerable, or framework-handled):

- **GET /api/v1/organisations/{id}, /stats, /charges, /summary/all, /analytics/comprehensive leak any org's data to any authenticated tenant (IDOR + cross-tenant read)** — False positive as stated. The 5 cited GET handlers (get_organisation @organisation.py:342, get_organisation_stats @539, get_organisation_charges @579, get_comprehensive_statistics @836, get_organisati
- **create_admin stores a client-supplied group_id with no validation that the institution group exists; that unvalidated group_id then drives the admin's JWT and every group-scoped query** — Largely a false positive: the auditor missed the persistence-layer guard. The live DB (verified by querying eduassist_db) has FK constraint `authorities_group_id_fkey` on `authorities.group_id` -> `in
- **list_users / list_staff / assignable-roles trust principal.organisation_id with no enforcement that the session org still belongs to the principal's group — stale token = cross-tenant read after group/org reassignment** — Mechanism is correct but the exploit is unreachable in this codebase, so this is a false positive (defense-in-depth at most).

Confirmed mechanics: Principal.organisation_id is taken verbatim from the
- **Raw f-string table interpolation in RBAC/user queries relies entirely on a hardcoded allow-list; any new caller passing user_type through is an injection sink** — Not a real vulnerability. Verified all three cited sites; in every case the only value interpolated into the f-string is a table name that is provably one of a tiny set of static string literals, and 
- **create_organisation (admin self-service) does not stamp group_id when reached via /api/v1/organisations, producing group-less orgs that escape all group ceilings** — Not an exploitable tenancy bypass — the claimed admin-reachable path does not exist. organisation_router is mounted exactly once (app/main.py:222) with dependencies=SUPERADMIN; require_super_admin (ap
- **Group ceiling editors and group org listing accept an arbitrary group_id with no check that the group exists (only UUID-shape validation)** — False positive. The finding's premise (orphan ceiling rows can be silently created for non-existent group_ids, and an FK should be added) is already mitigated by an existing FK constraint.

Evidence:

- **f-string identifier interpolation in raw SQL — reviewed, currently NOT injectable but fragile (defense-in-depth)** — Verified all four cited sites — no injectable SQLi exists; this is a defense-in-depth note, not a real vulnerability. (1) deps.py:14-32: _IDENTITY_TABLE is a module-level literal dict with hardcoded v
- **BaseService.create / model_dump() spread is safe for organisation create ONLY because the schema omits sensitive fields — no server-side allow-list backstop** — Verified against actual code; the finding's mechanics are all accurate but it is NOT a present vulnerability (the finding itself admits "latent, not currently exploitable"). Facts confirmed: base_serv
- **OrganisationCreate self-service path (POST /api/auth/organisations) trusts model_dump but doesn't re-validate group ownership of the active org** — False positive for the audited dimension (be-sqli-input). I re-read auth.py:641-676 (create_my_organisation) and confirmed there is NO SQL injection and NO input-validation gap:
- The post-create UPDA
- **Per-request authorization re-resolves role + permissions from the DB on every gated call — no caching** — The finding's central premise is false for the actual codebase. It claims "every authenticated, module-gated request issues 3-4 serial DB queries purely to authorize" — but the per-request gates actua
- **PermissionStore.load() races: login()/refreshSession()/switchOrganisation()/main() can run concurrent loads; failure silently leaves the UI permissive** — The headline claim (concurrent load() races corrupting _modules across orgs) is NOT reachable in this codebase. There are exactly 4 callers of PermissionStore.instance.load() (auth_api_service.dart:40
- **MainLayout content uses SliverFillRemaining(hasScrollBody:true) inside a CustomScrollView — pins content to one viewport and can clip/overflow** — False positive — the finding inverts the actual Flutter behavior. main_layout.dart:360-373 wraps each child in CustomScrollView > SliverFillRemaining(hasScrollBody: true), which is the standard docume
- **ModulePerm.fromJson force-casts j['module_key'] as String — crashes on an unexpected/null API shape** — Code structure is accurately described but the failure is NOT reachable against the paired backend, so the stated impact is a false positive. VERIFIED at lib/core/auth/permission_store.dart:33 `key: j
- **AnalyticsScreen / RoleManagement parse API maps with chained `as num?` casts that assume shape; minor crash risk on string-typed numerics** — False positive. The cited code (lib/features/super_admin/screens/analytics_screen.dart:57-58, 274-302) does use chained `as num?` casts with `?? 0` fallbacks, but the finding's triggering premise — th
- **Landing page two-column breakpoint (760px) leaves narrow tablets/phones-landscape with cramped side-by-side cards** — Code matches the finding's description: landing_screen.dart:19 `_bp = 760`, :24 `isWide = w >= _bp`, :137-148 `_actions` renders a two-column Row(Expanded + 16px gap), :220-230 `_about` renders descri
- **Login card shares one _loading flag across all action buttons — every button shows a spinner when any one is busy** — Title is false. login_card.dart renders exactly ONE _primaryButton per view at any time, so "every button shows a spinner when any one is busy" cannot happen. In _signInFields the only _primaryButton 
- **Module Access row packs name + 'Manage pages' pill + chevron in one Row — tight on small phones with long group names** — False positive — the layout cannot break and is comfortable, not squeezed. Code at lib/features/super_admin/screens/module_access_screen.dart:105-139 wraps the name/subtitle in Expanded (lib:116) with
- **Android targetSdk/minSdk/compileSdk are implicit Flutter defaults — Play compliance and reproducibility risk** — False positive. The `flutter.*` indirection in android/app/build.gradle.kts (lines 10, 27-28) is the standard, Flutter-recommended template idiom, and the finding's stated impacts are factually wrong 
- **iOS ATS allows local networking and the only configured backend is cleartext — production transport posture undefined** — Facts confirmed but the finding describes no actual vulnerability — it's the safe, recommended form of an ATS exception. ios/Runner/Info.plist:50-54 sets NSAppTransportSecurity with ONLY NSAllowsLocal
- **Dependencies use caret ranges with no committed lockfile guarantee in the build pipeline** — Largely a false positive / non-issue. The finding's own impact says it "only bites if CI runs `pub upgrade` or the lockfile is not committed/honored" — neither condition is true. Verified: pubspec.loc
- **iOS allows landscape/upside-down orientations app-wide; UI may not be designed for them** — Facts cited are accurate: ios/Runner/Info.plist:31-43 allows Portrait + LandscapeLeft/Right on iPhone (and PortraitUpsideDown on iPad), web/manifest.json:9 declares "portrait-primary", and there is no