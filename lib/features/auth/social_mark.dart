import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'login_page.dart' show SocialProvider;

/// Logo ba nhà cung cấp, dùng path SVG chính thức.
///
/// Bản trước vẽ tay bằng CustomPainter và thất bại ở GitHub: Octocat rút gọn
/// thành hình tròn với hai tai đọc ra như con ma, không ai nhận ra là GitHub.
/// Logo thương hiệu là thứ người dùng nhận diện bằng phản xạ — vẽ gần đúng còn
/// tệ hơn không vẽ.
///
/// Path lấy từ bộ nhận diện chính thức của từng hãng. Không đổi màu, không bo
/// tròn, không lồng vào khung màu khác: điều khoản thương hiệu của cả ba đều
/// cấm, và ở đây cũng không có lý do thiết kế nào để làm vậy.
///
/// Ngoại lệ DUY NHẤT là GitHub: logo của họ đơn sắc và chính hãng phát hành cả
/// bản trắng cho nền tối. Để nguyên màu mực tối thì nó biến mất hoàn toàn trên
/// nền #0A0A0F — đúng lỗi đã xảy ra khi đổi app sang nền tối.
class SocialMark extends StatelessWidget {
  const SocialMark({super.key, required this.provider, this.size = 22});

  final SocialProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        switch (provider) {
          SocialProvider.google => _google,
          SocialProvider.facebook => _facebook,
          SocialProvider.github => _github,
        },
        width: size,
        height: size,
      );
}

const _google = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24s.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

const _facebook = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
<path fill="#1877F2" d="M24 12.07C24 5.4 18.63 0 12 0S0 5.4 0 12.07C0 18.1 4.39 23.09 10.13 24v-8.44H7.08v-3.49h3.05V9.41c0-3.02 1.79-4.69 4.53-4.69 1.31 0 2.68.24 2.68.24v2.97h-1.51c-1.49 0-1.96.93-1.96 1.89v2.25h3.33l-.53 3.49h-2.8V24C19.61 23.09 24 18.1 24 12.07z"/>
</svg>
''';

/// Octocat — path chính thức từ bộ octicons của GitHub.
const _github = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">
<path fill="#FAFAFA" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/>
</svg>
''';
