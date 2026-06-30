# EduAssist — Test Logins

> Login is **phone number + password**. Type the phone **exactly** as shown (plain digits, no `+`, no spaces).

- **App:** http://localhost:8550
- **API:** http://localhost:8000  (Swagger: http://localhost:8000/docs)
- **Dev OTP** (first-login / forgot-password): always **`999999`**

> The database is seeded with **only the super-admin**. There are no pre-seeded
> organisations or other users — you create them yourself (see below). There are
> **3 user types**: `super_admin`, `authority` (the org admin), and `staff` (every
> other user — "Teacher", "Student", "Coach"… are just admin-defined `staff` roles).
> There is **no `teacher`/`student` role** and **no invite system**.

---

## 👑 Platform Super-Admin (the only seeded account)

Seeded from `.env` (`SUPER_ADMIN_PASSWORD`). Logs in via the direct login card (no
organisation). Sees the 6 super-admin pages: **Organisations, Admins, Module Access,
Analytics, Feedback, Profile**.

| Phone | Password |
|---|---|
| `9999999999` | `SuperAdmin123!` |

flutter run --release -d 00008140-0012644026D8801C
---

## ➕ Create users — password-less, set at first login (no invites)

The creator never sets a password; the new user sets their own on first login.

1. **Super-admin → admin:** log in as super-admin → **Admins** → add an admin
   (name + phone, **no password**). The admin is created with `status='invited'`.
2. **Admin → staff:** that admin logs in (first-login below), creates an
   organisation, then **Staff & Users** → add a user with an assigned **role**
   (again no password).

### First login (the new user sets their password)
Login card → **"First time here? Set your password"** (inline, like *Forgot password?*)
→ enter the phone they were created with → **Send OTP** → enter **`999999`** → set a
password → auto-logged in. From then on they log in normally with phone + password.

## 🔑 Forgot password
Login card → **Forgot password?** → phone → **Send OTP** → **`999999`** → new password.

---

## Notes
- **Entry flow:** Get Started → **pick an organisation** → **"Sign in to this
  organisation"** → the login card opens in place (phone + password; the role is
  resolved by the server, not chosen). The super-admin uses the direct login card
  (no organisation).
- If a login returns 401, the phone/password didn't match — type the phone exactly
  (no `+`, no spaces). A user who hasn't set a password yet can't log in until they
  do the **first-login** flow above.

<!-- physical-device run: flutter run --release -d 00008140-0012644026D8801C -->
