# Deploy Guide — Request VPN, GitLab & DB Access

> 📖 **Tiếng Việt:** Xem [DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md)

This guide covers the infra setup steps required before you can start building a miniapp.

---

## Step 1: Request VPN access

You need VPN to access all internal systems (GitLab, Postgres, etc.).

> ⏱ **Processing time:** 1–2 business days. Do this first!

### How to request

1. Go to: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Select:
   - **Nhóm quy trình:** Quy Trình Công Nghệ
   - **Quy trình:** IT - Yêu cầu cấp tài khoản VPN
3. Fill in: full name, department, company email
4. Contact for support: **tailp@ghn.vn**

### After VPN is approved

- Install the VPN client (instructions in the approval email)
- Connect VPN before doing anything else
- Verify by opening: `http://gitlab.ghn.vn`

---

## Step 2: Request GitLab account + repository

> Requires VPN to be connected.

### How to request

1. Go to: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Select:
   - **Nhóm quy trình:** Quy Trình Công Nghệ
   - **Quy trình:** IT - Yêu cầu cấp quyền truy cập dữ liệu VPN/File Server
3. Contact: **tiendk@ghn.vn**

### Information to provide

| Field | Example |
|-------|---------|
| Full name | Nguyen Van A |
| Company email | nguyenvana@ghn.vn |
| Repository name | `gtalk-miniapps/miniapp-library` |
| Access level | Developer (or Maintainer if you're the owner) |
| Team/department | Engineering - Mobile Platform |

> Repositories are created under the group `fe-mobile-platform/gtalk-miniapps/` on GitLab.

### Configure Git after account is created

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@ghn.vn"
```

---

## Step 3: Request DB access (if your miniapp needs a database)

> Skip this step if your miniapp doesn't need a database.

Contact your team lead or the infra team to:
1. Create a Postgres database named `<your_db_name>` on the shared instance
2. Grant VPN ACL access to the Postgres host (`fke-gtalk-pg-pgbouncer.ghn.dev:5432`)
3. Provide you with DB credentials (username/password)

**Information to provide:**
- Miniapp name
- DB name (e.g. `hr_leave_db`)
- Team/department

### After credentials are received

Update `conf/application-dev.yaml` in your project:

```yaml
service:
  noteDB:
    url: "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/<your_db_name>?connect_timeout=3"
```

> ⚠️ **Never commit credentials to git!** Use environment variables for test/stg/prod:
> ```yaml
> # conf/application-test.yaml
> service:
>   noteDB:
>     url: "${YOUR_DB_URL}"
> ```

---

## Troubleshooting

### GitLab connection error (401/403)

```
remote: HTTP Basic: Access denied
```

**Solution:**
1. Check VPN is connected
2. Check GitLab username/password
3. Create a Personal Access Token on GitLab and use it instead of your password

### Postgres connection error

```
failed to connect to host=fke-gtalk-pg-pgbouncer.ghn.dev
```

**Solution:**
1. Check VPN is connected
2. Check VPN ACL has been granted for the Postgres host
3. Check credentials in `conf/application-dev.yaml`

### pnpm not found

```bash
npm install -g pnpm
```

### Go module download fails

```bash
# Connect VPN first, then:
go mod tidy
```

---

## Contact

| Issue | Contact |
|-------|---------|
| VPN | tailp@ghn.vn |
| GitLab account / repo | tiendk@ghn.vn |
| Database / infra | Team lead or infra team |
| Platform / miniapp | binhtlt@ghn.vn |
