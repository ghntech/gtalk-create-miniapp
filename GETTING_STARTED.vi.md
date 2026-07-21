# Hướng Dẫn Bắt Đầu — Tạo Miniapp

> 📖 **English:** See [GETTING_STARTED.md](GETTING_STARTED.md)

---

## Quy tắc đặt tên

| | Giá trị | Ví dụ |
|-|---------|-------|
| **Tên app** | Một từ, chữ thường | `donation` |
| **Tên repo** | `miniapp_<appname>_service` | `miniapp_donation_service` |
| **Miniapp ID** | `<appname>` | `donation` |
| **URL** | `https://gtalk-miniapp.ghn.vn/apps/<appname>/` | `.../apps/donation/` |
| **Tên DB** | `<appname>_db` | `donation_db` |

---

## Tổng quan các bước

| Bước | Nội dung | Yêu cầu |
|------|----------|---------|
| 1 | Xin cấp VPN | Email công ty |
| 2 | Xin tài khoản GitLab + repo | VPN |
| 3 | Xin quyền truy cập DB (nếu cần) | VPN |
| 4 | Tạo project từ template | VPN + Git |
| 5 | Cấu hình DB | Credentials DB |
| 6 | Chạy local | Go, Node, pnpm |
| 7 | Push lên GitLab | VPN + GitLab |
| 8 | Tag release (CI/CD) | GitLab |
| 9 | Tích hợp WebView (mobile) | — |

---

## Công cụ cần cài đặt

| Công cụ | Phiên bản | Cài đặt |
|---------|-----------|---------|
| **Go** | 1.24+ | https://go.dev/dl/ |
| **Node.js** | 18+ | https://nodejs.org |
| **pnpm** | 8+ | `npm install -g pnpm` |
| **Git** | bất kỳ | https://git-scm.com/downloads |
| **Make** | bất kỳ | macOS: `xcode-select --install` · Linux: `apt install make` |

---

## Bước 1: Xin cấp VPN

> **Làm bước này trước** — mất 1–2 ngày làm việc.

Xem **[DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md) → Bước 1** để biết chi tiết.

Tóm tắt:
1. Truy cập: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Chọn: **Quy Trình Công Nghệ** → **IT - Yêu cầu cấp tài khoản VPN**
3. Liên hệ: **tailp@ghn.vn**

---

## Bước 2: Xin tài khoản GitLab + repository

> Cần kết nối VPN.

Xem **[DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md) → Bước 2** để biết chi tiết.

Tóm tắt:
1. Truy cập: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Liên hệ: **tiendk@ghn.vn**
3. Cung cấp: họ tên, email, tên repo (ví dụ: `miniapp_donation_service`), team

---

## Bước 3: Xin quyền truy cập DB (nếu cần)

> Bỏ qua nếu miniapp không cần database.

Xem **[DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md) → Bước 3** để biết chi tiết.

Liên hệ team lead hoặc infra team để tạo Postgres DB và cấp VPN ACL đến `fke-gtalk-pg-pgbouncer.ghn.dev:5432`.

---

## Bước 4: Tạo project từ template

### Cấu hình Git (lần đầu)

```bash
git config --global user.name "Họ Tên"
git config --global user.email "email@ghn.vn"
```

### Clone template và chạy script

```bash
# Clone template repo (cần VPN)
git clone http://gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/gtalk-create-miniapp.git
cd gtalk-create-miniapp
```

**macOS / Linux / Git Bash:**
```bash
bash create.sh
```

**Windows (PowerShell):**
```powershell
.\create.ps1
```

> 💡 Nếu PowerShell báo lỗi bảo mật, chạy lệnh này trước:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

Hoặc dùng script từ thư mục `docs/` này (không cần clone):
```bash
# macOS/Linux
bash create.sh

# Windows PowerShell
.\create.ps1
```

Script sẽ hỏi:

| Câu hỏi | Ví dụ | Ghi chú |
|---------|-------|---------|
| **Tên app** | `donation` | Một từ, chữ thường. Sẽ là miniapp ID và URL path. |
| **Tên DB** | `donation_db` | Nhấn Enter để dùng tên mặc định. |
| **Owner** | `your.gitlab.username` | Username GitLab của bạn. |
| **Thư mục** | `./miniapp_donation_service` | Nơi tạo project. |

Script tự động tạo:
- Tên repo: `miniapp_donation_service`
- Go module: `gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/miniapp_donation_service`
- URL path: `/apps/donation/`

---

## Bước 5: Cấu hình database

> Bỏ qua nếu miniapp không cần database.

Sửa `conf/application-dev.yaml`:

```yaml
service:
  noteDB:
    url: "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/donation_db?connect_timeout=3"
```

Chạy schema:

```bash
psql "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/donation_db" < schema/note.sql
```

> ⚠️ **Không commit credentials vào git!** Dùng environment variable cho test/stg/prod.

---

## Bước 6: Chạy local

```bash
cd miniapp_donation_service
make run
```

Mở **http://localhost:8082**

**Hot reload (frontend):**
```bash
# Terminal 1
make run-be-only

# Terminal 2
make fe-dev
# → http://localhost:5174
```

---

## Bước 7: Push lên GitLab

```bash
cd miniapp_donation_service
git remote add origin http://gitlab.ghn.vn/fe-mobile-platform/gtalk-miniapps/miniapp_donation_service.git
git push -u origin main
```

**Trước mỗi lần commit:**
```bash
make pre-commit
```

---

## Bước 8: Tag release (CI/CD)

```bash
git tag v0.1.0
git push origin v0.1.0
```

Pipeline sẽ tự động build Docker image và mở MR trên host service để đăng ký miniapp tại `/apps/donation/`.

---

## Bước 9: Tích hợp WebView (mobile)

Nếu miniapp sẽ được nhúng vào app iOS/Android gtalk, liên hệ platform team để nhận tài liệu WebView Native Bridge Integration.

---

## Tham khảo Makefile

| Lệnh | Mô tả |
|------|-------|
| `make run` | Build FE + khởi động server (dev) |
| `make run-be-only` | Khởi động server không rebuild FE |
| `make fe-dev` | Khởi động FE dev server với hot reload |
| `make build` | FE build + Go build (cho CI) |
| `make pre-commit` | tidy + fmt + test + build |
| `make test` | Chạy Go tests |
| `make clean` | Xóa build artifacts |

---

## FAQ

**Q: Làm sao đổi tên domain `note` thành domain của tôi?**
Tìm và thay thế `note` / `Note` trong toàn bộ codebase. Các file chính:
- `internal/app/core/entity/note.go`
- `internal/app/core/service/note/`
- `internal/app/controller/note/`
- `schema/note.sql`
- `conf/application-*.yaml` (đổi tên key `noteDB`)

**Q: Miniapp của tôi không cần database.**
Comment out phần `noteDB` trong `conf/application-dev.yaml` và xóa code khởi tạo DB trong `miniapp.go` và `cmd/runner.go`.

**Q: Lỗi 401/403 khi push lên GitLab.**
1. Kiểm tra VPN đang kết nối
2. Kiểm tra username/password GitLab
3. Thử dùng Personal Access Token thay password

---

## Liên hệ hỗ trợ

| Vấn đề | Liên hệ |
|--------|---------|
| VPN | tailp@ghn.vn |
| GitLab | tiendk@ghn.vn |
| Platform | binhtlt@ghn.vn |
