# Getting Started — Build Your Miniapp

> 📖 **Tiếng Việt:** Xem [GETTING_STARTED.vi.md](GETTING_STARTED.vi.md)

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

## Steps at a glance

| Step | What | Requires |
|------|------|----------|
| 1 | Request VPN | Company email |
| 2 | Request GitLab account + repo | VPN |
| 3 | Request DB access (if needed) | VPN |
| 4 | Scaffold your project | VPN + Git |
| 5 | Configure DB | DB credentials |
| 6 | Run locally | Go, Node, pnpm |
| 7 | Push to GitLab | VPN + GitLab |
| 8 | Tag release (CI/CD) | GitLab |
| 9 | WebView integration (mobile) | — |

---

## Prerequisites

Install these tools on your machine:

| Tool | Version | Install |
|------|---------|---------|
| **Go** | 1.24+ | https://go.dev/dl/ |
| **Node.js** | 18+ | https://nodejs.org |
| **pnpm** | 8+ | `npm install -g pnpm` |
| **Git** | any | https://git-scm.com/downloads |
| **Make** | any | macOS: `xcode-select --install` · Linux: `apt install make` |

---

## Phase 1: Request VPN access

> **Do this first** — it takes 1–2 business days.

See **[DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) → Step 1** for detailed instructions.

Quick summary:
1. Go to: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Select: **Quy Trình Công Nghệ** → **IT - Yêu cầu cấp tài khoản VPN**
3. Contact: **tailp@ghn.vn**

---

## Phase 2: Request GitLab account + repository

> Requires VPN.

See **[DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) → Step 2** for detailed instructions.

Quick summary:
1. Go to: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Contact: **tiendk@ghn.vn**
3. Provide: full name, email, repo name (e.g. `miniapp_donation_service`), team

---

## Phase 3: Request DB access (if needed)

> Skip if your miniapp doesn't need a database.

See **[DEPLOY_GUIDE.md](DEPLOY_GUIDE.md) → Step 3** for detailed instructions.

Contact your team lead or infra team to create a Postgres DB and grant VPN ACL to `fke-gtalk-pg-pgbouncer.ghn.dev:5432`.

---

## Phase 4: Scaffold your project

### Configure Git (first time only)

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@ghn.vn"
```

**macOS / Linux / Git Bash:**
```bash
bash create.sh
```

**Windows (PowerShell):**
```powershell
.\create.ps1
```

> 💡 If PowerShell blocks the script, run first:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

Or use the scripts from this `docs/` folder directly (no need to clone):
```bash
# macOS/Linux
bash create.sh

# Windows PowerShell
.\create.ps1
```

The script will ask:

| Prompt | Example | Notes |
|--------|---------|-------|
| **App name** | `donation` | Single lowercase word. Becomes the miniapp ID and URL path. |
| **DB name** | `donation_db` | Press Enter to use the default. |
| **Owner** | `your.gitlab.username` | Your GitLab username. |
| **Directory** | `./miniapp_donation_service` | Where to create the project. |

The script automatically derives:
- Repo name: `miniapp_donation_service`
- Go module: `gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/miniapp_donation_service`
- URL path: `/apps/donation/`

---

## Phase 5: Configure the database

> Skip if your miniapp doesn't need a database.

Edit `conf/application-dev.yaml`:

```yaml
service:
  noteDB:
    url: "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/donation_db?connect_timeout=3"
```

Run the schema:

```bash
psql "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/donation_db" < schema/note.sql
```

> ⚠️ **Never commit credentials to git!** Use environment variables for test/stg/prod.

---

## Phase 6: Run locally

```bash
cd miniapp_donation_service
make run
```

Open **http://localhost:8082**

**Hot reload (frontend):**
```bash
# Terminal 1
make run-be-only

# Terminal 2
make fe-dev
# → http://localhost:5174
```

---

## Phase 7: Push to GitLab

```bash
cd miniapp_donation_service
git remote add origin http://gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/miniapp_donation_service.git
git push -u origin main
```

**Before every commit:**
```bash
make pre-commit
```

---

## Phase 8: Tag release (CI/CD)

```bash
git tag v0.1.0
git push origin v0.1.0
```

The pipeline will build the Docker image and open an MR on the host service to register your miniapp at `/apps/donation/`.

---

## Phase 9: WebView integration (mobile apps)

If your miniapp will be embedded in the iOS/Android gtalk app, ask the platform team for the WebView Native Bridge Integration guide.

---

## Makefile reference

| Command | Description |
|---------|-------------|
| `make run` | Build FE + start server (dev) |
| `make run-be-only` | Start server without rebuilding FE |
| `make fe-dev` | Start FE dev server with hot reload |
| `make build` | FE build + Go build (for CI) |
| `make pre-commit` | tidy + fmt + test + build |
| `make test` | Run Go tests |
| `make clean` | Remove build artifacts |

---

## FAQ

**Q: How do I rename the `note` domain to my own domain?**
Search and replace `note` / `Note` across the codebase. Main files:
- `internal/app/core/entity/note.go`
- `internal/app/core/service/note/`
- `internal/app/controller/note/`
- `schema/note.sql`
- `conf/application-*.yaml` (rename `noteDB` key)

**Q: My miniapp doesn't need a database.**
Comment out the `noteDB` section in `conf/application-dev.yaml` and remove DB init code in `miniapp.go` and `cmd/runner.go`.

**Q: 401/403 error when pushing to GitLab.**
1. Check VPN is connected
2. Check GitLab username/password
3. Try a Personal Access Token instead of password

---

## Help

| Issue | Contact |
|-------|---------|
| VPN | tailp@ghn.vn |
| GitLab | tiendk@ghn.vn |
| Platform | binhtlt@ghn.vn |
