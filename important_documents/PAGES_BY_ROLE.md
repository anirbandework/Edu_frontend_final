# EduAssist — Pages by Role

What each role can see. Two sources of truth:
- **Sidebar menus** — hardcoded per role in [`lib/shared/widgets/navigation_sidebar.dart`](../lib/shared/widgets/navigation_sidebar.dart) (`_getNavigationItems`).
- **RBAC catalog** — the grantable pages for the dynamic permission system in the backend
  `app/auth_rbac/access/catalog.py` (`MODULES`). This drives the **org ceiling** (super-admin → school) and **roles** (admin → staff).

> **Profile** is universal & `required` — every role always has it; it can never be revoked.

---

## 1. Super Admin  (6 pages)

Hardcoded surface, **not** RBAC-gated (super-admin bypasses all permission checks). Sidebar role key: `global_admin` / `tenant_manager`.

| Page | Route | Purpose |
|---|---|---|
| Tenants | `/tenant-management` | List/manage all schools (organisations) |
| Admins | super-admin Admins route | Create admins, grant them module access |
| Module Access | super-admin Module Access route | Set each org's **page ceiling** ("what they paid for") |
| Analytics | super-admin Analytics route | Platform-wide stats |
| Feedback | super-admin Feedback route | Feedback inbox |
| Profile | super-admin Profile route | Account / password |

> Legacy, routed but **not** in the sidebar: **Tenant Access** (`/admin/tenant-access`) — the older per-audience module/tab ceiling editor (superseded by Module Access).

---

## 2. Admin  (School Authority — 12 pages)

Sidebar role key: `admin` / `school_authority`. **Currently the admin sidebar is hardcoded to show ALL of these** (the org ceiling is not applied to the admin's own menu).

| Page | Route | RBAC module_key |
|---|---|---|
| Dashboard | admin Dashboard route | `dashboard` |
| Notifications | admin Notifications route | `notifications` |
| Send Message | admin Send-Notification route | `send_notification` |
| Classes | `/school_authority/classes` | `classes` |
| Students | `/school_authority/students` | `students` |
| Exams | admin Exams route | `exams` |
| Enrolment | admin Enrollment route | `enrollment` |
| Roles & Access | `/admin/roles` | `rbac_management` *(admin-only)* |
| Staff & Users | admin Staff route | `staff` |
| Attendance | admin Attendance route | `attendance` |
| Timetable | `/school_authority/timetable` | `timetable` |
| Profile | admin Profile route | `profile` *(required)* |

---

## 3. Teacher  (13 pages)

| Page | Route | RBAC module_key |
|---|---|---|
| Dashboard | teacher Dashboard route | `dashboard` |
| Notifications | teacher Notifications route | `notifications` |
| Send Message | teacher Send-Notification route | `send_notification` |
| Classes | teacher Classes route | `classes` / `my_classes` |
| My Schedule | teacher Schedule route | `timetable` |
| Students | teacher Students route | — (teacher view) |
| Quizzes | teacher Quizzes route | `quizzes` |
| Assignments | teacher Assignments route | `assignments` |
| Messages | teacher Chat route | `chat` |
| Attendance | teacher Attendance route | `attendance` |
| Grades | teacher Grades route | `grades` |
| Exams | teacher Exams route | `exams` |
| Profile | teacher Profile route | `profile` *(required)* |

---

## 4. Student  (8 pages)

| Page | Route | RBAC module_key |
|---|---|---|
| Dashboard | student Dashboard route | `dashboard` |
| Notifications | student Notifications route | `notifications` |
| Assignments | student Assignments route | `assignments` |
| Grades | student Grades route | `grades` |
| Attendance | student Attendance route | `attendance` |
| Timetable | student Timetable route | `timetable` |
| Messages | student Chat route | `chat` |
| Profile | student Profile route | `profile` *(required)* |

> Sub-screens reachable from these (not sidebar items): **Take Quiz**, **Report Card**.

---

## 5. Staff  (Dynamic role — menu = its granted pages)

A "staff" user has **no fixed menu**. The sidebar is built live from the pages their admin-defined role was granted:

```
Home (always)  +  every granted module (enabled, has a route)  +  Profile (always)
```

A staff role may be granted any **`staff_grantable`** page from the catalog below — i.e. **all modules except** the admin-only and teacher/student-coupled ones:

- ❌ Not grantable to staff: `rbac_management` (admin-only) · `my_classes`, `quizzes`, `assignments`, `grades`, `chat` (tied to a teacher/student identity).
- ✅ Grantable to staff: `notifications`, `students`, `classes`, `timetable`, `attendance`, `enrollment`, `send_notification`, `exams`, `staff` (+ `dashboard` → shown as **Home**, `profile` → always on).

---

## 6. Master RBAC catalog (the grantable pages)

The 17 modules in `catalog.py` — the canonical list the **org ceiling** and **roles** draw from. `audience` = which canonical roles the page belongs to (A = Authority/Admin, T = Teacher, S = Student).

| module_key | Name | Route | Audience | Section | Flags |
|---|---|---|---|---|---|
| `dashboard` | Dashboard | `/dashboard` | A T S | Core | |
| `profile` | Profile | `/profile` | A T S | Core | **required** |
| `notifications` | Notifications | `/notifications` | A T S | Core | |
| `students` | Students | `/school_authority/students` | A | Administration | tabs |
| `classes` | Classes | `/school_authority/classes` | A T | Academics | tabs |
| `timetable` | Timetable | `/school_authority/timetable` | A T S | Academics | tabs |
| `attendance` | Attendance | `/school_authority/attendance` | A T | Academics | tabs |
| `enrollment` | Enrolment | `/school_authority/enrollment` | A | Administration | |
| `send_notification` | Send Message | `/admin/send-notification` | A T | Communication | |
| `exams` | Exams | `/school_authority/exams` | A T S | Academics | |
| `rbac_management` | Roles & Access | `/admin/roles` | A | Administration | **admin-only** |
| `staff` | Staff & Users | `/admin/staff` | A | Administration | |
| `my_classes` | My Classes | `/teacher/classes` | T | Academics | not-staff |
| `quizzes` | Quizzes | `/teacher/quizzes` | T | Academics | not-staff |
| `assignments` | Assignments | `/student/assignments` | T S | Academics | not-staff |
| `grades` | Grades | `/student/grades` | T S | Academics | not-staff |
| `chat` | Messages | `/student/chat` | T S | Communication | not-staff |

> Super-admin's 5 pages (Tenants, Admins, Module Access, Analytics, Feedback) are **not** in this catalog — they're a separate hardcoded surface.

---

## How it resolves (quick reference)

| Role | Effective pages |
|---|---|
| **Super Admin** | Full catalog — bypasses all checks |
| **Admin** | All admin pages — *currently hardcoded ON* (org ceiling not applied to admin's own sidebar) |
| **Teacher / Student** | Pages in their `audience` ∩ org ceiling, minus anything their role explicitly disables (**default-allow**) |
| **Staff** | Only pages their role explicitly grants ∩ org ceiling, + required (**default-deny allow-list**) |

- **Tier 0 — Super-admin → Org ceiling:** `tenant_module_permissions` via Module Access (`/api/access/org/{tenant}/pages`).
- **Tier 1 — Admin → Roles:** `role_module_permissions` via Roles & Access (`/api/access/roles`), clamped to the ceiling (locked pages show as "Premium / Not in your plan").
- **Assignment — Admin → User:** `rbac_role_id` on the user, via Staff & Users (`/api/staff`).
- **Login → sidebar:** `GET /api/access/my-permissions` → `PermissionStore` → `navigation_sidebar`.
