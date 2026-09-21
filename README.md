# frontMobile — nextplease Mobile

Ứng dụng di động (Flutter) cho **ứng viên** của nextplease: xem cơ hội việc làm
và quest, nộp đơn, quản lý portfolio.

Backend dùng chung với web — xem repo `backend`. App này không có backend riêng.

## Chạy thử

```bash
flutter pub get
flutter run
```

Backend phải đang chạy ở `localhost:8080`. Địa chỉ API tự chọn theo nền tảng
(xem `lib/core/config.dart`): simulator iOS dùng `localhost`, emulator Android
dùng `10.0.2.2`. Chạy trên máy thật thì truyền IP LAN:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8080
```

## Cấu trúc

```
lib/
  core/       cấu hình, lớp gọi API, theme (token lấy từ DESIGN.md)
  features/   chia theo tính năng
```
