# EduAssist — Directory Structure, "Where Is What" & How to Add a Feature

> Companion to [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) (the rules) and
> [MODULE_AND_FEATURE_PLAN.md](MODULE_AND_FEATURE_PLAN.md) (the roadmap). This is the **layout contract +
> install guide**: where every file lives today, the wiring anchors a feature touches, and a step-by-step
> recipe so a new module can be added by reading this doc alone. Keep it in sync when the structure changes.

## 0. The one rule

**Organise by FEATURE (vertical slice), never by organisation type.** The product is **institution-agnostic**:
school vs college vs coaching differences are handled by admin-named **roles**, the per-group **page ceiling**,
and **configurable labels** — *not* by forking code. So there is **no `school/` `college/` `coaching/`** anywhere.
Institution type is **data + config**, never a code boundary. One feature = one folder, shown to whichever roles
RBAC grants the page to. A feature maps 1:1 to a **catalog page-domain** ↔ a **backend module** ↔ a **FE slice**:
`features/<name>/` ↔ `app/<name>_management/` ↔ catalog `<page_key>`.

---

## 1. Backend — `edu_backend/app/` (current state)

A **modular monolith of vertical slices**; each domain owns its full stack (`models/ routers/ services/ schemas/`).

```
app/
  main.py                   # mounts every module's router (app.include_router)
  core/                     # config.py · database.py · cache.py · rate_limit.py · exceptions.py   (infra)
  models/   base.py         # SQLAlchemy Base ONLY (shared)
  routers/  health.py       # global health check ONLY
  services/ base_service.py # shared base service ONLY (used by org + authority services)
  auth_rbac/                # AUTH + RBAC engine (the core everything hangs off)
    access/   catalog.py · custom_fields.py · deps.py · models.py · router.py · service.py   # the RBAC engine
    security/ principal.py · deps.py · tokens.py · sessions.py · password.py · otp.py
    services/ login_service.py · signup_service.py · auth_service.py · phone_service.py     # phone_service = phone-uniqueness guard
    routers/  auth.py        # ⚠ see note below
    models/   super_admin.py
  authority_management/      # the admin identity (authorities table) · models · routers · schemas · services
  staff_management/          # members (every non-admin user) · models(member) · routers(staff) · services(staff_service, imports)
  organisation_management/   # organisations · models · routers · schemas · services
  group_management/          # institution group · models(group) ONLY  ⚠ see note
  feedback_management/       # feedback · models · routers
database_compare/            # migrations.py (idempotent list) + run_local/production_migration  (NOT inside app/)
```

> **⚠ Known debt (intentional, not fixed):** `auth_rbac/routers/auth.py` is a ~960-line "god router" that, besides
> auth (login/refresh/signup/password), currently also hosts the **admin** (`/api/auth/admins*`), **group**
> (`/api/auth/groups*`), and **organisation** (`/api/auth/organisations*`, `/my-organisation`,
> `/switch-organisation`) endpoints. That is why `group_management/` is a **model-only stub** — its routes live in
> `auth.py`. When you need to add/edit admin, group, or org endpoints, **they go in `auth.py` today** (until/unless
> it's split into the three modules). Everything else follows the clean per-module pattern.

**Rule:** a new feature = a new `app/<name>_management/` package; mount its router in `main.py`; add its catalog
page in `auth_rbac/access/catalog.py`; gate writes with `require_authority_or_module('<key>')`. Keep the global
`models/routers/services` holding ONLY shared things (Base, health, base_service).

---

## 2. Frontend — `lib/` (current state)

Three layers: **`core/`** (cross-cutting non-UI), **`shared/`** (cross-cutting UI + design system + app shell),
**`features/<name>/`** (self-contained slices: `screens/ widgets/ services/ models/`).

```
lib/
  main.dart
  core/
    auth/      auth_session.dart · auth_storage.dart · permission_store.dart
    network/   app_http.dart            # the authed HTTP wrapper (401-refresh/retry/hard-logout + multipart)
    constants/ app_theme.dart · app_constants.dart
    utils/     app_router.dart · org_session.dart · responsive.dart
    models/    organisation.dart        # shared model (used by auth + organisation)
  shared/
    root_scaffold_messenger.dart
    widgets/   main_layout.dart · navigation_sidebar.dart · navigation_header.dart · org_switcher.dart   # app shell
               sa_widgets.dart          # DESIGN SYSTEM (SaScreen, SaGradientHeader, SaCard, SaStatusPill… — used in 8 areas)
               custom_fields.dart       # per-role custom-field builder + form  (used by rbac + members)
               page_group_toggle.dart   # Function/Audience grouping (used by rbac + super_admin)
  features/
    auth/          screens/(landing, organisation_selection) · widgets/(login_card, search_bar_widget) · services/(auth_api_service)
    super_admin/   screens/(admins, analytics, institution_groups, module_access) · widgets/(group_pages_dialog) · services/(super_admin_service)
    rbac/          screens/(role_management) · widgets/(role_templates) · services/(roles_service)          # Roles & Access
    members/       screens/(staff_management) · services/(staff_service)                                     # Staff & Users (+ bulk import)
    profile/       screens/(profile) · services/(profile_service)
    organisation/  screens/(admin_onboarding) · widgets/(organisation_create_dialog, org_levels_field) · services/(organisation_management_service)
    feedback/      screens/(feedback) · widgets/(feedback_dialog) · services/(feedback_service)
    ai/            widgets/(ai_assistant_widget) · services/(ai_service, ai_assistant_manager)               # global AI overlay
```

### Where does a new file go?
- Used by **one** feature → that `features/<name>/{screens|widgets|services|models}`.
- Used by **≥2** features and it's **UI** → `shared/widgets/`.   • non-UI infra (auth/http/config) → `core/`.
- App shell / navigation → `shared/widgets/`.
- A new typed data model used only by one feature → `features/<name>/models/` (raw `Map<String,dynamic>` is fine early).

---

## 3. WHERE IS WHAT — the wiring anchors (every feature touches these)

A page is only "real" once it's registered in these shared spots. Memorise this map:

| Concern | File | What to add |
|---|---|---|
| **Catalog page** (source of truth) | `app/auth_rbac/access/catalog.py` → `MODULES` | `_m("<key>", "<Label>", "<icon>", "<path>", [AUTHORITY], section=SEC_…)` |
| **Write authorization** | `app/auth_rbac/access/deps.py` | gate endpoints with `Depends(require_authority_or_module("<key>"))` (or `require_staff_or_module`) |
| **Mount the router** | `app/main.py` | `from .<mod>.routers.<x> import router as <x>_router` + `app.include_router(<x>_router, dependencies=AUTHED)` |
| **New tables** | ORM model under `app/<mod>/models/` | `Base.metadata.create_all` builds them; FK the actor to `members.id` (`member_id`) |
| **Schema changes / indexes** | `database_compare/migrations.py` | append an idempotent `ALTER/CREATE INDEX … IF NOT EXISTS`, run `run_local_migration` |
| **FE route** | `lib/core/utils/app_router.dart` | a `GoRoute(path: "<path>", builder: …)` under the authority `ShellRoute` |
| **FE sidebar + gating** | `lib/shared/widgets/navigation_sidebar.dart` | a nav item `{id, label, path, icon}` (icon inline on the item) + `_navModule["<nav-id>"]="<key>"`. For the dynamic **staff** sidebar also add `_staffNavIcons["<key>"]=Icons.x`. The item auto-hides unless `PermissionStore.canModule("<key>")`. (Add to `_alwaysShow` ONLY for always-on pages like Profile.) |
| **FE API client** | `lib/features/<name>/services/<x>_service.dart` | `import '../../../core/network/app_http.dart' as http;` then `http.get/post/...('/api/<x>/…')` |
| **FE permissions** | `lib/core/auth/permission_store.dart` | nothing to edit — it loads `/api/access/my-permissions`; `canModule("<key>")` drives sidebar + guards |

The `<key>` (catalog page key) is the single thread tying it together: BE catalog ↔ BE gate ↔ FE `_navModule` ↔
`PermissionStore.canModule`. Keep it identical in all four places.

---

## 4. HOW TO ADD A FEATURE / MODULE (the recipe — do top-down)

> Prereq: the feature's actor is a **`member`** (`members.id`); grade/section/etc. come from the **class**, not the
> member. Build roots before leaves (see MODULE_AND_FEATURE_PLAN §6): `Classes/Enrolment` before academic leaves.

### Backend
1. `mkdir -p app/<name>_management/{models,routers,services,schemas}` + empty `__init__.py` in each.
2. **Model** `models/<x>.py` — `class X(Base): __tablename__=…`; FK actor/subject to `members.id`; scope rows by
   `organisation_id`.
3. **Service** `services/<x>_service.py` — business logic; every query filtered by `organisation_id` (tenant
   isolation); reuse `StaffService`/`RBACService` patterns.
4. **Schemas** pydantic in `schemas/` (or inline in the router for tiny ones).
5. **Router** `routers/<x>.py` — `router = APIRouter(prefix="/api/<x>", tags=["X"])`; every write
   `Depends(require_authority_or_module("<key>"))`; read the caller via `Depends(get_current_principal)` and scope
   to `principal.organisation_id`.
6. **Mount** in `app/main.py` (`include_router(..., dependencies=AUTHED)`).
7. **Catalog** add `_m("<key>", "<Label>", "<icon>", "<path>", [AUTHORITY], section=SEC_…)` in `catalog.py`.
8. **Migrate** new tables auto-create on startup (`create_all`); for indexes/alters append to
   `database_compare/migrations.py` and run `PYTHONPATH=. ./venv/bin/python -m database_compare.run_local_migration`.
9. **Verify** `PYTHONPATH=. ./venv/bin/python -c "import app.main; from sqlalchemy.orm import configure_mappers; configure_mappers()"` + a transactional test (create→read→rollback/cleanup).

### Frontend
1. `lib/features/<name>/{screens,services,widgets,models}/`.
2. **Service** `services/<x>_service.dart` — `import '../../../core/network/app_http.dart' as http;`; hit
   `/api/<x>/…`; parse the `{items,total}` envelope where the API paginates.
3. **Screen** `screens/<x>_screen.dart` — build inside `SaScreen` + `SaGradientHeader` (from `shared/widgets/sa_widgets.dart`);
   **no own `Scaffold`** (the shell provides it).
4. **Route** add a `GoRoute(path:"<path>", builder:(_, __) => const XScreen())` in `lib/core/utils/app_router.dart`
   under the authority `ShellRoute`.
5. **Sidebar** in `lib/shared/widgets/navigation_sidebar.dart`: add the nav item (with its inline `icon`) +
   `_navModule["<nav-id>"]="<key>"`; for the dynamic staff sidebar also add `_staffNavIcons["<key>"]=Icons.x`.
6. **Verify** `dart analyze lib` → 0 errors.

> Trigger phrase: say *"build feature X per DIRECTORY_STRUCTURE.md"* and this recipe is followed end-to-end.

---

## 5. Future features — planned slices (create the folder only when you build it)

| Feature (build order) | Frontend slice | Backend module | Catalog page key(s) |
|---|---|---|---|
| Classes / Batches | `features/classes/` | `app/class_management/` | `classes` |
| Enrolment | `features/enrolment/` | `app/enrollment_management/` | `enrollment` |
| Attendance | `features/attendance/` | `app/attendance_management/` | `attendance` |
| Exams / Marks | `features/exams/` | `app/exam_management/` | `exams` |
| Assessments / Quizzes / Assignments | `features/assessments/` | `app/assessment_management/` | `quizzes`, `assignments`, `grades` |
| Chat / Messages | `features/chat/` | `app/chat_management/` | `chat` |
| Timetable | `features/timetable/` | `app/timetable_management/` | `timetable` |
| Notifications | `features/notifications/` | `app/notification_management/` | `notifications`, `send_notification` |
| Fees / Payments | `features/fees/` | `app/fees_management/` | `fees` |
| Study Materials | `features/study_materials/` | `app/materials_management/` | `materials` |
| Parent access | `features/parent/` | (reuses members/rbac) | `parent_*` |
| Calendar / Events | `features/calendar/` | `app/calendar_management/` | `calendar` |
| Admissions / Leads | `features/admissions/` | `app/admissions_management/` | `admissions` |
| Org Settings + presets | extend `features/organisation/` | extend `organisation_management/` | `org_settings` |

> Institution type never appears here. A coaching's "batch tutor" and a college's "professor" are the same
> `members` row + role + granted pages — one slice serves every institution type.
