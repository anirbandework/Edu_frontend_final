# EduAssist — Test Logins

> Login is **phone number + password**. Type the phone **exactly** as shown (plain digits, no `+`, no spaces).
> All credentials below verified against the API (`HTTP 200`).

- **App:** http://localhost:8550
- **API:** http://localhost:8000  (Swagger: http://localhost:8000/docs)
- **Dev OTP** (signup / forgot-password): always **`999999`**

---

## 👑 Platform Super-Admin
Seeded from `.env`. Logs in via the login card (no school). Sees Tenant management + Invite Admin.

| Phone | Password |
|---|---|

| `9999999999` | `SuperAdmin123!` |

flutter run --release -d 00008140-0012644026D8801C


---

## 🏫 Test School

| Role | Name | Phone | Password |
|------|------|-------|----------|
| School Authority (Admin) | John Principal | `1000000001` | `Password123!` |
| Teacher | Jane Teacher | `1000000002` | `Password123!` |
| Student | Alice Student | `1000000003` | `Password123!` |

## 🏫 RBAC Test School

| Role | Name | Phone | Password |
|------|------|-------|----------|
| School Authority (Admin) | Sarah Principal | `2000000001` | `Password123!` |
| Teacher | Mike Teacher | `2000000002` | `Password123!` |
| Student | Emma Student | `2000000003` | `Password123!` |

---

## ➕ Create a new user (invite → signup)
1. Log in as **super-admin** → sidebar **Invite Admin** → pick a school, fill name+email → **Generate invite link** → copy it.
   (Or as a **School Authority** → **Invite users** → invite a Teacher/Student.)
2. Open the link (`…/signup?token=…`) → enter a phone → **Send OTP** → enter **`999999`** → set a password → **Create account** (auto-logged in).

## 🔑 Forgot password
Login card → **Forgot password?** → phone → **Send OTP** → **`999999`** → new password.

---

## Notes
- Flow: **Get Started → pick a school → pick a role → the login card opens in place** (phone + password). Super-admin uses the direct login card (no school).
- If a login returns 401, the phone/password didn't match — type the phone exactly as above (no `+`).
- Earlier seed data used `+1…`-prefixed phones; those have been replaced with the clean numbers above.
