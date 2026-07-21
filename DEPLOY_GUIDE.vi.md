# Hướng Dẫn Deploy — Xin Cấp VPN, GitLab & DB

> 📖 **English:** See [DEPLOY_GUIDE.md](DEPLOY_GUIDE.md)

Tài liệu này hướng dẫn các bước chuẩn bị hạ tầng cần thiết trước khi bắt đầu xây dựng miniapp.

---

## Bước 1: Xin Cấp VPN

Bạn cần VPN để truy cập tất cả hệ thống nội bộ (GitLab, Postgres, v.v.).

> ⏱ **Thời gian xử lý:** 1–2 ngày làm việc. Hãy làm bước này trước!

### Cách thực hiện

1. Truy cập: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Chọn:
   - **Nhóm quy trình:** Quy Trình Công Nghệ
   - **Quy trình:** IT - Yêu cầu cấp tài khoản VPN
3. Điền đầy đủ: họ tên, bộ phận, email công ty
4. Liên hệ hỗ trợ: **tailp@ghn.vn**

### Sau khi được cấp VPN

- Cài đặt VPN client theo hướng dẫn trong email phản hồi
- Kết nối VPN trước khi thực hiện các bước tiếp theo
- Kiểm tra kết nối bằng cách mở: `http://gitlab.ghn.vn`

---

## Bước 2: Xin Cấp Tài Khoản GitLab + Repository

> Cần kết nối VPN.

### Cách thực hiện

1. Truy cập: https://noibo.ghn.vn/eform/form/create?flowId=6676c752140753310e197f73
2. Chọn:
   - **Nhóm quy trình:** Quy Trình Công Nghệ
   - **Quy trình:** IT - Yêu cầu cấp quyền truy cập dữ liệu VPN/File Server
3. Liên hệ trực tiếp: **tiendk@ghn.vn**

### Thông tin cần cung cấp

| Thông tin | Ví dụ |
|-----------|-------|
| Họ và tên đầy đủ | Nguyễn Văn A |
| Email công ty | nguyenvana@ghn.vn |
| Tên repository | `gtalk-miniapps/miniapp-library` |
| Quyền truy cập | Developer (hoặc Maintainer nếu bạn là owner) |
| Bộ phận / team | Engineering - Mobile Platform |

> Repository sẽ được tạo trong group `fe-mobile-platform/gtalk-miniapps/` trên GitLab.

### Cấu hình Git sau khi có tài khoản

```bash
git config --global user.name "Họ Tên"
git config --global user.email "email@ghn.vn"
```

---

## Bước 3: Xin Quyền Truy Cập DB (nếu miniapp cần database)

> Bỏ qua bước này nếu miniapp không cần database.

Liên hệ team lead hoặc infra team để:
1. Tạo Postgres database tên `<your_db_name>` trên shared instance
2. Cấp VPN ACL đến Postgres host (`fke-gtalk-pg-pgbouncer.ghn.dev:5432`)
3. Cung cấp credentials (username/password)

**Thông tin cần cung cấp:**
- Tên miniapp
- Tên DB (ví dụ: `hr_leave_db`)
- Bộ phận / team

### Sau khi có credentials

Cập nhật `conf/application-dev.yaml` trong project:

```yaml
service:
  noteDB:
    url: "postgres://<user>:<password>@fke-gtalk-pg-pgbouncer.ghn.dev:5432/<your_db_name>?connect_timeout=3"
```

> ⚠️ **Không commit credentials vào git!** Dùng environment variable cho test/stg/prod:
> ```yaml
> # conf/application-test.yaml
> service:
>   noteDB:
>     url: "${YOUR_DB_URL}"
> ```

---

## Xử lý lỗi thường gặp

### Lỗi kết nối GitLab (401/403)

```
remote: HTTP Basic: Access denied
```

**Giải pháp:**
1. Kiểm tra VPN đang kết nối
2. Kiểm tra username/password GitLab
3. Tạo Personal Access Token trên GitLab và dùng thay password

### Lỗi kết nối Postgres

```
failed to connect to host=fke-gtalk-pg-pgbouncer.ghn.dev
```

**Giải pháp:**
1. Kiểm tra VPN đang kết nối
2. Kiểm tra VPN ACL đã được cấp cho Postgres host
3. Kiểm tra credentials trong `conf/application-dev.yaml`

### Lỗi pnpm không tìm thấy

```bash
npm install -g pnpm
```

### Lỗi download Go module

```bash
# Kết nối VPN trước, sau đó:
go mod tidy
```

---

## Liên hệ hỗ trợ

| Vấn đề | Liên hệ |
|--------|---------|
| VPN | tailp@ghn.vn |
| Tài khoản GitLab / repo | tiendk@ghn.vn |
| Database / infra | Team lead hoặc infra team |
| Platform / miniapp | binhtlt@ghn.vn |

---

*Tài liệu nội bộ — GHN GTalk Team*
