/// Phiên bản văn bản pháp lý hiện hành.
///
/// PHẢI KHỚP với LEGAL_VERSION trong FE/src/lib/legalDocuments.js. Bản ghi
/// đồng ý lưu đúng chuỗi này, nên hai bên lệch nhau nghĩa là cùng một người
/// bị hỏi lại mỗi lần đổi giữa web và app — hoặc tệ hơn, app ghi nhận đồng ý
/// với một phiên bản không tồn tại.
const kLegalVersion = '2026-06-29';

/// Những điểm người dùng thực sự cần biết trước khi bấm đồng ý.
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

class LegalSection {
  const LegalSection({
    required this.id,
    required this.heading,
    required this.paragraphs,
    this.bulletPoints,
  });

  final String id;
  final String heading;
  final List<String> paragraphs;
  final List<String>? bulletPoints;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updated,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String updated;
  final String intro;
  final List<LegalSection> sections;
}

const kTermsDoc = LegalDocument(
  title: 'Điều khoản dịch vụ',
  updated: '29 tháng 6, 2026',
  intro:
      'Điều khoản này quy định quyền và nghĩa vụ khi bạn sử dụng nền tảng fonlio. Vui lòng đọc kỹ trước khi sử dụng tài khoản.',
  sections: [
    LegalSection(
      id: 'chap-nhan',
      heading: '1. Chấp nhận điều khoản',
      paragraphs: [
        'Bằng việc tạo tài khoản hoặc sử dụng nền tảng fonlio ("Nền tảng"), bạn đồng ý với các Điều khoản dịch vụ này. Nếu bạn không đồng ý, vui lòng ngừng sử dụng Nền tảng.',
        'Điều khoản áp dụng cho cả ứng viên (sinh viên) và đối tác (doanh nghiệp, câu lạc bộ, tổ chức).',
      ],
    ),
    LegalSection(
      id: 'tai-khoan',
      heading: '2. Tài khoản & đăng ký',
      paragraphs: [
        'Bạn chịu trách nhiệm về tính chính xác của thông tin đăng ký và bảo mật mật khẩu của mình.',
      ],
      bulletPoints: [
        'Mỗi người dùng chỉ nên sở hữu một tài khoản ứng viên.',
        'Tài khoản đối tác cần cung cấp minh chứng pháp lý (giấy phép kinh doanh, quyết định thành lập CLB) để được xác minh.',
        'Bạn phải đủ tuổi tham gia lao động/hoạt động theo quy định pháp luật Việt Nam.',
      ],
    ),
    LegalSection(
      id: 'proof',
      heading: '3. Hệ thống uy tín (RS, EXP, NP)',
      paragraphs: [
        'Điểm uy tín (RS), kinh nghiệm (EXP) và số dư NP đều do hệ thống kiểm soát qua nhật ký sự kiện, minh bạch và có thể kiểm chứng. Người dùng không được tự khai hay can thiệp các chỉ số này.',
        'Mọi minh chứng (proof) phải trung thực. Hành vi gian lận, làm giả minh chứng có thể dẫn tới khoá tài khoản và thu hồi điểm/thưởng liên quan.',
      ],
    ),
    LegalSection(
      id: 'noi-dung',
      heading: '4. Nội dung người dùng',
      paragraphs: [
        'Bạn giữ quyền sở hữu với nội dung mình đăng tải (hồ sơ, minh chứng, mô tả). Khi đăng tải, bạn cấp cho Nền tảng quyền lưu trữ và hiển thị nội dung đó nhằm vận hành dịch vụ.',
        'Bạn không được đăng nội dung vi phạm pháp luật, xâm phạm quyền của bên thứ ba, spam hoặc gây hiểu nhầm.',
      ],
    ),
    LegalSection(
      id: 'doi-tac',
      heading: '5. Quyền & nghĩa vụ đối tác',
      paragraphs: [
        'Đối tác đăng tin tuyển dụng, Quest và quản lý ứng viên có trách nhiệm cung cấp thông tin chính xác về cơ hội, thù lao và quyền lợi.',
        'Việc đánh giá và trao thưởng ứng viên phải dựa trên kết quả công việc thực tế, công bằng và đúng quy tắc của Nền tảng.',
      ],
    ),
    LegalSection(
      id: 'thanh-toan',
      heading: '6. NP, Premium & thanh toán',
      paragraphs: [
        'NP là đơn vị quy đổi nội bộ dùng cho một số tính năng (vd gói Premium). Các giao dịch nạp NP và mua Premium tuân theo mô tả tại thời điểm giao dịch.',
        'Trừ khi pháp luật yêu cầu khác, các khoản đã sử dụng cho dịch vụ là không hoàn lại.',
      ],
    ),
    LegalSection(
      id: 'dinh-chi',
      heading: '7. Đình chỉ & chấm dứt',
      paragraphs: [
        'Chúng tôi có thể tạm ngưng hoặc chấm dứt tài khoản vi phạm Điều khoản, gian lận, hoặc gây rủi ro cho người dùng khác.',
        'Bạn có thể ngừng sử dụng và yêu cầu xoá tài khoản bất kỳ lúc nào.',
      ],
    ),
    LegalSection(
      id: 'trach-nhiem',
      heading: '8. Giới hạn trách nhiệm',
      paragraphs: [
        'Nền tảng đóng vai trò kết nối ứng viên và đối tác. Chúng tôi không phải là một bên trong quan hệ lao động giữa hai phía và không bảo đảm kết quả tuyển dụng cụ thể.',
        'Dịch vụ được cung cấp trên cơ sở "nguyên trạng"; chúng tôi nỗ lực vận hành ổn định nhưng không bảo đảm không gián đoạn.',
      ],
    ),
    LegalSection(
      id: 'thay-doi',
      heading: '9. Thay đổi điều khoản',
      paragraphs: [
        'Chúng tôi có thể cập nhật Điều khoản theo thời gian. Khi có thay đổi quan trọng, chúng tôi sẽ thông báo trên Nền tảng. Việc bạn tiếp tục sử dụng đồng nghĩa với chấp nhận bản cập nhật.',
      ],
    ),
    LegalSection(
      id: 'lien-he',
      heading: '10. Liên hệ',
      paragraphs: [
        'Mọi thắc mắc về Điều khoản, vui lòng liên hệ: fonlioofficial@gmail.com.',
      ],
    ),
  ],
);

const kPrivacyDoc = LegalDocument(
  title: 'Chính sách bảo mật',
  updated: '29 tháng 6, 2026',
  intro:
      'Chính sách này mô tả cách fonlio thu thập, sử dụng và bảo vệ dữ liệu cá nhân của bạn.',
  sections: [
    LegalSection(
      id: 'thu-thap',
      heading: '1. Dữ liệu chúng tôi thu thập',
      paragraphs: [
        'Chúng tôi thu thập dữ liệu bạn cung cấp và dữ liệu phát sinh khi sử dụng Nền tảng:',
      ],
      bulletPoints: [
        'Thông tin tài khoản: tên hiển thị, email, email sinh viên, mật khẩu (được mã hoá).',
        'Hồ sơ năng lực: kỹ năng, học vấn, minh chứng (proof), chứng chỉ, kinh nghiệm.',
        'Dữ liệu hoạt động: điểm RS, EXP, NP, lịch sử ứng tuyển và Quest.',
        'Với đối tác: thông tin tổ chức, giấy tờ pháp lý phục vụ xác minh.',
      ],
    ),
    LegalSection(
      id: 'muc-dich',
      heading: '2. Mục đích sử dụng',
      paragraphs: [
        'Chúng tôi dùng dữ liệu để: vận hành tài khoản, xác minh proof, kết nối ứng viên với cơ hội phù hợp, tính toán RS/EXP/NP, gửi thông báo liên quan và cải thiện dịch vụ.',
        'Chúng tôi không bán dữ liệu cá nhân của bạn cho bên thứ ba.',
      ],
    ),
    LegalSection(
      id: 'co-so',
      heading: '3. Cơ sở xử lý & sự đồng ý',
      paragraphs: [
        'Chúng tôi xử lý dữ liệu trên cơ sở sự đồng ý của bạn khi đăng ký, và để thực hiện dịch vụ bạn yêu cầu. Bạn có thể rút lại đồng ý bằng cách yêu cầu xoá tài khoản.',
      ],
    ),
    LegalSection(
      id: 'chia-se',
      heading: '4. Chia sẻ dữ liệu',
      paragraphs: [
        'Một số dữ liệu được chia sẻ có chủ đích nhằm vận hành dịch vụ:',
      ],
      bulletPoints: [
        'Hồ sơ và proof của ứng viên được hiển thị cho đối tác khi bạn ứng tuyển hoặc bật chế độ hiển thị.',
        'Tổ chức liên quan có thể xác nhận minh chứng công việc bạn đã tham gia.',
        'Nhà cung cấp hạ tầng (lưu trữ, email) xử lý dữ liệu thay chúng tôi theo hợp đồng bảo mật.',
      ],
    ),
    LegalSection(
      id: 'luu-tru',
      heading: '5. Lưu trữ & bảo mật',
      paragraphs: [
        'Dữ liệu được lưu trữ trên hạ tầng đám mây có biện pháp bảo mật phù hợp. Mật khẩu được mã hoá và không lưu ở dạng văn bản thuần.',
        'Chúng tôi giữ dữ liệu trong thời gian tài khoản còn hoạt động hoặc theo yêu cầu pháp luật.',
      ],
    ),
    LegalSection(
      id: 'quyen',
      heading: '6. Quyền của bạn',
      paragraphs: [
        'Bạn có quyền: truy cập, chỉnh sửa, xuất hoặc yêu cầu xoá dữ liệu cá nhân của mình. Hãy liên hệ chúng tôi để thực hiện các quyền này.',
      ],
    ),
    LegalSection(
      id: 'cookie',
      heading: '7. Cookie & lưu trữ cục bộ',
      paragraphs: [
        'Chúng tôi dùng cookie và bộ nhớ trình duyệt (localStorage) cho các mục đích cần thiết như giữ đăng nhập, ghi nhớ tuỳ chọn giao diện (sáng/tối) và một số tiến trình trải nghiệm.',
      ],
    ),
    LegalSection(
      id: 'tre-vi-thanh-nien',
      heading: '8. Người chưa thành niên',
      paragraphs: [
        'Nền tảng hướng tới sinh viên và người dùng đủ tuổi tham gia hoạt động/lao động theo quy định. Nếu bạn dưới độ tuổi cho phép, vui lòng có sự đồng ý của người giám hộ.',
      ],
    ),
    LegalSection(
      id: 'thay-doi',
      heading: '9. Thay đổi chính sách',
      paragraphs: [
        'Chính sách có thể được cập nhật. Khi có thay đổi quan trọng, chúng tôi sẽ thông báo trên Nền tảng và cập nhật ngày ở đầu trang.',
      ],
    ),
    LegalSection(
      id: 'lien-he',
      heading: '10. Liên hệ',
      paragraphs: [
        'Câu hỏi về quyền riêng tư, vui lòng liên hệ: fonlioofficial@gmail.com.',
      ],
    ),
  ],
);

