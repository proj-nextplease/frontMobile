/// Phiên bản văn bản pháp lý hiện hành.
///
/// PHẢI KHỚP với LEGAL_VERSION trong FE/src/lib/legalDocuments.js. Bản ghi
/// đồng ý lưu đúng chuỗi này, nên hai bên lệch nhau nghĩa là cùng một người
/// bị hỏi lại mỗi lần đổi giữa web và app — hoặc tệ hơn, app ghi nhận đồng ý
/// với một phiên bản không tồn tại.
///
/// Đây là một bản SAO, và bản sao thì trôi. Cách sửa đúng là backend trả về
/// phiên bản hiện hành trong /me hoặc /profiles/me để cả web lẫn app cùng đọc
/// một nguồn; tới lúc đó, đổi ở FE thì phải đổi cả ở đây.
const kLegalVersion = '2026-06-29';

/// Những điểm người dùng thực sự cần biết trước khi bấm đồng ý.
///
/// Đây là TÓM TẮT, không phải văn bản đầy đủ — và màn hình nói rõ như vậy.
/// Chép nguyên hai văn bản vào app là tạo bản sao thứ hai của thứ đã có một
/// bản sao; chúng sẽ lệch, và người dùng sẽ đồng ý với một văn bản khác với
/// văn bản đăng công khai. Nút mở bản đầy đủ nằm ngay dưới.
const kConsentPoints = <({String title, String body})>[
  (
    title: 'Điểm uy tín do hệ thống ghi nhận',
    body: 'RS, EXP và NP đều sinh ra từ nhật ký sự kiện. Bạn không tự khai '
        'được, và cũng không ai sửa tay được cho bạn.',
  ),
  (
    title: 'Minh chứng phải trung thực',
    body: 'Làm giả minh chứng có thể dẫn tới khoá tài khoản và thu hồi điểm '
        'thưởng liên quan.',
  ),
  (
    title: 'Hồ sơ công khai là do bạn chọn',
    body: 'Trang hồ sơ chỉ hiện những gì bạn đưa vào. Bạn bật hoặc tắt nó bất '
        'cứ lúc nào trong phần Hồ sơ.',
  ),
  (
    title: 'Dữ liệu của bạn',
    body: 'Chúng tôi dùng thông tin bạn cung cấp để gợi ý cơ hội phù hợp và '
        'để đối tác xem hồ sơ khi bạn ứng tuyển.',
  ),
];
