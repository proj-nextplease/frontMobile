// Các tính năng ứng viên vừa đưa từ web sang app: loại hình/cấp bậc kinh
// nghiệm, giao diện website, bằng cấp & chứng chỉ, và lưu hồ sơ không làm mất
// dữ liệu khác. Máy chủ giả bắt đúng yêu cầu PUT /profiles/me gửi lên.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextplease_mobile/core/api_client.dart';
import 'package:nextplease_mobile/core/theme.dart';
import 'package:nextplease_mobile/features/discussions/discussion_models.dart';
import 'package:nextplease_mobile/features/profile/edit_credentials_page.dart';
import 'package:nextplease_mobile/features/profile/edit_experience_page.dart';
import 'package:nextplease_mobile/features/profile/me_store.dart';

/// Hồ sơ "trên máy chủ": có cả trường chỉ-đọc lẫn dữ liệu web đã lưu
/// (ảnh chân dung, chứng chỉ PDF, giao diện) — những thứ app không được làm mất.
Map<String, dynamic> _serverProfile() => {
      'name': 'Nghê Tài Phát',
      'headline': 'Sinh viên',
      'skills': ['Java'],
      'avatar': {'mascot': 'boy', 'portraitUrl': 'data:image/jpeg;base64,AAAA'},
      'selectedTheme': 'PURPLE_AURA',
      'reputationScore': 15,
      'totalExp': 300,
      'avatarUrl': 'https://lh3.googleusercontent.com/a/x=s96-c',
      'publicSlug': 'phat',
      'isExported': true,
      'exportCount': 2,
      'experiences': [
        {
          'id': 'e1',
          'title': 'Developer',
          'organization': 'FPT',
          'detail': 'mô tả',
          'startDate': '06/2026',
          'endDate': '08/2026',
          'category': 'SCHOOL_CAMPAIGN',
          'roleLevel': 'MEMBER',
          'verified': true,
        }
      ],
      'credentials': [
        {
          'id': 'c1',
          'name': 'IELTS 7.0',
          'issuer': 'British Council',
          'issuedAt': '05/25',
          'fileName': 'ielts.pdf',
          'fileData': 'data:application/pdf;base64,JVBERi0=',
          'fileType': 'application/pdf',
        }
      ],
    };

class _Server {
  _Server() {
    MeStore.instance.api = ApiClient(client: MockClient(_handle));
  }

  Map<String, dynamic> profile = _serverProfile();
  final puts = <Map<String, dynamic>>[];

  Future<http.Response> _handle(http.Request r) async {
    final path = r.url.path;
    if (path.endsWith('/profiles/me') && r.method == 'GET') {
      return _ok(profile);
    }
    if (path.endsWith('/profiles/me') && r.method == 'PUT') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      puts.add(body);
      profile = {...profile, ...body};
      return _ok('ok');
    }
    return http.Response(jsonEncode({'success': false, 'message': 'not found'}), 404);
  }

  http.Response _ok(Object data) => http.Response(
      jsonEncode({'success': true, 'data': data}), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

Widget _app(Widget child) =>
    MaterialApp(theme: buildNpTheme(Brightness.light), home: child);

Future<_Server> _ready() async {
  final s = _Server();
  await MeStore.instance.hydrate();
  return s;
}

void main() {
  group('MeStore.saveWith', () {
    test('đổi giao diện: gửi selectedTheme, giữ mọi dữ liệu khác, bỏ trường chỉ-đọc',
        () async {
      final s = await _ready();
      await MeStore.instance.saveWith({'selectedTheme': 'NHO_NEON'});
      final body = s.puts.single;
      expect(body['selectedTheme'], 'NHO_NEON');
      expect((body['avatar'] as Map)['portraitUrl'], 'data:image/jpeg;base64,AAAA');
      expect((body['credentials'] as List).single['fileData'], startsWith('data:application/pdf'));
      expect((body['experiences'] as List).single['category'], 'SCHOOL_CAMPAIGN');
      for (final k in ['reputationScore', 'totalExp', 'avatarUrl', 'publicSlug', 'isExported', 'exportCount']) {
        expect(body.containsKey(k), isFalse, reason: k);
      }
      expect(MeStore.instance.selectedTheme, 'NHO_NEON');
    });

    test('lưu thứ khác thì KHÔNG gửi selectedTheme (máy chủ giữ nguyên)', () async {
      final s = await _ready();
      await MeStore.instance.saveWith({'headline': 'Mới'});
      expect(s.puts.single.containsKey('selectedTheme'), isFalse);
    });

    test('mã giao diện cũ hiển thị như Cốm Neon', () async {
      final s = _Server()..profile['selectedTheme'] = 'DARK_GOLD';
      await MeStore.instance.hydrate();
      expect(MeStore.instance.selectedTheme, 'FOMLIO');
      expect(s.puts, isEmpty);
    });
  });

  group('Kinh nghiệm: loại hình & cấp bậc', () {
    testWidgets('mục mới gửi đúng loại hình và cấp bậc đã chọn', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_app(const EditExperiencePage()));
      await tester.tap(find.text('Thêm mục kinh nghiệm'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Trưởng ban');
      await tester.enterText(fields.at(1), 'CLB ABC');
      await tester.enterText(fields.at(4), 'Tổ chức sự kiện');
      await tester.pump();
      await tester.ensureVisible(find.text('Dự án Doanh nghiệp (+500 EXP)'));
      await tester.tap(find.text('Dự án Doanh nghiệp (+500 EXP)'));
      await tester.tap(find.text('Trưởng nhóm / Ban (+10 RS khi duyệt)'));
      await tester.pump();
      await tester.ensureVisible(find.text('Xong'));
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      final exps = (s.puts.single['experiences'] as List).cast<Map>();
      final added = exps.firstWhere((e) => e['title'] == 'Trưởng ban');
      expect(added['category'], 'COMPANY_PROJECT');
      expect(added['roleLevel'], 'LEADER');
      // Mục cũ đã duyệt vẫn được gửi lại nguyên vẹn.
      expect(exps.firstWhere((e) => e['id'] == 'e1')['category'], 'SCHOOL_CAMPAIGN');
    });

    testWidgets('mục đã duyệt không đổi được loại hình', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_app(const EditExperiencePage()));
      await tester.tap(find.text('Developer'));
      await tester.pumpAndSettle();
      expect(find.text('Mục đã được duyệt nên không đổi loại hình và cấp bậc được nữa.'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Công việc tự do (+500 EXP)'));
      await tester.tap(find.text('Công việc tự do (+500 EXP)'));
      await tester.pump();
      await tester.ensureVisible(find.text('Xong'));
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      final e1 = (s.puts.single['experiences'] as List).cast<Map>().single;
      expect(e1['category'], 'SCHOOL_CAMPAIGN');
    });
  });

  group('Bằng cấp & chứng chỉ', () {
    testWidgets('thêm chứng chỉ: tự chèn "/", chặn tháng tương lai, giữ tệp PDF cũ',
        (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_app(const EditCredentialsPage()));
      expect(find.text('IELTS 7.0'), findsOneWidget);
      await tester.tap(find.text('Thêm chứng chỉ'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Google UX Design');
      await tester.enterText(fields.at(1), 'Coursera');
      await tester.enterText(fields.at(2), '1299');
      await tester.pump();
      expect(find.text('Thời gian cấp không được sau tháng hiện tại'), findsOneWidget);

      await tester.enterText(fields.at(2), '0626');
      await tester.pump();
      final ctrl = tester.widget<TextField>(fields.at(2)).controller!;
      expect(ctrl.text, '06/26');
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      final creds = (s.puts.single['credentials'] as List).cast<Map>();
      expect(creds, hasLength(2));
      final added = creds.firstWhere((c) => c['name'] == 'Google UX Design');
      expect(added['issuer'], 'Coursera');
      expect(added['issuedAt'], '06/26');
      expect((added['id'] as String).isNotEmpty, isTrue);
      expect(creds.firstWhere((c) => c['id'] == 'c1')['fileData'], startsWith('data:application/pdf'));
    });

    testWidgets('xoá chứng chỉ', (tester) async {
      final s = await _ready();
      await tester.pumpWidget(_app(const EditCredentialsPage()));
      await tester.tap(find.byTooltip('Xoá'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(s.puts.single['credentials'], isEmpty);
    });
  });

  test('chủ đề thảo luận đọc và đổi trạng thái theo dõi', () {
    final t = DiscussionTopic.fromJson({'id': 'x', 'slug': 's', 'name': 'N', 'isFollowing': true});
    expect(t.isFollowing, isTrue);
    expect(t.copyWith(isFollowing: false).isFollowing, isFalse);
    expect(t.copyWith(isFollowing: false).name, 'N');
  });
}
