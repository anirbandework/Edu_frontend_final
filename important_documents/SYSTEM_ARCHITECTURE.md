# EduAssist — System Architecture & RBAC (read before building any feature)

This is the **target model** the whole app conforms to. When you build a feature, it must fit this.

---

## 1. The aim (in one paragraph)

There is a **super-admin** (the platform owner). Per **organisation**, the super-admin controls **two
independent sets of pages**: (a) the **Admin pages** the org's admin sees in their own sidebar, and
(b) the **Organisation pages** the admin is allowed to hand out to roles. An **admin can own many
organisations** (schools / colleges / coachings) and switches the active one. Inside an organisation
the admin **creates roles** (which can differ per org — "Teacher" in a school, "Professor" in a
college), **grants pages** to each role (only from the org's allowed set), and those granted pages
**appear in that role's users' sidebar**. Nothing about roles is hardcoded — they're admin-defined per org.

---

## 2. There are exactly THREE user types

| Type | Who | Identity table | How they're created |
|---|---|---|---|
| `super_admin` | Platform owner | `super_admins` | Seeded (config) |
| `school_authority` (**admin**) | Owns organisations | `school_authorities` | Super-admin creates them (password-less) |
| `staff` | **Every** non-admin user (Teacher, Professor, Student, Parent, Office, …) | `members` | Admin creates them with an assigned **role** (password-less) |

> **Onboarding is password-less.** No creator ever sets a password. `POST /api/staff` (admin → staff/student)
> and `POST /api/auth/admins` (super-admin → admin) create the user with `status='invited'`, no password, and
> issue an invitation tied to the user's phone. The user then **sets their own password at first login**:
> the login screen's "First time? Set your password" → enters their phone → OTP → password (token-less; the
> server finds the pending invite by phone). An invite *link* (`/signup?token=…`) also works. Until they do,
> login rejects them (no password). Endpoints: `/api/auth/signup/request-otp` + `/signup/verify` (token optional).

> **There is NO `teacher` or `student` role.** A "Teacher" is just a `staff` user whose admin-defined
> role is named "Teacher". Login resolves only these three types
> ([`login_service._IDENTITY_TABLES`](../../../edu_backend/app/auth_rbac/services/login_service.py)).
>
> *(Teardown DONE ✅ — the `teachers`/`students` tables, the `teacher_management` module, the legacy
> `Student` model, the orphaned teacher/student FE portal screens, and the `ROLE_TEACHER`/`ROLE_STUDENT`
> constants are all deleted. `student_management`'s router/service were KEPT — rewritten to back `members`
> (that's the admin Students page). Nothing in the codebase references the legacy tables/models any more.)*

---

## 3. Organisations & multi-org ownership

- An **organisation = a tenant** (`tenants` table). A school, college, or coaching is one tenant.
- An admin **owns** one or more tenants (`tenants.owner_authority_id`).
- The admin's **active organisation** is encoded in their JWT (`tenant_id`). Switching schools
  (`POST /api/auth/switch-school/{tenantId}`) mints a **new JWT** scoped to that org **and reloads
  permissions** (`SuperAdminService.switchSchool` → `PermissionStore.load()`), because every ceiling
  and role below is **per-tenant**.

---

## 4. The TWO ceilings per organisation (super-admin controls)

Both live on **`tenant_module_permissions`** (one row per tenant × page):

| Ceiling | Column(s) | Controls | Super-admin UI |
|---|---|---|---|
| **Admin pages** | `admin_enabled` | Which pages the **admin** sees in their own sidebar | Module Access → org → **"Admin pages"** tab |
| **Organisation pages** | `authority_enabled`/`teacher_enabled`/`student_enabled` | Which pages the admin may **distribute to roles** ("what they paid for") | Module Access → org → **"Organisation pages"** tab |

- Default = **ON** (a missing row means granted), so a new org starts permissive until the super-admin
  revokes. `required` pages (Profile) are always on.
- Endpoints: `GET/PUT/POST /api/access/org/{tenant}/admin-page(s)` and `.../page(s)`
  ([`access/router.py`](../../../edu_backend/app/auth_rbac/access/router.py), `require_super_admin`).

---

## 5. Roles & page grants (admin controls, per organisation)

- **Role** = `rbac_roles` row, scoped to a tenant (`tenant_id`), `user_type='staff'`, with a free-text
  `role_name` ("Teacher", "Professor", "Coach"…). The SAME admin makes *different* roles in *different*
  orgs — they don't share.
- **Page grant** = `role_module_permissions` (role → module_key, allow-list). A role can only be granted
  pages that are in the org's **Organisation-pages** ceiling — the UI shows out-of-ceiling pages as
  **"Premium / Not in your plan"** (the backend returns a `locked` flag from
  `GET /api/access/grantable-pages`), and `set_role_modules` drops anything outside the ceiling.
- **Delegation** = `role_creatable_roles` — a role may be allowed to create users into specific other
  roles (so a "Principal" role can add staff without full admin).
- **Assignment** = `staff_users.rbac_role_id`. The admin creates a user and assigns a role via
  **Staff & Users** (`POST /api/staff`, delegation-gated).
- Admin UI: **Roles & Access** (`/admin/roles`) + **Staff & Users** (`/admin/staff`).

---

## 6. How permissions resolve → the sidebar

```
login / school-switch
   └─ GET /api/access/my-permissions   (server computes the EFFECTIVE page set)
        ├─ super_admin       → full catalog
        ├─ school_authority  → admin-audience pages ∩ admin_enabled ceiling   (get_admin_permissions)
        └─ staff             → role's granted pages ∩ org ceiling + required  (get_staff_permissions, default-DENY)
   └─ PermissionStore (Flutter cache)  →  navigation_sidebar renders the menu
```

- **Staff sidebar = exactly their granted pages** (built live from `PermissionStore.modules`; Home +
  Profile always present).
- **Admin sidebar = the admin pages the super-admin left on.**
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
| `premium` | Defaults OFF at tenant level until the super-admin enables (currently unused) |
| `tabs` | Sub-sections (tab-level ceilings exist too) |

---

## 8. Backend enforcement (gate every feature endpoint)

Pages are advisory on the client; **the API must enforce**. Use the dependencies in
[`access/deps.py`](../../../edu_backend/app/auth_rbac/access/deps.py):

| Dependency | Passes for |
|---|---|
| `require_module_access('key')` | the caller's role ∩ tenant ceiling grants `key` (super-admin bypass) |
| `require_authority_or_module('key')` | super-admin; **admin** (clamped by their `admin_enabled` ceiling); a **staff** role granted `key`. *(Not teacher/student.)* |
| `require_staff_or_module('key')` | the above **plus** teacher (legacy) |
| `require_super_admin` / `require_authority` | role gates (admin clamp applies via the `_or_module` variants) |

Admins are now clamped by their **Admin-pages** ceiling on `*_or_module` routes
(`tenant_admin_has_page` → `authority_admin_allowed`). Default-ON, so only an explicit revoke 403s.

---

## 9. RECIPE — adding a new feature/page so it fits the model

1. **Add a route** for the screen in [`app_router.dart`](../lib/core/utils/app_router.dart). Admin-usable pages live under the `school_authority` shell; everything a `staff` role can reach must be reachable for staff too.
2. **Add the page to the catalog** (`catalog.py` `MODULES`): pick a stable `module_key`, the `path`, `audience` (`[AUTHORITY]` if it's an admin tool; include it broadly if any role may use it), `section`, and `staff_grantable=True` unless it's truly admin-only.
3. **Gate the endpoints**: every write/route for that feature uses `require_authority_or_module('your_key')` (admin + staff-with-page) or `require_staff_or_module('your_key')`. Never leave a feature endpoint on a bare role check.
4. **Build the screen** with the design system ([UI_DESIGN_SYSTEM.md](UI_DESIGN_SYSTEM.md)) — no `Scaffold`, green+white, etc.
5. **Sidebar icon**: add `module_key → IconData` to `_staffNavIcons` in `navigation_sidebar.dart` so the staff tile has an icon.
6. That's it — the page now flows through both ceilings + roles automatically. The super-admin can include/exclude it per org; the admin can grant it to roles; it appears in those users' sidebars.

> **Decouple from `teachers.id`/`students.id`.** New feature tables must reference the **actor by a
> generic id** (`staff_users.id` / a polymorphic creator), NOT the legacy teacher/student tables — so a
> dynamic role can use the feature. This is the main work when reworking an existing feature.

---

## 10. Current status (2026-06-28)

**Done:** super-admin; the two per-org ceilings (Admin pages / Organisation pages); multi-org +
active-school switch (with permission reload); per-org dynamic roles + page grants + delegation +
assignment; staff sidebar = granted pages; **3 user types only** (login/RBAC no longer know
teacher/student) + the dead teacher/student FE removed; per-route admin-page enforcement; fresh DB.
**Identity unified** → one table `members` (every non-admin user). **Classes + Enrolment** reworked onto
generic `member_id` (enrolment = `(member_id, class_id)`; teaching = a member in the class's assigned list).

**Pending (Phase 2 continues, per MODULE_AND_FEATURE_PLAN.md build order):**
- **Attendance (#4) — DONE ✅:** its model was already polymorphic (no FK to teachers/students); the marker
  is now `STAFF` (server-derived from the JWT), writes gated `require_authority_or_module('attendance')`.
- **Exams/Marks (#5) — DONE ✅:** `student_exam_marks` now keys on `member_id` (FK `members.id`); marks JOIN
  `members`; writes gated `require_authority_or_module('exams')`.
- **Assessments/Quizzes (#6) — DONE ✅:** the 6 grading/quiz tables (`assessments`, `assessment_submissions`,
  `student_grades`, `report_cards`, `quizzes`, `quiz_attempts`) now FK `members.id` (column names kept; they
  carry a `members.id`); services + raw-SQL JOIN `members`. (Gating still `require_staff` — page-grant retrofit pending.)
- **Chat + Timetable (#7) — DONE ✅:** `chat_rooms` (teacher_id+student_id) and `teacher_timetables.teacher_id`
  now FK `members.id`. The **FK/ORM/relationship layer is now fully off `teachers`/`students`.**
- **#8 — full decoupling — DONE ✅:** attendance (raw SQL incl. the broken roster join; grade/section→`profile`),
  notification_management (~20 queries; teacher `personal_info` JSON→flat member cols; class/grade via enrollments),
  tenant dashboard counts, auth_service user-profile (→ one `Member` branch; fixed staff-profile resolution),
  invitation_service, and `Tenant` decoupled from `Student`/`Teacher`. **App-wide sweep: nothing outside the legacy
  modules references `teachers`/`students`.** Teardown is now UNBLOCKED.
- **Teardown — DONE ✅:** dropped `teachers`/`students` tables; deleted `teacher_management` (+ unmounted) and the
  legacy `Student` model; deleted the orphaned teacher/student FE portal screens + `student_portal_service`; removed
  `ROLE_TEACHER`/`ROLE_STUDENT` (the Students-page invite now uses `ROLE_STAFF`); cleaned the migrations/seeds.
  Verified: app-wide residual sweeps empty, DB recreates clean, multi-subsystem live smoke green.
- **Enforcement retrofit — DONE ✅:** all 35 assessment write/authoring gates converted `require_staff` →
  `require_authority_or_module('quizzes'/'assignments'/'grades')` (quiz_management/ai_quiz_*/cbse_* → `quizzes`;
  assignment_routes/assignment_grading → `assignments`; ai_student_analytics → `grades`). The catalog now marks
  `quizzes`/`assignments`/`grades` **staff-grantable** (they were excluded as teacher/student-coupled; that's gone
  post-#6), so a dynamic "Teacher" role can be granted them — staff without the grant now 403.
- **Member self-onboarding — DONE ✅:** `signup_service` now processes `ROLE_STAFF` invites (`_MODEL_BY_ROLE[ROLE_STAFF]=Member`),
  so the Students-page set-password link activates the pre-created member (sets phone+password, status=active).
- **Students = members — DONE ✅:** the admin **Students** page now backs the `members` table (a student is a
  `Member` with `profile.category='student'` + the tenant's default `staff` role; student extras live in
  `members.profile` JSON; HRID = `member.staff_id`; grade/section authoritative via the enrolment class). API
  paths unchanged; writes gated `require_authority_or_module('students')`. New students are immediately
  enrollable. The legacy `students` table/model is now unused by this page (still FK'd by exams/assessments/chat
  until #5–#7).
- **Staff-scoped routing polish:** a staff user's granted page currently opens inside the admin shell
  (sidebar is correctly overridden to staff, so it works) — a dedicated staff route/shell would be cleaner.

---

## 11. Key files

| Area | Backend (`edu_backend/app/`) | Frontend (`lib/`) |
|---|---|---|
| Catalog | `auth_rbac/access/catalog.py` | — |
| RBAC model/logic | `auth_rbac/access/{models,service,router,deps}.py` | `core/auth/permission_store.dart` |
| Login / identity | `auth_rbac/services/login_service.py`, `security/principal.py` | `core/auth/auth_session.dart` |
| Super-admin ceilings | `auth_rbac/access/router.py` | `services/super_admin_service.dart`, `features/super_admin/…/org_pages_dialog.dart`, `…/module_access_screen.dart` |
| Roles / staff | `auth_rbac/access/service.py`, `staff_management/` | `services/{roles_service,staff_service}.dart`, `features/admin/screens/{role_management,staff_management}_screen.dart` |
| Sidebar / routing | — | `shared/widgets/navigation_sidebar.dart`, `shared/widgets/main_layout.dart`, `core/utils/app_router.dart` |
| Tenants (orgs) | `tenant_management/`, `school_authority_management/` (my-schools, switch-school) | `services/super_admin_service.dart` (getTenants/getMySchools/switchSchool) |

See also: [PAGES_BY_ROLE.md](PAGES_BY_ROLE.md) (page lists), [UI_DESIGN_SYSTEM.md](UI_DESIGN_SYSTEM.md) (UI rules).
