# Đăng ký tài khoản Digital Ocean

[![DigitalOcean Referral Badge](https://web-platforms.sfo2.cdn.digitaloceanspaces.com/WWW/Badge%201.svg)](https://www.digitalocean.com/?refcode=e0496d81b971&utm_campaign=Referral_Invite&utm_medium=Referral_Program&utm_source=badge)

# Cài đặt n8n Docker với Caddy và Cloudflare SSL

Hướng dẫn đầy đủ để thiết lập n8n với Docker, Caddy reverse proxy, và chứng chỉ SSL Cloudflare trên Ubuntu.

## 🚀 Hướng dẫn Cài đặt

### Bước 1: Chuẩn bị Máy chủ

#### Tạo người dùng chuyên dụng (khuyến nghị cho bảo mật)
```bash
# Kết nối đến máy chủ với quyền root
sudo adduser n8n-admin
sudo usermod -aG sudo n8n-admin
```

#### Chuyển sang người dùng mới
```bash
su - n8n-admin
```

### Bước 2: Chuẩn bị Chứng chỉ SSL (Cloudflare)

Trước khi cài đặt, bạn cần chứng chỉ SSL từ Cloudflare:

1. **Đăng nhập vào Cloudflare Dashboard**
   - Truy cập [Cloudflare Dashboard](https://dash.cloudflare.com)
   - Chọn domain của bạn

2. **Cấu hình chế độ mã hóa SSL/TLS**
   - Điều hướng đến `SSL/TLS` → `Overview`
   - Đặt chế độ mã hóa thành `Full (strict)`
   - Điều này đảm bảo mã hóa end-to-end giữa Cloudflare và máy chủ gốc của bạn

3. **Tạo Origin Certificate**
   - Điều hướng đến `SSL/TLS` → `Origin Server`
   - Nhấn `Create Certificate`
   - Nhấn `Create`

4. **Lưu các tệp chứng chỉ**
   - Sao chép nội dung **Certificate** (giữ sẵn)
   - Sao chép nội dung **Private Key** (giữ sẵn)
   - Bạn sẽ cần những thông tin này trong quá trình cài đặt

### Bước 3: Cấu hình DNS (Cloudflare)

Thiết lập bản ghi DNS cho subdomain n8n của bạn:

1. **Trong Cloudflare Dashboard**
   - Đi đến `DNS` → `Records`
   - Thêm bản ghi `A` mới:
     - **Name**: `n8n` (hoặc subdomain mà bạn muốn)
     - **IPv4 address**: IP công cộng của máy chủ
     - **Proxy status**: 🟠 Proxied (khuyến nghị)
   - Nhấn `Save`

### Bước 4: Tải xuống và Chuẩn bị Script Cài đặt

```bash
# Tải xuống các tệp cài đặt
git clone https://github.com/trungpv1601/n8n-docker-cloudflare-setup
cd n8n-docker-cloudflare-setup

# Làm cho script cài đặt có thể thực thi
chmod +x install.sh
chmod +x update.sh
```

### Bước 5: Chạy Cài đặt

**Quan trọng**: Chuẩn bị sẵn chứng chỉ SSL và private key trước khi chạy script.

```bash
# Chạy script cài đặt
sudo ./install.sh
```

Trong quá trình cài đặt, bạn sẽ được yêu cầu nhập:
- **Tên domain**: `yourdomain.com`
- **Subdomain**: `n8n` (hoặc theo lựa chọn của bạn)
- **Chứng chỉ SSL**: Dán chứng chỉ từ Cloudflare
- **Private Key**: Dán private key từ Cloudflare

### Bước 6: Truy cập n8n
   - Mở trình duyệt
   - Điều hướng đến `https://n8n.yourdomain.com`
   - Hoàn thành thiết lập ban đầu của n8n

## 🔄 Cập nhật n8n

Thiết lập bao gồm script cập nhật tự động để xử lý việc sao lưu dữ liệu, cập nhật containers, và cung cấp khả năng rollback.

### Lệnh Cập nhật

#### Cập nhật Đầy đủ (Khuyến nghị)
Tạo bản sao lưu và cập nhật lên phiên bản mới nhất:
```bash
sudo ./update.sh
```

#### Cập nhật Nhanh
```bash
# Cập nhật mà không tạo bản sao lưu
sudo ./update.sh --no-backup

# Buộc cập nhật mà không cần xác nhận
sudo ./update.sh --force

# Xem những gì sẽ được cập nhật mà không thực hiện thay đổi
sudo ./update.sh --dry-run
```

#### Quản lý Sao lưu
```bash
# Chỉ tạo bản sao lưu (không cập nhật)
sudo ./update.sh --backup-only

# Chỉ cập nhật containers (không sao lưu)
sudo ./update.sh --update-only
```

#### Rollback và Khôi phục
```bash
# Liệt kê tất cả bản sao lưu có sẵn
sudo ./update.sh --rollback

# Rollback đến một bản sao lưu cụ thể
sudo ./update.sh --rollback 20231201_120000

# Xem trợ giúp và tất cả các tùy chọn
sudo ./update.sh --help
```

### Quy trình Cập nhật

Khi bạn chạy cập nhật đầy đủ, script sẽ:

1. **Tạo Bản sao lưu**: Tự động sao lưu dữ liệu và cấu hình n8n
2. **Pull Latest Images**: Tải xuống các Docker images n8n và Caddy mới nhất
3. **Cập nhật Containers**: Tạo lại containers với images mới
4. **Kiểm tra Trạng thái**: Kiểm tra xem mọi thứ có chạy đúng không
5. **Dọn dẹp**: Xóa các bản sao lưu cũ (giữ lại 5 bản gần nhất)

### Vị trí Sao lưu

Các bản sao lưu được lưu trữ trong thư mục `./backups/` và bao gồm:
- Dữ liệu workflow và cài đặt n8n
- Cấu hình và chứng chỉ Caddy
- Biến môi trường và cấu hình Docker
- Metadata sao lưu với thông tin phiên bản

---

**⚠️ Quan trọng**: Giữ bảo mật private key SSL của bạn và không bao giờ chia sẻ công khai!
