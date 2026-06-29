# EduAssist — System Architecture & RBAC (read before building any feature)

This is the **target model** the whole app conforms to. When you build a feature, it must fit this.

---

## 1. The aim (in one paragraph)

There is a **super-admin** (the platform owner). The super-admin creates an **Institution Group**
(the top-level tenant) and creates **admins into that group**. Per **institution group**, the
super-admin controls **two independent sets of pages**: (a) the **Admin pages** every admin of the
group sees in their own sidebar, and (b) the **Group pages** the admins are allowed to hand out to
roles. An **admin belongs to one group** and **manages all of the group's organisations** (schools /
colleges / coachings / private tutors / any educational org) — **every admin of a group sees the same
shared set of organisations** and switches the **active one** (each org's data stays isolated). Inside
an organisation the admin **creates roles** (which can differ per org — "Teacher" in a school,
"Professor" in a college), **grants pages** to each role (only from the group's allowed set), and those
granted pages **appear in that role's users' sidebar**. Nothing about roles is hardcoded — they're
admin-defined per org.

```
super_admin → Institution Group → Admins (many, share the group)
                                 → Organisations (admins create them; belong to the GROUP;
                                   visible to ALL the group's admins; each org's data isolated)
                                     → Staff (scoped to ONE org)
```

---

## 2. There are exactly THREE user types

| Type | Who | Identity table | How they're created |
|---|---|---|---|
| `super_admin` | Platform owner | `super_admins` | Seeded (config) |
| `authority` (**admin**) | Belongs to one group; manages the group's organisations | `authorities` (`group_id` FK) | Super-admin creates them **into an institution group** (password-less) |
| `staff` | **Every** non-admin user (Teacher, Professor, Student, Parent, Office, …) | `members` | Admin creates them with an assigned **role** (password-less) |

> **Onboarding is password-less.** No creator ever sets a password. `POST /api/staff` (admin → staff)
> and `POST /api/auth/admins` (super-admin → admin) create the user with `status='invited'` and no password.
> The user then **sets their own password at first login** — the login card's **"First time here? Set your
> password"** (inline in the same card, like "Forgot password?") → phone → OTP → password → auto-login.
> The server finds the pending account **by phone** (`signup_service.find_pending_account_by_phone`):
> there are **no invite tokens and no invite links** — the whole invitation system was removed. Until a
> password is set, login rejects them. Endpoints: `/api/auth/signup/request-otp` + `/signup/verify` (phone-based).

> **Deletion is disabled — only deactivate.** Hard-deleting a user breaks references, so the user DELETE
> endpoints are gone. `PATCH /api/staff/{id}/status` (and admin equivalents) flips `is_active` instead.

> **There is NO `teacher` or `student` role.** A "Teacher" is just a `staff` user whose admin-defined
> role is named "Teacher". Login resolves only these three types
> ([`login_service._IDENTITY_TABLES`](../../../edu_backend/app/auth_rbac/services/login_service.py)).
>
> *(The `teachers`/`students` tables, the legacy `Student` model, and the `ROLE_TEACHER`/`ROLE_STUDENT`
> constants are all gone. In the **strip-down (§10)** the `student_management` module was deleted too,
> along with every other feature module — a student is created as a `staff` member from **Staff & Users**.
> Nothing in the codebase references the legacy tables/models any more.)*

---

## 3. Institution Groups, organisations & the active org

- An **institution group** (`institution_groups` table: `name`, `code` unique, `is_active`) is the
  **top-level tenant**. The super-admin creates it (`POST/GET /api/auth/groups`) and creates admins into
  it. The group is where **both page ceilings live** (§4) — they apply to every organisation in it.
- An **organisation** (`organisations` table) is a school, college, coaching, etc. The product is
  **institution-agnostic**: the fields are generic — `name`, `code`, `org_type`
  (∈ School / College / Coaching / University / Institute / Tutor / Other — "Tutor" covers private
  tutors; default `School`), `head_name` (was school_name / school_code / school_type / principal_name;
  renamed FE+API+DB on 2026-06-29).
  *(The admin's role/identity layer is the `authority` role + `authorities` table — "Admin" = an
  `authority`. Renamed from `school_authority`/`school_authorities` on 2026-06-29 so no "school"
  remains in table/role/file/folder names.)*
- **Organisations belong to a group** (`organisations.group_id`), not to a single admin. **Every admin
  of the group sees the same shared list of organisations**; the admin who created one is recorded in
  `organisations.owner_authority_id` for **audit only** (management is group-scoped, not per-creator).
- The admin's **active organisation** is encoded in their JWT (`organisation_id`); their **group** is
  too (`group_id`). `GET /api/auth/my-organisations` returns **the group's** orgs
  (`WHERE group_id = principal.group_id`). Switching (`POST /api/auth/switch-organisation/{id}`,
  validated to be in the admin's group) mints a **new JWT** scoped to that org (same `group_id`) **and
  reloads permissions** (`SuperAdminService.switchOrganisation` → `PermissionStore.load()`), because
  every **role** below is **per-organisation**. Admins self-create orgs with
  `POST /api/auth/organisations` (stamps `owner_authority_id` + `group_id`).
- **JWT carries `group_id`** on access *and* refresh tokens; `Principal.group_id` / `Identity.group_id`
  come from `authority.group_id`. *(Staff tokens carry `group_id=None` today — staff are scoped by their
  one organisation, which resolves to a group server-side where needed.)*

### Activation / deactivation — who can log in

Nothing is ever hard-deleted; access is controlled by **deactivation** at three nested levels, all
toggled by the super-admin (default = active). Each entity has an `is_active` / `status` flag and a
`PATCH` endpoint:

| Level | Endpoint (super-admin) | Effect when deactivated |
|---|---|---|
| **Admin** | `PATCH /api/auth/admins/{id}/status` `{is_active}` (sets `authorities.status`) | That admin can't log in. *(The `DELETE /admins/{id}` route was removed — **deactivate-only**.)* |
| **Organisation** | `PATCH /api/auth/organisations/{id}/status` `{is_active}` | That org's **staff** can't log in. **Admins are group-level, so they're NOT blocked** — they can still switch to the org to manage/reactivate it. |
| **Institution group** | `PATCH /api/auth/groups/{id}/status` `{is_active}` | **Nobody** in the group can log in — its admins *and* all staff in *every* one of its organisations. |

**Enforcement** lives in [`login_service.assert_active`](../../../edu_backend/app/auth_rbac/services/login_service.py)
(raising `AccountInactiveError`), called on **login** *and* **refresh** (so live sessions die on the next
refresh; the super-admin is exempt). It's evaluated **only after the password verifies**, so a deactivated
state never reveals which phones/orgs exist. The route returns **403** with a specific message:

- account `status=='inactive'` → *"Your account has been deactivated…"* (`'invited'` is **not** blocked — it
  falls through to first-login). In lists this `'invited'` state shows as a neutral **"Pending"** pill (never
  "Inactive"); only a deactivated row shows "Inactive". The row action reads **"Deactivate"** for both Active
  and Pending, and **"Activate"** only for a deactivated row.
- org off (staff only; org→group resolved) → *"This organisation has been deactivated…"*
- group off (admin via token `group_id`; staff inherit via their org's group) → *"Your institution group has been deactivated…"*

The public login picker (`GET /api/auth/organisations`) **includes** deactivated orgs — and orgs whose
**group** is off — flagged `is_active=false`, so the org-selection screen greys them out with an "Inactive"
badge and shows *"this organisation is currently inactive — contact your administrator"* on tap instead of
signing in.

---

## 4. The TWO ceilings per institution GROUP (super-admin controls)

Both live on **`group_module_permissions`** (one row per **group** × page; unique on
`(group_id, module_key)`). They apply to **every organisation in the group**:

| Ceiling | Column | Controls | Super-admin UI |
|---|---|---|---|
| **Admin pages** | `admin_enabled` | Which pages every **admin** of the group sees in their own sidebar | Module Access → group → **"Admin pages"** tab |
| **Group pages** | `role_enabled` | Which pages the admins may **distribute to roles** in any org of the group ("what they paid for") | Module Access → group → **"Group pages"** tab |

- Default = **ON** (a missing row means granted), so a new group starts permissive until the super-admin
  revokes. `required` pages (Profile) are always on. *(The legacy per-org audience columns
  `authority_enabled`/`teacher_enabled`/`student_enabled` and the `organisation_module_permissions` /
  `organisation_tab_permissions` tables are **gone** — ceilings are group-scoped now.)*
- A request scoped to an **org** resolves to its **group** via `group_id_for_org(db, organisation_id)`;
  `organisation_has_page` reads the group's `role_enabled`, `organisation_admin_has_page` reads
  `admin_enabled`.
- Endpoints (all `require_super_admin`): `GET/PUT/POST /api/access/group/{group_id}/admin-page(s)` and
  `.../page(s)` ([`access/router.py`](../../../edu_backend/app/auth_rbac/access/router.py)). Editor
  functions (`set_group_page`, `set_admin_page`, `set_all_group_pages`, `set_all_admin_pages`) take a
  **`group_id`**.

---

## 5. Roles & page grants (admin controls, per organisation)

- **Role** = `rbac_roles` row, scoped to an organisation (`organisation_id`), `user_type='staff'`, with a free-text
  `role_name` ("Teacher", "Professor", "Coach"…). The SAME admin makes *different* roles in *different*
  orgs — they don't share.
- **Page grant** = `role_module_permissions` (role → module_key, allow-list). A role can only be granted
  pages that are in the **group's Group-pages** ceiling (`role_enabled`, resolved org→group) — the UI
  shows out-of-ceiling pages as **"Premium / Not in your plan"** (the backend returns a `locked` flag
  from `GET /api/access/grantable-pages`), and `set_role_modules` drops anything outside the ceiling.
- **User management = page grant.** Granting a role the **Staff & Users** page (`staff` module) is what
  lets its holders manage users: they can then add users into **any** role in the organisation and see all
  available roles. There is **no separate per-role delegation step** — `GET /api/access/assignable-roles`
  and the `POST /api/staff` create-gate both key off `has_module_access(..., 'staff')`. A staff creator can
  still only ever assign **`user_type='staff'` roles** (never `authority`/admin). *(The legacy
  `role_creatable_roles` table is retired from this flow.)*
- **Assignment** = `staff_users.rbac_role_id`. The admin (or a staff user holding the Staff page) creates a
  user and assigns a role via **Staff & Users** (`POST /api/staff`).
- Admin UI: **Roles & Access** (`/admin/roles`) + **Staff & Users** (`/admin/staff`).

---

## 6. How permissions resolve → the sidebar

```
login / org-switch
   └─ GET /api/access/my-permissions   (server computes the EFFECTIVE page set)
        ├─ super_admin       → full catalog
        ├─ authority (admin) → admin pages ∩ the GROUP's admin_enabled ceiling   (get_admin_permissions; org→group resolved)
        └─ staff             → role's granted pages ∩ the GROUP's role_enabled pool + required  (default-DENY)
   └─ PermissionStore (Flutter cache)  →  navigation_sidebar renders the menu
```

- **Staff sidebar = exactly their granted pages** (built live from `PermissionStore.modules`; Profile
  always present). Post strip-down that's just Profile until feature pages are granted.
- **Admin sidebar = the admin pages the super-admin left on for the group** (now Roles & Access,
  Staff & Users, Profile).
- Client gating is permissive-on-load-failure for UX, but the **server enforces** (see §8), so it's safe.

---

## 7. The page CATALOG — the single source of truth for "what pages exist"

[`edu_backend/app/auth_rbac/access/catalog.py`](../../../edu_backend/app/auth_rbac/access/catalog.py) → `MODULES`. Each entry (`_m(...)`):

| Field | Meaning |
|---|---|
| `module_key` | Stable id, persisted in permission rows. **Never rename.** |
| `module_name`, `icon`, `path` | Display + the **registered route** the sidebar tile opens |
| `audience` | `[AUTHORITY, TEACHER, STUDENT]` — which canonical buckets the page belongs to. For the new model, `AUTHORITY` = "is an admin page". |
| `section` | `Core / Administration / Academics / Communication` (page-picker grouping) |
| `required` | Always-on, never toggleable (e.g. `profile`) |
| `admin_only` | Admin's own tool (e.g. `rbac_management`) — never distributable to roles |
| `staff_grantable` | May be granted to a dynamic staff role |
| `premium` | Defaults OFF at organisation level until the super-admin enables (currently unused) |
| `tabs` | Sub-sections (tab-level ceilings exist too) |

> **Post strip-down the catalog holds exactly 3 pages:** `profile` (required, every user),
> `rbac_management` ("Roles & Access", admin-only), `staff` ("Staff & Users", admin). Feature pages
> are re-added here as their modules are rebuilt (§9 recipe).

---

## 8. Backend enforcement (gate every feature endpoint)

Pages are advisory on the client; **the API must enforce**. Use the dependencies in
[`access/deps.py`](../../../edu_backend/app/auth_rbac/access/deps.py):

| Dependency | Passes for |
|---|---|
| `require_module_access('key')` | the caller's role ∩ organisation ceiling grants `key` (super-admin bypass) |
| `require_authority_or_module('key')` | super-admin; **admin** (clamped by their `admin_enabled` ceiling); a **staff** role granted `key`. *(Not teacher/student.)* |
| `require_staff_or_module('key')` | the above **plus** teacher (legacy) |
| `require_super_admin` / `require_authority` | role gates (admin clamp applies via the `_or_module` variants) |

Admins are clamped by their group's **Admin-pages** ceiling on `*_or_module` routes
(`organisation_admin_has_page` resolves the caller's org → its group → `admin_enabled` →
`authority_admin_allowed`). Default-ON, so only an explicit revoke 403s.

---

## 9. RECIPE — adding a new feature/page so it fits the model

1. **Add a route** for the screen in [`app_router.dart`](../lib/core/utils/app_router.dart). Admin-usable pages live under the `authority` shell; everything a `staff` role can reach must be reachable for staff too.
2. **Add the page to the catalog** (`catalog.py` `MODULES`): pick a stable `module_key`, the `path`, `audience` (`[AUTHORITY]` if it's an admin tool; include it broadly if any role may use it), `section`, and `staff_grantable=True` unless it's truly admin-only.
3. **Gate the endpoints**: every write/route for that feature uses `require_authority_or_module('your_key')` (admin + staff-with-page) or `require_staff_or_module('your_key')`. Never leave a feature endpoint on a bare role check.
4. **Build the screen** with the design system ([UI_DESIGN_SYSTEM.md](UI_DESIGN_SYSTEM.md)) — no `Scaffold`, green+white, etc.
5. **Sidebar icon**: add `module_key → IconData` to `_staffNavIcons` in `navigation_sidebar.dart` so the staff tile has an icon.
6. That's it — the page now flows through both ceilings + roles automatically. The super-admin can include/exclude it per org; the admin can grant it to roles; it appears in those users' sidebars.

> **Decouple from `teachers.id`/`students.id`.** New feature tables must reference the **actor by a
> generic id** (`staff_users.id` / a polymorphic creator), NOT the legacy teacher/student tables — so a
> dynamic role can use the feature. This is the main work when reworking an existing feature.

---

## 10. Current status (2026-06-29) — STRIPPED to the auth/RBAC core

The app was deliberately **stripped down to its skeleton** so the auth + org + RBAC foundation is
solid before features are rebuilt. **Every feature module was deleted** (frontend *and* backend) and
will be re-added later via the §9 recipe.

> **Institution Group re-architecture (2026-06-29).** A top-level **Institution Group** layer was added
> above organisations (§1, §3): `super_admin → group → admins (share the group) → organisations
> (group-shared, switchable) → staff`. The **two page ceilings moved from per-org to per-group**
> (`organisation_module_permissions` → **`group_module_permissions`** with `role_enabled` +
> `admin_enabled`), the **JWT now carries `group_id`**, and the access endpoints are
> `/api/access/group/{group_id}/…`. The super-admin's first page is now **Institution Groups**.

> **Deactivation (2026-06-29).** Access is controlled by **deactivation at three nested levels**
> (admin / organisation / institution group) — see **§3 "Activation / deactivation"**. The super-admin
> toggles each via a `PATCH …/status` endpoint; login *and* refresh enforce it (`assert_active` → 403
> with a specific message). Admin **delete was removed** — deactivate-only. The Admins page is now a
> **group → admins hierarchy** (each group expands to its admins).

**What remains (the whole app right now):**
- **Auth:** login, password-less first-login (phone → OTP → password, inline in the login card),
  forgot-password. No invite system.
- **Super-admin — their 6 pages:** **Institution Groups**, Admins, Module Access, Analytics, Feedback, Profile.
- **Admin (authority):** **Roles & Access** (`/admin/roles`), **Staff & Users** (`/admin/staff`),
  **Profile** — plus standalone **onboarding** (create the first organisation). Lands on Staff & Users.
- **Every other user (staff):** **Profile only** (their sidebar grows as pages are re-added and granted).
- **RBAC + org model:** the institution-group layer, the two **per-group** ceilings, group-shared orgs +
  active-org switch (permission reload), per-org dynamic roles + page grants + delegation + assignment,
  server-side enforcement — all intact.

**Catalog = 3 pages** (`profile`, `rbac_management`, `staff`). **3 user types** (`super_admin` /
`authority` / `staff`); a student is just a staff member created from Staff & Users.

**Deleted in the strip-down:**
- **Backend modules:** `attendance_management`, `exam_management`, `assessment_management`,
  `chat_management`, `timetable_management`, `enrollment_management`, `class_management`,
  `notification_management`, `student_management` — folders removed, routers unmounted from `app.main`,
  `Organisation.classes` relationship dropped.
- **Frontend:** the matching feature folders/screens/services/dialogs, the orphaned feature models
  (`attendance_models`, `class_model`, `notification`, `student`, `timetable_models`), the dead route
  constants, and all dead notification UI in `navigation_sidebar`. `ai_service` (the global AI chat stub)
  was **kept** per request.
- **DB rebuilt** with only the required tables: `institution_groups`, `super_admins`, `authorities`
  (`group_id`, nullable `organisation_id`/`email`), `members`, `organisations` (`group_id`,
  `owner_authority_id`), `rbac_roles`, `role_module_permissions`, `role_creatable_roles`,
  `role_tab_permissions`, **`group_module_permissions`** (`role_enabled` + `admin_enabled`),
  **`group_tab_permissions`**, `feedback`, `invitations`. Migrations/seeds pruned of the feature-table
  entries. **Seeded = only the super-admin** (`seed_default_roles` adds one `Administrator` authority
  role per org once orgs exist; no teacher/student roles).

**Verified:** FE `dart analyze lib` → 0 errors; BE `import app.main` + `configure_mappers()` OK;
server up with only `/api/auth`, `/api/staff`, `/api/access`, `/api/v1/{organisations,authorities,feedback}`.

**Next:** rebuild features one at a time per [MODULE_AND_FEATURE_PLAN.md](MODULE_AND_FEATURE_PLAN.md),
each following the §9 recipe (route → catalog entry → gated endpoints → screen → sidebar icon).

---

## 11. Key files

| Area | Backend (`edu_backend/app/`) | Frontend (`lib/`) |
|---|---|---|
| Catalog | `auth_rbac/access/catalog.py` | — |
| RBAC model/logic | `auth_rbac/access/{models,service,router,deps}.py` | `core/auth/permission_store.dart` |
| Login / identity | `auth_rbac/services/login_service.py`, `security/principal.py` | `core/auth/auth_session.dart` |
| Institution Groups | `group_management/models/group.py`, `auth_rbac/routers/auth.py` (groups, admins, my-organisations, switch) | `features/super_admin/screens/institution_groups_screen.dart`, `services/super_admin_service.dart` (createGroup/getGroups/getGroupOrganisations) |
| Super-admin ceilings (per group) | `auth_rbac/access/{router,service}.py` | `services/super_admin_service.dart`, `features/super_admin/widgets/group_pages_dialog.dart`, `…/screens/module_access_screen.dart` |
| Roles / staff | `auth_rbac/access/service.py`, `staff_management/` | `services/{roles_service,staff_service}.dart`, `features/admin/screens/{role_management,staff_management}_screen.dart` |
| Sidebar / routing | — | `shared/widgets/navigation_sidebar.dart`, `shared/widgets/main_layout.dart`, `core/utils/app_router.dart` |
| Organisations (group-shared) | `organisation_management/`, `authority_management/` (my-organisations, switch-organisation) | `services/super_admin_service.dart` (getMyOrganisations/switchOrganisation) |

See also: [PAGES_BY_ROLE.md](PAGES_BY_ROLE.md) (page lists), [UI_DESIGN_SYSTEM.md](UI_DESIGN_SYSTEM.md) (UI rules).
