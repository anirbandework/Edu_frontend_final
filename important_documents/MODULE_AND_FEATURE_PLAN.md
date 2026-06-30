# EduAssist — Module & Feature Plan

> Companion to [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) (the rules) and
> [PAGES_BY_ROLE.md](PAGES_BY_ROLE.md) (current page lists). This is the **roadmap**: what to keep,
> rework, or delete, what the admin sidebar and organisation pages should be, and what to build next —
> for a product that serves **coachings, schools, colleges, private tutors, and any educational institution**.

> ## ⚠️ STRIP-DOWN (2026-06-29) — read this first
> The app was **deliberately stripped to its auth/RBAC core.** Every feature module below was deleted
> on **both** frontend and backend (folders removed, routers unmounted, DB rebuilt with only the
> required tables). **What survives = auth + super-admin's 6 pages + admin's Roles & Access / Staff &
> Users / Profile + Profile for everyone else.** Catalog = 3 pages (`profile`, `rbac_management`,
> `staff`).
>
> **This document is now the REBUILD plan.** The verdicts (§1), target catalog (§3), dependency tree
> and build order (§6) all still hold — they're how features get re-added, each via the §9 recipe in
> SYSTEM_ARCHITECTURE. The "DONE ✅" markers in §6 record work that was *completed once and then removed
> in the strip-down* — treat those features as **to-be-rebuilt**, not present. The hard lessons from
> that first pass (the `member_id` actor-generic pattern, the gating recipe) carry forward and make the
> rebuild faster.

> ## 🏛️ Institution Group layer (2026-06-29) — also read this
> Above organisations there is now an **Institution Group** (the top-level tenant):
> `super_admin → group → admins (share the group) → organisations (group-shared, switchable) → staff`.
> The two page ceilings are **per-group** now (`group_module_permissions`: `role_enabled` = the
> Group-pages pool, `admin_enabled` = Admin pages), not per-org. When a feature page is re-added to the
> catalog it flows through the **group** ceiling (every org in the group inherits it), then the per-org
> roles. See SYSTEM_ARCHITECTURE §1, §3, §4.

---

## 0. The one principle that decides everything

In the dynamic model there are **3 user types** (`super_admin`, `admin`, `staff`) and **no role-portals**.
So **"Teacher portal" and "Student portal" are NOT modules or roles** — they are just **bundles of
pages** an admin grants to a dynamic role. A "Teacher" is a staff user whose role was granted the
*teaching* pages; a "Student" is a staff user whose role was granted the *learning* pages.

➡️ **Every module below is reframed as: which PAGES does it contribute to the catalog, and who (which
kind of role) gets them.** Institution differences (school vs college vs coaching) are handled by
(a) admin-named **roles**, (b) the per-**group** **page ceiling**, and (c) a few **configurable labels** — not
by forking the codebase.

---

## 1. Verdict on each module

| Module | Verdict | What it becomes |
|---|---|---|
| **Super-admin / Institution Group** | ✅ **KEEP** | Platform layer: manages **institution groups** + admins + the two **per-group** ceilings (Admin pages + Group pages) + **activation/deactivation** at group / org / admin level (enforced at login + refresh). |
| **RBAC** | ✅ **KEEP (core)** | The dynamic role engine. Everything hangs off it. |
| **Authority / Admin core** | ✅ **KEEP** | The admin's own toolset (roles, staff, classes, timetable, enrolment, settings, analytics). |
| **Teacher portal** | ♻️ **REWORK → pages** | Delete the teacher *role/shell/login* (done). Keep the *screens* and expose them as **grantable pages**: My Classes, Mark Attendance, Enter Marks/Grades, Build Quiz/Assignment, Schedule, Students directory. |
| **Student portal** | ♻️ **REWORK → pages** | Delete the student *role/shell/login* (done). Keep the *screens* as **grantable pages**: Assignments (submit), Grades/Marks (view), Report Card, Timetable, Attendance (view), Take Quiz, Exam results. |
| **Enrollment** | ✅ **KEEP** | Admin/"Registrar" page: place members into classes/batches. Becomes the link between a member and a class. |
| **Exams / Marks** | ✅ **KEEP (rework actor)** | Pages: Exam management (create/publish), Marks entry, Marks/results view. Decouple from `teachers.id`/`students.id`. |
| **Assessments / Quizzes** | ✅ **KEEP (rework actor)** | Pages: Quiz builder, Take quiz, Results, Assignments + grading. Decouple actor. |
| **Chat** | ✅ **KEEP (rework actor)** | Messaging between members. Decouple actor to the unified member id. |

> **Strip-down note:** all of the ♻️/✅ feature modules above were built then **removed** — their
> backend folders (`attendance_management`, `exam_management`, `assessment_management`, `chat_management`,
> `timetable_management`, `enrollment_management`, `class_management`, `notification_management`,
> `student_management`) and matching FE screens/services are deleted. The legacy `teachers`/`students`
> tables and `teacher_management`/`student_management` are gone. The verdicts stand as the **rebuild
> targets**; "KEEP" means "re-add it this way", not "it's currently in the tree".

---

## 2. THE key decision — unify identity (do this first in Phase 2)

Today non-admin users are split across `teachers`, `students`, `staff_users`, and features FK to
`teachers.id`/`students.id`. That is the ONLY thing blocking "fully dynamic".

**Decision: one identity table for every non-admin user.**

- All non-admin users live in **one table** (today `staff_users`). A "teacher", "student", "professor",
  "parent" is just a row there with an assigned **role**.
- **Rename `staff_users` → a neutral name** (recommend **`members`** or `org_users`) — "staff" reads
  wrong for students. (Cheap now: fresh DB, no data.)
- **Every feature table references `member_id` (the generic actor)**, never `teachers.id`/`students.id`:
  - enrolment: `(member_id, class_id)` — a "student" is a member enrolled in a class.
  - teaching: `(member_id, class_id, subject)` — a "teacher" is a member assigned to teach.
  - marks/attendance/submissions: `member_id` for both the actor and the subject.
- Then **delete** `teachers`/`students` tables + `teacher_management`/`student_management`.

This makes the whole product institution-agnostic: a coaching's "batch tutor" and a college's
"professor" are the same shape, differing only by role name + granted pages.

---

## 3. The organisation page catalog (what to offer)

The catalog ([`catalog.py`](../../../edu_backend/app/auth_rbac/access/catalog.py)) is the menu of pages the
super-admin can enable **per institution group** and the admin can grant to roles. Proposed **target catalog**, grouped:

### Core (everyone)
| Page | Notes |
|---|---|
| Dashboard | Per-role landing (stats relevant to the granted pages) |
| Profile | `required`, always on |
| Notifications | Inbox |
| Chat / Messages | Member-to-member |

### Administration (admin tools — `admin_only` or admin-pages)
| Page | Notes |
|---|---|
| Roles & Access | `admin_only` — define roles + grants |
| Staff & Users (Members) | Create members, assign roles |
| Classes / Batches | Generic grouping (label configurable) |
| Timetable | Build schedules |
| Enrolment | Place members in classes |
| Send Message | Broadcast notifications |
| Analytics / Reports | Org-wide stats |
| Organisation Settings | Labels, academic year/terms, branding (NEW) |

### Teaching (grant to Teacher/Professor/Tutor roles)
| Page | Notes |
|---|---|
| My Classes | Classes the member teaches |
| Mark Attendance | Per class/session |
| Marks / Grade entry | Enter exam/assignment marks |
| Quiz builder | Create quizzes |
| Assignments | Create + grade |
| Exam management | Create/publish exams |
| Students/Members directory | Roster of their classes |

### Learning (grant to Student/Learner roles)
| Page | Notes |
|---|---|
| Assignments | View + submit |
| Quizzes | Take |
| Exams / Results | Take + view results |
| Marks / Grades | View |
| Report Card | Consolidated |
| Timetable | View |
| Attendance | View own |

> `staff_grantable=False` is no longer needed once features are actor-generic — any page can go to any
> role. Until then, keep teaching/learning pages role-coupled.

---

## 4. What the ADMIN sidebar should contain

The admin's own toolset (the **Admin-pages** ceiling; the super-admin can hide any of these per institution group):

1. **Dashboard** — org overview (members, classes, today's attendance, fees due…)
2. **Members / Staff & Users** — create users, assign roles
3. **Roles & Access** — define roles + page grants (the heart of the product)
4. **Classes / Batches** — create groupings
5. **Timetable** — schedules
6. **Enrolment** — place members in classes
7. **Exams** — create/publish (admin-level)
8. **Send Message** — broadcasts
9. **Analytics / Reports**
10. **Organisation Settings** *(NEW)* — labels (Class/Batch, Teacher/Professor), academic year/terms, branding
11. **Profile** *(required)*

> The admin does **not** need Chat/Assignments/Quizzes as admin tools — those are pages they *grant to
> roles*, not run themselves (though they can grant themselves a role-like view if wanted).

---

## 5. More features to take into account (by need)

**High value across all institution types (build after the core rework):**
- 💰 **Fees / Payments** — essential for coachings & many schools (invoices, due, receipts, online pay).
- 📚 **Study Materials / Resources** — upload notes/PDFs/videos per class.
- 🗓️ **Events / Academic Calendar** — holidays, exams, PTMs.
- 👪 **Parent access** — a "Parent" role linked to a student member (view-only grades/attendance/fees).
- 🎫 **Admissions / Leads** — coaching/college intake pipeline (enquiry → admission → member).

**Institution-specific (enable via the group ceiling):**
- **Coaching:** batches, fees, doubt-chat, test series, lead management.
- **School:** sections, report cards, parent portal, transport, fees.
- **College:** courses/semesters/credits/GPA, departments, electives, TAs.

**Cross-cutting platform features:**
- **Configurable terminology** (Class↔Batch↔Course, Teacher↔Professor↔Tutor) — per-org labels so one
  app fits every institution without code forks.
- **Reports/exports** (attendance %, marks sheets, fee collection).
- **Audit log** of admin/super-admin actions.

---

## 6. Build order, dependencies & what to pick first

### Does the order (hierarchy) matter? **YES — a lot.**
The features are **not a flat list** — they form a **dependency tree**. Almost every academic feature
reads *who* (a member) and *where* (a class/batch). If you build a leaf (attendance, marks) before its
root (identity, classes), you build it against `teachers.id`/`students.id` and **rework it twice**.
So: **build roots before leaves.** Among features at the same depth, order by **value**, not dependency.

### The dependency tree
```
            RBAC + IDENTITY (members)                ← Tier 0  FOUNDATION  (everything needs it)
                     │
         CLASSES / BATCHES  +  ENROLMENT             ← Tier 1  BACKBONE   (every per-class feature needs it)
         (a "student" = member enrolled;
          a "teacher" = member assigned to teach)
                     │
   ┌─────────┬───────┼────────┬──────────┬─────────┐
Attendance  Marks/  Assignments Timetable  Chat   Study   ← Tier 2  LEAVES   (need the backbone;
            Exams   /Quizzes                        Materials         independent of EACH OTHER → any order / parallel)
                     
   Fees   Parent   Calendar   Admissions   Analytics   Audit-log       ← Tier 3  ADD-ONS  (need identity;
   /Payments access /Events   /Leads       /Reports                              only loosely need classes → slot anytime)
```

- **Strict, must-be-sequential chain:** `Identity → Classes/Enrolment → (everything else)`.
- **Parallel-OK:** the Tier-2 leaves among themselves; the Tier-3 add-ons among themselves. (You could
  hand two leaves to two people once the backbone exists.)

### What to pick first — the ranked order (do top-down)
| # | Pick | Tier | Why this position | Code to touch |
|---|---|---|---|---|
| 1 | **Finish Phase-1 cleanup** (delete dead teacher/student FE) | — | Trivial, makes the tree honest before new work | `navigation_sidebar`, `app_router`, `invite_screen` |
| 2 | **Identity unification** — rename `staff_users`→`members`, add generic `member_id` | **0** | The root. NOTHING is truly dynamic until every actor is a `member`. Unblocks all. | `auth_rbac/`, `staff_management/` |
| 3 | **Classes/Batches + Enrolment** onto `member_id` | **1** | The backbone every academic feature reads. **Do this first among features** — it also *proves* the `member_id` pattern end-to-end. | `class_management/`, `enrollment_management/` |
| 4 | **Attendance** | **2** | Cheapest leaf, daily value — the ideal first leaf to validate the pattern at low risk | `attendance_management/` |
| 5 | **Exams / Marks** | **2** | Academic core (results, report cards depend on marks) | `exam_management/` |
| 6 | **Assessments / Quizzes / Assignments** (+ grading) | **2** | Academic core; biggest module, do after attendance proves the pattern | `assessment_management/` |
| 7 | **Chat / Messages** | **2** | Communication; self-contained | `chat_management/` |
| 8 | **Fees / Payments** | **3** | Highest commercial value (coachings/schools); independent of academics | *new module* |
| 9 | **Study Materials, Parent access, Calendar/Events, Admissions/Leads** | **3** | By your target market; each is an independent add-on | *new modules* |
| 10 | **Org Settings + institution presets** (labels, terms, ceiling templates) | **4** | Flexibility polish — do last, once the page set is stable | `organisation_management/`, `catalog.py` |

> **Report-card / results** is *not* its own build step — it's a **read view** that appears automatically
> once Marks/Exams (5) exist. Same for Analytics/Reports: build it after the features it reports on.

### The phases (map onto the tiers)

> **Where we actually are after the strip-down:** Phase 1 (the foundation) is **DONE and intact**.
> The Phase-2 feature reworks (#3–#8) were all completed once — and then **deleted in the strip-down**,
> so they are now **rebuild-pending**. The `member_id` actor-generic pattern they proved is the recipe
> to reuse when re-adding them.

- **Phase 1 — DONE ✅ (intact, survived the strip-down):** Identity/login/RBAC + 2 ceilings + dynamic
  roles; **3 user types** (`super_admin` / `authority` / `staff`); per-route admin-page
  enforcement; password-less phone-based first-login (no invites); deactivate-only (no user delete).
  Identity is unified on one table **`members`** (every non-admin user; the `staff` token kept).

- **Phase 2 (the unlock) — REBUILD PENDING after strip-down:** #3 → #7, identity is done, each academic
  feature gets re-added onto `member_id`. *(All of these were built once and removed — the notes below
  are the proven recipe to repeat, not current state.)*
  - **#3 Classes/Batches + Enrolment** — enrolment = `(member_id, class_id)`; teaching = a member in the
    class's assigned list; `member_hrid` = `member.staff_id`; writes gated
    `require_authority_or_module('classes','enrollment')`. (Build this first — it's the backbone and
    re-proves the `member_id` pattern end-to-end.)
  - **#4 Attendance** — keep the actor polymorphic; `STAFF` is the canonical marker (server derives
    `marked_by_type` from the JWT); gate all writes `require_authority_or_module('attendance')`.
  - **#5 Exams/Marks** — marks key on `member_id` (FK `members.id`); marks-list JOINs `members`
    (roll_number from `profile`); gate `require_authority_or_module('exams')`.
  - **#6 Assessments/Quizzes (heaviest)** — assessments/submissions/grades/report-cards/quizzes/
    quiz-attempts all FK `members.id`; gate per page (`quizzes`/`assignments`/`grades`) with
    `require_authority_or_module` so a dynamic "Teacher" role can be granted them.
  - **#7 Chat + Timetable** — `chat_rooms`/`teacher_timetables` actors → `members.id`.
  - **Students page** — a "student" is just a `Member` (`profile.category='student'` + default `staff`
    role; extras in `profile` JSON; grade/section via the enrolment class). Already created from **Staff
    & Users** today; a richer Students screen returns with #3.

- **Phase 3:** #8 → #9 — new high-value features as catalog pages + gated endpoints (Fees/Payments,
  Study Materials, Parent access, Calendar/Events, Admissions/Leads) per the §9 recipe in SYSTEM_ARCHITECTURE.
- **Phase 4:** #10 — institution flexibility (Org Settings + per-**group** ceiling presets: "School",
  "College", "Coaching" templates that pre-enable a sensible page set).

> **Pattern established in #3 (reuse for #4-#7):** a feature's actor/subject is a `member_id` (FK
> `members.id`); grade/section/etc. come from the **class**, not the member; the human-readable code is
> `member.staff_id`. Gate every write with `require_authority_or_module('<page_key>')`.

---

## 7. Recommendation — what to do next

The foundation (auth, identity=`members`, RBAC, the 2 ceilings, dynamic roles) is in place and the app
is stripped to that core. To start rebuilding:

1. **Re-add Classes/Batches + Enrolment (#3) first** — the backbone every academic feature reads, and
   the page that re-proves the `member_id` actor-generic pattern end-to-end before rolling it across the rest.
2. Then work down the Tier-2 leaves (Attendance → Exams/Marks → Quizzes/Assignments → Chat/Timetable),
   each as a catalog page + `member_id` tables + gated endpoints + screen + sidebar icon.
3. Keep the catalog growing through the §9 recipe so every new page automatically flows through both
   ceilings + roles.

When you pick a feature to build, say *"do feature X per MODULE_AND_FEATURE_PLAN.md"* and I'll take it
through: catalog entry → `member_id` tables → gated endpoints → screen → sidebar.
