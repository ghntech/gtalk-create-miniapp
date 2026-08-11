# Create a New Miniapp — Starter Kit

> 📖 **Tiếng Việt:** Xem [README.vi.md](README.vi.md)

This folder contains everything you need to create a new miniapp on the GHN gtalk platform.

---

## What's in this folder

| File | Description |
|------|-------------|
| `create.sh/create.ps1` | Script to scaffold a new miniapp project |
| `GETTING_STARTED.md` | Step-by-step guide: VPN → GitLab → scaffold → run → push |
| `DEPLOY_GUIDE.md` | How to request VPN, GitLab account, and DB access |

---

## Naming convention

| | Value | Example |
|-|-------|---------|
| **App name** | Single lowercase word | `donation` |
| **Repo name** | `miniapp_<appname>_service` | `miniapp_donation_service` |
| **Miniapp ID** | `<appname>` | `donation` |
| **URL** | `https://gtalk-miniapp.ghn.vn/apps/<appname>/` | `.../apps/donation/` |
| **DB name** | `<appname>_db` | `donation_db` |

---

## Quick start

### Step 1 — Request VPN and GitLab access first

Before running the script, you need:
1. **VPN access** — see [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) → Step 1
2. **GitLab account + repository** — see [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) → Step 2

> ⏱ VPN approval takes 1–2 business days. Request it early!

### Step 2 — Clone the template repo (requires VPN)
Run this command in Terminal
```bash
git clone https://github.com/ghntech/gtalk-create-miniapp.git
```

### Step 3 — Run the scaffolder
Run this command in Terminal
**macOS / Linux / Git Bash:**
```bash
bash create.sh
```

**Windows (PowerShell):**
Run this command in PowerShell
```powershell
.\create.ps1
```

> 💡 If PowerShell blocks the script, run first:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

The script will ask for:
- **App name** (single word, e.g. `donation`)
- **DB name** (optional, default: `donation_db`)
- **Owner** (your GitLab username)

After the script finishes, your project is ready at `./miniapp_donation_service/`.

### Step 4 — Follow the full guide

👉 **[GETTING_STARTED.md](GETTING_STARTED.md)**

---

## Need help?

| Issue | Contact |
|-------|---------|
| VPN | tailp@ghn.vn |
| GitLab account / repo | tiendk@ghn.vn |
| Platform / miniapp | binhtlt@ghn.vn |
