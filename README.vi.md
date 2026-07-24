# Tạo Miniapp Mới — Starter Kit

> 📖 **English:** See [README.md](README.md)

Thư mục này chứa tất cả những gì bạn cần để tạo một miniapp mới trên nền tảng GHN gtalk.

---

## Nội dung thư mục

| File | Mô tả |
|------|-------|
| `create.sh/create.ps1` | Script tạo project miniapp mới |
| `GETTING_STARTED.md` | Hướng dẫn từng bước: VPN → GitLab → tạo project → chạy → push |
| `DEPLOY_GUIDE.md` | Cách xin cấp VPN, tài khoản GitLab, và quyền truy cập DB |

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

## Bắt đầu nhanh

### Bước 1 — Xin cấp VPN và tài khoản GitLab trước

Trước khi chạy script, bạn cần:
1. **VPN** — xem [DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md) → Bước 1
2. **Tài khoản GitLab + repository** — xem [DEPLOY_GUIDE.vi.md](DEPLOY_GUIDE.vi.md) → Bước 2

> ⏱ Xin cấp VPN mất 1–2 ngày làm việc. Hãy làm sớm!

### Bước 2 — Clone template repo (cần VPN)

```bash
git clone https://github.com/ghntech/gtalk-create-miniapp.git
```

### Bước 3 — Chạy script tạo project

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

Script sẽ hỏi:
- **Tên app** (một từ, ví dụ: `donation`)
- **Tên DB** (không bắt buộc, mặc định: `donation_db`)
- **Owner** (username GitLab của bạn)

Sau khi script chạy xong, project của bạn sẵn sàng tại `./miniapp_donation_service/`.

### Bước 4 — Xem hướng dẫn đầy đủ

👉 **[GETTING_STARTED.vi.md](GETTING_STARTED.vi.md)**

---

## Cần hỗ trợ?

| Vấn đề | Liên hệ |
|--------|---------|
| VPN | tailp@ghn.vn |
| Tài khoản GitLab / repo | tiendk@ghn.vn |
| Platform / miniapp | binhtlt@ghn.vn |
