# EduAssist — Pages by Role

> **STRIPPED-DOWN STATE (2026-06-29).** The app was reduced to its auth/RBAC core — every feature
> module was deleted (FE + BE) and will be rebuilt later (see
> [MODULE_AND_FEATURE_PLAN.md](MODULE_AND_FEATURE_PLAN.md)). This file lists the pages that exist
> **right now**. The pre-strip-down page sets (Classes, Attendance, Exams, Quizzes, Chat, Timetable,
> Enrolment, Notifications, Students, Teacher/Student portals) are **gone** — they'll reappear here as
> their modules are re-added via the §9 recipe in [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md).

Two sources of truth:
- **Sidebar menus** — hardcoded per role in [`lib/shared/widgets/navigation_sidebar.dart`](../lib/shared/widgets/navigation_sidebar.dart) (`_getNavigationItems`).
- **RBAC catalog** — the grantable pages for the dynamic permission system in
  `app/auth_rbac/access/catalog.py` (`MODULES`). This drives the **group ceiling** (super-admin → institution group) and **roles** (admin → staff).

> **Profile** is universal & `required` — every role always has it; it can never be revoked.

---

## 1. Super Admin  (6 pages)

Hardcoded surface, **not** RBAC-gated (super-admin bypasses all permission checks). Sidebar role key: `super_admin` (aliases `global_admin` / `organisation_manager`). First page is now **Institution Groups** (the rest unchanged).

| Page | Route | Purpose |
|---|---|---|
| Institution Groups | `/organisation-management` | Create **institution groups**; **activate/deactivate a group** (blocks everyone in it); tap one to view its organisations and **activate/deactivate each org** (blocks that org's staff) |
| Admins | `/admin/admins` | Create admins **into a group** (group dropdown required); shown as a **group → admins hierarchy** (each group expands to its admins); per admin: edit / **activate-deactivate** / reset password (**no delete — deactivate-only**) |
| Module Access | `/admin/module-access` | Set each **group's** two page ceilings — **Admin pages** (`admin_enabled`) + **Group pages** (`role_enabled`) |
| Analytics | `/admin/platform-analytics` | Platform-wide stats |
| Feedback | `/admin/feedback` | Feedback inbox |
| Profile | `/super-admin/profile` | Account / password |

> **Deactivation (admin / org / group)** is enforced at **login _and_ refresh** with a specific 403
> message ("This organisation has been deactivated.", "Your institution group has been deactivated."),
> and deactivated orgs show greyed-out in the login picker. See
> [SYSTEM_ARCHITECTURE.md §3 "Activation / deactivation"](SYSTEM_ARCHITECTURE.md).

---

## 2. Admin  (Authority — 3 pages + onboarding)

Sidebar role key: `admin` / `authority`. After login the admin lands on **Staff & Users**
(an organisation-less admin is sent to onboarding first to create their first organisation).

| Page | Route | RBAC module_key |
|---|---|---|
| Roles & Access | `/admin/roles` | `rbac_management` *(admin-only)* |
| Staff & Users | `/admin/staff` | `staff` |
| Profile | `/admin/profile` | `profile` *(required)* |

> Standalone (authed, not in the sidebar): **Onboarding** (`/admin/onboarding`) — an organisation-less admin
> creates their first organisation here before entering the app.

---

## 3. Staff  (every non-admin user — Profile only, for now)

There is **no `teacher` or `student` role** — a "Teacher" / "Student" / "Professor" is just a `staff`
user whose admin-defined role is named that. A staff user's sidebar is built live from the pages their
role was granted. **Post strip-down the only grantable page is Profile**, so every staff user currently
sees exactly:

| Page | Route | RBAC module_key |
|---|---|---|
| Profile | `/staff/profile` | `profile` *(required)* |

As feature pages are re-added to the catalog and granted to a role, they will appear here automatically:
```
every granted module (enabled, has a route)  +  Profile (always)
```

---

## 4. The RBAC catalog (the grantable pages)

The catalog in [`catalog.py`](../../../edu_backend/app/auth_rbac/access/catalog.py) (`MODULES`) — the
canonical list the **group ceiling** and **roles** draw from. **Currently 3 pages.** `audience` = which
canonical buckets the page belongs to (A = Authority/Admin, T = Teacher, S = Student).

| module_key | Name | Route | Audience | Section | Flags |
|---|---|---|---|---|---|
| `profile` | Profile | `/profile` | A T S | Core | **required** |
| `rbac_management` | Roles & Access | `/admin/roles` | A | Administration | **admin-only** |
| `staff` | Staff & Users | `/admin/staff` | A | Administration | |

> Super-admin's 6 pages (Institution Groups, Admins, Module Access, Analytics, Feedback, Profile) are **not** in
> this catalog — they're a separate hardcoded surface.

---

## How it resolves (quick reference)

| Role | Effective pages |
|---|---|
| **Super Admin** | The 6 hardcoded pages — bypasses all permission checks |
| **Admin** | Roles & Access, Staff & Users, Profile (admin pages ∩ the **group's** `admin_enabled` ceiling; Profile always) |
| **Staff** | Only pages their role explicitly grants ∩ the **group's** `role_enabled` pool, + required (**default-deny allow-list**) — currently just Profile |

- **Tier 0 — Super-admin → GROUP ceiling:** `group_module_permissions` (`role_enabled` = Group-pages pool, `admin_enabled` = Admin pages) via Module Access (`/api/access/group/{group_id}/pages` + `/admin-pages`). A caller's org resolves to its group (`group_id_for_org`).
- **Tier 1 — Admin → Roles:** `role_module_permissions` via Roles & Access (`/api/access/roles`), clamped to the group's `role_enabled` pool (locked pages show as "Premium / Not in your plan").
- **Assignment — Admin → User:** `rbac_role_id` on the user, via Staff & Users (`/api/staff`).
- **Login → sidebar:** `GET /api/access/my-permissions` → `PermissionStore` → `navigation_sidebar`.
