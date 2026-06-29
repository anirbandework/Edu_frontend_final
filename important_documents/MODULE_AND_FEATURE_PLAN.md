# EduAssist — Module & Feature Plan

> Companion to [SYSTEM_ARCHITECTURE.md](SYSTEM_ARCHITECTURE.md) (the rules) and
> [PAGES_BY_ROLE.md](PAGES_BY_ROLE.md) (current page lists). This is the **roadmap**: what to keep,
> rework, or delete, what the admin sidebar and organisation pages should be, and what to build next —
> for a product that serves **coachings, schools, colleges, and any educational institution**.

---

## 0. The one principle that decides everything

In the dynamic model there are **3 user types** (`super_admin`, `admin`, `staff`) and **no role-portals**.
So **"Teacher portal" and "Student portal" are NOT modules or roles** — they are just **bundles of
pages** an admin grants to a dynamic role. A "Teacher" is a staff user whose role was granted the
*teaching* pages; a "Student" is a staff user whose role was granted the *learning* pages.

➡️ **Every module below is reframed as: which PAGES does it contribute to the catalog, and who (which
kind of role) gets them.** Institution differences (school vs college vs coaching) are handled by
(a) admin-named **roles**, (b) the per-org **page ceiling**, and (c) a few **configurable labels** — not
by forking the codebase.

---

## 1. Verdict on each module

| Module | Verdict | What it becomes |
|---|---|---|
| **Super-admin / Tenant** | ✅ **KEEP** | Platform layer: manages admins + the two per-org ceilings. Unchanged. |
| **RBAC** | ✅ **KEEP (core)** | The dynamic role engine. Everything hangs off it. |
| **Authority / Admin core** | ✅ **KEEP** | The admin's own toolset (roles, staff, classes, timetable, enrolment, settings, analytics). |
| **Teacher portal** | ♻️ **REWORK → pages** | Delete the teacher *role/shell/login* (done). Keep the *screens* and expose them as **grantable pages**: My Classes, Mark Attendance, Enter Marks/Grades, Build Quiz/Assignment, Schedule, Students directory. |
| **Student portal** | ♻️ **REWORK → pages** | Delete the student *role/shell/login* (done). Keep the *screens* as **grantable pages**: Assignments (submit), Grades/Marks (view), Report Card, Timetable, Attendance (view), Take Quiz, Exam results. |
| **Enrollment** | ✅ **KEEP** | Admin/"Registrar" page: place members into classes/batches. Becomes the link between a member and a class. |
| **Exams / Marks** | ✅ **KEEP (rework actor)** | Pages: Exam management (create/publish), Marks entry, Marks/results view. Decouple from `teachers.id`/`students.id`. |
| **Assessments / Quizzes** | ✅ **KEEP (rework actor)** | Pages: Quiz builder, Take quiz, Results, Assignments + grading. Decouple actor. |
| **Chat** | ✅ **KEEP (rework actor)** | Messaging between members. Decouple actor to the unified member id. |

**Delete-able once features are reworked (Phase 2):** `teacher_management/`, `student_management/`
backend modules + `teachers`/`students` tables + `lib/features/teacher/`, `lib/features/student/`
screens (after their pages are rebuilt/repointed as grantable pages).

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
super-admin can enable per org and the admin can grant to roles. Proposed **target catalog**, grouped:

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

The admin's own toolset (the **Admin-pages** ceiling; the super-admin can hide any of these per org):

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

**Institution-specific (enable via the org ceiling):**
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
| 10 | **Org Settings + institution presets** (labels, terms, ceiling templates) | **4** | Flexibility polish — do last, once the page set is stable | `tenant_management/`, `catalog.py` |

> **Report-card / results** is *not* its own build step — it's a **read view** that appears automatically
> once Marks/Exams (5) exist. Same for Analytics/Reports: build it after the features it reports on.

### The phases (map onto the tiers)
- **Phase 1 — DONE ✅:** Identity/login/RBAC + 2 ceilings + dynamic roles; **3 user types**; per-route
  admin-page enforcement; dead-FE teacher/student cleanup (#1) finished.
- **Phase 2 (the unlock):** #2 → #7 — identity unification then rework each academic feature onto `member_id`.
  - #2 **DONE ✅** — `staff_users` → `members` (table/model; the `staff` token kept).
  - #3 **DONE ✅** — Classes/Batches + Enrolment onto `member_id` (enrolment = `(member_id, class_id)`;
    teaching = a member in the class's assigned list). `Enrollment.member_id` FK→`members.id`; class/enrolment
    services, routers + FE (`enrollment_service`, `class_service`, `enrollment_screen`, `class_screen`,
    `teacher_portal_service`) all on `member_id`/`member_name`/`member_hrid` (=`member.staff_id`). Enrolment
    writes gated `require_authority_or_module('classes','enrollment')`. DB recreated; BE import+mappers + FE
    `dart analyze` clean (only pre-existing info lints). Two legacy routes' `Enrollment.student_id`→`member_id`.
  - #4 **DONE ✅** — Attendance. The model was already polymorphic (`user_id`/`marked_by` plain UUIDs, no FK
    to teachers/students). Made `STAFF` the canonical marker: server derives `marked_by_type` from the JWT
    (`_principal_user_type` → SCHOOL_AUTHORITY for admins, STAFF for members, never TEACHER), validators
    authorize STAFF via the page grant, all 7 write routes gated `require_authority_or_module('attendance')`,
    and the post-#3-broken `_verify_teacher_student_relationship` SQL (`enrollments.student_id`) is dead+fixed.
    No DB change. BE import+mappers + FE `dart analyze` clean.
  - **Interlude (DONE ✅):** (a) dead-service cleanup — removed `teacher_service.dart`, `student_service.dart`
    and their two orphaned role-landing dashboards. (b) **Students = members** — the admin Students page now
    backs `members` (`profile.category='student'` + default `staff` role; extras in `profile`; grade/section via
    the enrolment class). New students are immediately enrollable; legacy `students` table untouched (FK'd by
    exams/assessments/chat until #5–#7). Verified: BE import + live JSON-predicate query + FE analyze.
  - #5 **DONE ✅** — Exams/Marks. `student_exam_marks.student_id`→`member_id` (FK `members.id`; `uq_member_exam_mark`,
    `idx_marks_member`); `exam_service` + the broken post-#3 enrolment SQL now on `member_id`; the marks-list query
    JOINs `members` (roll_number read from `profile`); writes gated `require_authority_or_module('exams')`; the API
    key `student_id` is kept but carries a `members.id`. FE marks-entry (`teacher_grades_screen`) reads
    `member_id`/`member_hrid` from the roster. DB recreated; BE import + live JOIN smoke + FE analyze clean.
  - #6 **DONE ✅** — Assessments/Quizzes (heaviest). 6 tables' 8 FKs (`assessments.teacher_id`;
    `assessment_submissions.student_id`+`graded_by`; `student_grades.student_id`+`calculated_by`;
    `report_cards.student_id`; `quizzes.teacher_id`; `quiz_attempts.student_id`) repointed
    `teachers.id`/`students.id`→`members.id` (column names KEPT — they now hold a `members.id`).
    quizzes/quiz_attempts relationships → `Member`; 4 services' `Student`/`Teacher` ORM → `Member` (+ 2 dead
    imports removed); 7 raw-SQL JOINs → `members`. Gating left as `require_staff` (per-page-grant retrofit
    deferred to the enforcement pass). DB recreated (all 8 FKs verified → members); BE import+mappers + live
    JOIN smoke + FE analyze clean.
  - #7 **DONE ✅** — Chat + Timetable. `chat_rooms.teacher_id`+`student_id`→`members.id` (two FKs to members →
    relationships need `foreign_keys=`); `teacher_timetables.teacher_id`→`members.id`, `teacher_ref`→`Member`
    (back-ref removed from the legacy `Teacher` model); `chat_service` 16 ORM/join swaps → `Member`; timetable
    `FROM teachers`→`FROM members` (2). DB recreated (3 FKs verified → members); BE import+mappers + live JOIN + FE analyze clean.
  - #8 **DONE ✅ — full decoupling (raw SQL + the stragglers the milestone grep surfaced).** Nothing outside the
    legacy `teacher_management`/`student_management` module files now references the `teachers`/`students` tables
    or `Student`/`Teacher` models (verified by an app-wide FK/relationship/select/import/raw-SQL sweep — all empty).
    Fixed: **attendance** (~5 raw queries via category-filtered member subqueries + `e.student_id`→`member_id` +
    grade/section→`profile`; the broken class-roster join), **attendance_service** tenant UNION, **tenant** dashboard
    counts, **notification_management** (~20 queries incl. teacher `personal_info` JSON→flat member cols, class/grade
    targeting via enrollments, sender validation), **auth_service** user-profile (Teacher+Student branches → one
    `Member` branch — also fixed a latent bug where staff profiles didn't resolve), **invitation_service** phone
    check, and **decoupled `Tenant`** from the `Student`/`Teacher` relationships. BE import+mappers + per-shape live
    SQL smokes + DB recreate all green.
    <!-- historical scope notes: -->
    The earlier finding was that **raw SQL** still referenced those tables:
    - **attendance_management (a #4 GAP):** `attendance.py` has ~5 raw queries (`JOIN students`/`FROM students`/
      `FROM teachers`) + `attendance_service.py:40` tenant-lookup UNION. NOTE `attendance.py:295` joins
      `enrollments e ... e.student_id` which **#3 renamed to `member_id` → currently broken (would 500)**. Several
      select/filter `s.grade_level`/`s.section`/`s.roll_number` → now `members.profile` (or class via enrolment) —
      a semantics rework, not a pure table swap.
    - **notification_management (UNPLANNED module):** ~20 raw-SQL refs to students/teachers (recipient lists by
      class, sender-name resolution) in `routers/notifications.py` + `services/notification_service.py`.
    - **tenant_management:** dashboard `COUNT(*) FROM students/teachers` (`tenant.py:858`) → member-category counts.
  - **Teardown — DONE ✅:** dropped `teachers`/`students` tables; deleted `teacher_management` (+ unmounted from
    `main.py`) and the legacy `Student` model (kept `student_management`'s member-backed router/service); deleted the
    orphaned `features/teacher` + `features/student` FE screens + `student_portal_service`; removed
    `ROLE_TEACHER`/`ROLE_STUDENT` (Students-page invite → `ROLE_STAFF`); cleaned `migrations.py`/`seeds.py`. Verified:
    app-wide residual sweeps empty, clean DB recreate, multi-subsystem live smoke green, FE `dart analyze` 0 errors.
  - **Enforcement retrofit — DONE ✅:** 35 assessment gates `require_staff` → `require_authority_or_module('quizzes'
    /'assignments'/'grades')`; catalog now marks those 3 pages staff-grantable (post-#6 they're member-backed), so a
    dynamic "Teacher" role can be granted them. **Member self-onboarding — DONE ✅:** `signup_service` accepts
    `ROLE_STAFF` invites, so the Students-page set-password link activates the pre-created member. Both import-verified.
- **Phase 3:** #8 → #9 — new high-value features as catalog pages + gated endpoints (per the §9 recipe
  in SYSTEM_ARCHITECTURE).
- **Phase 4:** #10 — institution flexibility (Org Settings + per-org ceiling presets: "School",
  "College", "Coaching" templates that pre-enable a sensible page set).

> **Pattern established in #3 (reuse for #4-#7):** a feature's actor/subject is a `member_id` (FK
> `members.id`); grade/section/etc. come from the **class**, not the member; the human-readable code is
> `member.staff_id`. Gate every write with `require_authority_or_module('<page_key>')`.

---

## 7. Recommendation — what to do next

1. **Finish Phase 1 cleanup** (delete dead teacher/student FE) — quick, makes the tree honest.
2. **Start Phase 2 with the rename + Classes/Enrolment rework** — it's the foundation everything else
   (attendance, marks, results) hangs on, and it proves the actor-generic pattern end-to-end on one
   feature before rolling it across the rest.
3. Keep the catalog growing through the §9 recipe so every new page automatically flows through both
   ceilings + roles.

When you pick a feature to build/rework, say *"do feature X per MODULE_AND_FEATURE_PLAN.md"* and I'll
take it through: catalog entry → `member_id` tables → gated endpoints → screen → sidebar.
