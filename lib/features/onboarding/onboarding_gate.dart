import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/mascot.dart';
import '../../core/theme.dart';
import '../profile/me_store.dart';
import '../profile/gamification_store.dart';

/// Cổng thiết lập hồ sơ ban đầu cho ứng viên mới.
///
/// Hoạt động theo mô hình 3 bước nhanh:
///   1. Linh vật & Thông tin cơ bản (Tên, Trường học)
///   2. Kỹ năng thế mạnh (Tags gợi ý + Thêm tự do)
///   3. Mục tiêu & Định hướng (Headline, Trạng thái tìm việc)
///
/// Có tuỳ chọn "Để sau" để người dùng không bị ép buộc nếu chỉ muốn dạo xem việc làm trước.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  final _me = MeStore.instance;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _me.addListener(_sync);
  }

  @override
  void dispose() {
    _me.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (mounted) setState(() {});
  }

  /// Chỉ hiện cổng khi:
  ///   - `enabled == true`
  ///   - `_me.loaded == true` (đã nạp xong hồ sơ)
  ///   - `_me.onboardingCompleted == false`
  ///   - Chưa bấm "Để sau" trong phiên hiện tại (`!_dismissed`)
  bool get _blocking {
    if (!widget.enabled || !_me.loaded || _dismissed) return false;
    return !_me.onboardingCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_blocking)
          Positioned.fill(
            child: _OnboardingWizardSheet(
              onDismiss: () => setState(() => _dismissed = true),
            ),
          ),
      ],
    );
  }
}

class _OnboardingWizardSheet extends StatefulWidget {
  const _OnboardingWizardSheet({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_OnboardingWizardSheet> createState() => _OnboardingWizardSheetState();
}

class _OnboardingWizardSheetState extends State<_OnboardingWizardSheet> {
  final _api = ApiClient();
  final _me = MeStore.instance;

  int _currentStep = 0;
  bool _saving = false;
  String? _error;

  late String _mascot = NpMascot.resolveId(_me.raw['avatar']);
  late final _name = TextEditingController(text: _me.name ?? '');
  late final _school = TextEditingController(text: _me.school ?? '');
  late final _headline = TextEditingController(text: _me.headline ?? '');
  final _skillInput = TextEditingController();

  late List<String> _skills = [
    if (_me.skillLabels.isNotEmpty) ..._me.skillLabels,
  ];

  bool _openToWork = true;

  static const _popularSchools = [
    'ĐH Bách Khoa',
    'ĐH Quốc gia',
    'ĐH FPT',
    'ĐH Kinh tế (UEH)',
    'ĐH Ngoại thương (FTU)',
    'ĐH Công nghệ (UET)',
  ];

  static const _popularSkills = [
    'Flutter',
    'React',
    'JavaScript',
    'TypeScript',
    'Java',
    'Python',
    'UI/UX Design',
    'Figma',
    'SQL',
    'Node.js',
    'Content Marketing',
    'Data Analysis',
  ];

  static const _popularHeadlines = [
    'Frontend Developer tập sự',
    'Mobile Flutter Developer',
    'Backend Engineer',
    'UI/UX & Product Designer',
    'Sinh viên IT đam mê AI/Data',
    'Marketing & Content Specialist',
  ];

  @override
  void dispose() {
    _name.dispose();
    _school.dispose();
    _headline.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  bool _hasSkill(String s) =>
      _skills.any((e) => e.toLowerCase() == s.trim().toLowerCase());

  void _toggleSkill(String s) {
    final v = s.trim();
    if (v.isEmpty) return;
    setState(() {
      if (_hasSkill(v)) {
        _skills = _skills
            .where((e) => e.toLowerCase() != v.toLowerCase())
            .toList();
      } else {
        _skills = [..._skills, v];
        _skillInput.clear();
      }
    });
  }

  void _addCustomSkill() {
    final text = _skillInput.text.trim();
    if (text.isNotEmpty && !_hasSkill(text)) {
      setState(() {
        _skills = [..._skills, text];
        _skillInput.clear();
      });
    }
  }

  bool get _canGoNext {
    if (_currentStep == 0) {
      return _name.text.trim().isNotEmpty;
    }
    return true;
  }

  void _next() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _finish() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = Map<String, dynamic>.from(_me.raw)
      ..['name'] = _name.text.trim()
      ..['school'] = _school.text.trim()
      ..['headline'] = _headline.text.trim().isNotEmpty
          ? _headline.text.trim()
          : 'Ứng viên fonlio'
      ..['skills'] = _skills
      ..['openToWork'] = _openToWork
      ..['avatar'] = {
        ...?(_me.raw['avatar'] is Map
            ? Map<String, dynamic>.from(_me.raw['avatar'])
            : null),
        'mascot': _mascot,
      };

    for (final k in const [
      'avatarUrl',
      'publicSlug',
      'onboardingCompleted',
      'reputationScore',
      'totalExp',
      'currentLevel',
      'npBalance',
      'selectedTheme',
      'themeUnlocked',
      'legalConsentVersion',
    ]) {
      payload.remove(k);
    }

    try {
      await _api.put('/profiles/me', body: payload);
      await _me.hydrate();
      GamificationStore.instance.ping(force: true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Np.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Np.gutter, vertical: Np.s3),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: c.ink),
                      onPressed: _saving ? null : _back,
                    )
                  else
                    const SizedBox(width: 40),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Bước ${_currentStep + 1} / 3',
                        style: NpType.label.copyWith(color: c.acidText),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(Np.s2),
                      child: Text(
                        'Để sau',
                        style: NpType.meta.copyWith(color: c.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Animated Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Np.rPill),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 3.0,
                  backgroundColor: c.line,
                  valueColor: AlwaysStoppedAnimation<Color>(c.acid),
                  minHeight: 4,
                ),
              ),
            ),

            const SizedBox(height: Np.s4),

            // Step Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: Np.gutter),
                children: [
                  if (_currentStep == 0) _buildStep1(c, isDark),
                  if (_currentStep == 1) _buildStep2(c),
                  if (_currentStep == 2) _buildStep3(c, isDark),
                  const SizedBox(height: Np.s6),
                ],
              ),
            ),

            // Error display
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    Np.gutter, 0, Np.gutter, Np.s3),
                child: Text(
                  _error!,
                  style: NpType.meta.copyWith(color: c.danger),
                  textAlign: TextAlign.center,
                ),
              ),

            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Np.gutter, 0, Np.gutter, Np.s4),
              child: AcidButton(
                label: _currentStep == 2
                    ? (_saving ? 'Đang hoàn tất…' : 'Hoàn tất hồ sơ (+50 EXP)')
                    : 'Tiếp tục',
                busy: _saving,
                enabled: _canGoNext && !_saving,
                onTap: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bước 1: Linh vật & Thông tin cơ bản
  Widget _buildStep1(NpColors c, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chào mừng bạn!',
          style: NpType.display.copyWith(color: c.ink),
        ),
        const SizedBox(height: Np.s2),
        Text(
          'Chọn linh vật đại diện và nhập tên trường để nhận diện hồ sơ.',
          style: NpType.body.copyWith(color: c.muted),
        ),
        const SizedBox(height: Np.s5),

        // Mascot Picker
        Text('CHỌN LINH VẬT ĐẠI DIỆN',
            style: NpType.label.copyWith(color: c.muted)),
        const SizedBox(height: Np.s3),
        SizedBox(
          height: 125,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: NpMascot.candidateMascots.length,
            separatorBuilder: (_, _) => const SizedBox(width: Np.s3),
            itemBuilder: (context, idx) {
              final m = NpMascot.candidateMascots[idx];
              final selected = m.id == _mascot;
              return GestureDetector(
                onTap: () => setState(() => _mascot = m.id),
                child: Container(
                  width: 95,
                  padding: const EdgeInsets.all(Np.s2),
                  decoration: BoxDecoration(
                    color: selected ? c.acid.withValues(alpha: 0.12) : c.surface,
                    borderRadius: BorderRadius.circular(Np.rMd),
                    border: Border.all(
                      color: selected ? c.acid : c.line,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected ? Np.glow(c, isDark: isDark) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 60,
                        width: 60,
                        child: MascotSprite(
                          assetPath: NpMascot.directionsAsset(m.id),
                          frameIndex: 4,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: Np.s1),
                      Text(
                        m.label,
                        style: NpType.meta.copyWith(
                          color: selected ? c.acidText : c.ink,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: Np.s5),

        // Name field
        Text('HỌ VÀ TÊN *', style: NpType.label.copyWith(color: c.muted)),
        const SizedBox(height: Np.s2),
        _buildTextField(
          controller: _name,
          hint: 'Nguyễn Văn A',
          c: c,
          onChanged: (_) => setState(() {}),
        ),

        const SizedBox(height: Np.s4),

        // School field
        Text('TRƯỜNG ĐẠI HỌC / CAO ĐẲNG',
            style: NpType.label.copyWith(color: c.muted)),
        const SizedBox(height: Np.s2),
        _buildTextField(
          controller: _school,
          hint: 'vd: Đại học Bách Khoa',
          c: c,
        ),
        const SizedBox(height: Np.s3),

        // Quick school chips
        Wrap(
          spacing: Np.s2,
          runSpacing: Np.s2,
          children: _popularSchools.map((s) {
            final active = _school.text == s;
            return GestureDetector(
              onTap: () => setState(() => _school.text = s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? c.acid.withValues(alpha: 0.15) : c.surface,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: active ? c.acid : c.line),
                ),
                child: Text(
                  s,
                  style: NpType.meta.copyWith(
                    color: active ? c.acidText : c.muted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Bước 2: Kỹ năng thế mạnh
  Widget _buildStep2(NpColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kỹ năng của bạn',
          style: NpType.display.copyWith(color: c.ink),
        ),
        const SizedBox(height: Np.s2),
        Text(
          'Chọn hoặc nhập các kỹ năng thế mạnh để hệ thống ghép việc chính xác hơn.',
          style: NpType.body.copyWith(color: c.muted),
        ),
        const SizedBox(height: Np.s5),

        // Skill input
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _skillInput,
                hint: 'Nhập kỹ năng khác (vd: Docker, Swift…)',
                c: c,
                onSubmitted: (_) => _addCustomSkill(),
              ),
            ),
            const SizedBox(width: Np.s2),
            GestureDetector(
              onTap: _addCustomSkill,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: Np.s4),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Np.rMd),
                  border: Border.all(color: c.line),
                ),
                alignment: Alignment.center,
                child: Text('Thêm',
                    style: NpType.button.copyWith(color: c.acidText)),
              ),
            ),
          ],
        ),

        const SizedBox(height: Np.s4),

        // Selected Skills
        if (_skills.isNotEmpty) ...[
          Text('ĐÃ CHỌN (${_skills.length})',
              style: NpType.label.copyWith(color: c.acidText)),
          const SizedBox(height: Np.s2),
          Wrap(
            spacing: Np.s2,
            runSpacing: Np.s2,
            children: _skills.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: 6),
                decoration: BoxDecoration(
                  color: c.acid.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: c.acid),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s,
                        style: NpType.meta.copyWith(
                            color: c.acidText, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _toggleSkill(s),
                      child: Icon(Icons.close, size: 14, color: c.acidText),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: Np.s5),
        ],

        // Suggested Popular Skills
        Text('GỢI Ý KỸ NĂNG PHỔ BIẾN',
            style: NpType.label.copyWith(color: c.muted)),
        const SizedBox(height: Np.s3),
        Wrap(
          spacing: Np.s2,
          runSpacing: Np.s2,
          children: _popularSkills.map((s) {
            final active = _hasSkill(s);
            return GestureDetector(
              onTap: () => _toggleSkill(s),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? c.acid.withValues(alpha: 0.15) : c.surface,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: active ? c.acid : c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active) ...[
                      Icon(Icons.check, size: 14, color: c.acidText),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      s,
                      style: NpType.meta.copyWith(
                        color: active ? c.acidText : c.ink,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Bước 3: Định hướng & Hoàn tất
  Widget _buildStep3(NpColors c, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Định hướng nghề nghiệp',
          style: NpType.display.copyWith(color: c.ink),
        ),
        const SizedBox(height: Np.s2),
        Text(
          'Thiết lập tiêu đề hồ sơ và trạng thái sẵn sàng nhận việc.',
          style: NpType.body.copyWith(color: c.muted),
        ),
        const SizedBox(height: Np.s5),

        // Reward Banner Callout
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Np.s4),
          decoration: BoxDecoration(
            color: c.acid.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(Np.rMd),
            border: Border.all(color: c.acid.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.acid,
                  borderRadius: BorderRadius.circular(Np.rSm),
                ),
                child: Icon(Icons.stars_rounded, color: c.onAcid, size: 26),
              ),
              const SizedBox(width: Np.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thưởng hoàn tất hồ sơ',
                      style: NpType.body.copyWith(
                          color: c.ink, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nhận ngay +50 EXP & +5 Điểm uy tín (RS) vào ví.',
                      style: NpType.meta.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: Np.s5),

        // Headline field
        Text('TIÊU ĐỀ NGHỀ NGHIỆP / CHỨC DANH',
            style: NpType.label.copyWith(color: c.muted)),
        const SizedBox(height: Np.s2),
        _buildTextField(
          controller: _headline,
          hint: 'vd: Frontend Developer tập sự',
          c: c,
        ),
        const SizedBox(height: Np.s3),

        // Quick headlines
        Wrap(
          spacing: Np.s2,
          runSpacing: Np.s2,
          children: _popularHeadlines.map((h) {
            final active = _headline.text == h;
            return GestureDetector(
              onTap: () => setState(() => _headline.text = h),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Np.s3, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? c.acid.withValues(alpha: 0.15) : c.surface,
                  borderRadius: BorderRadius.circular(Np.rPill),
                  border: Border.all(color: active ? c.acid : c.line),
                ),
                child: Text(
                  h,
                  style: NpType.meta.copyWith(
                    color: active ? c.acidText : c.muted,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: Np.s5),

        // Open to work switch
        Container(
          padding: const EdgeInsets.all(Np.s4),
          decoration: Np.card(c, radius: Np.rMd),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sẵn sàng nhận cơ hội (Open to work)',
                      style: NpType.body.copyWith(
                          color: c.ink, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cho phép nhà tuyển dụng và doanh nghiệp tìm thấy hồ sơ của bạn.',
                      style: NpType.meta.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _openToWork,
                activeThumbColor: c.acid,
                activeTrackColor: c.acid.withValues(alpha: 0.3),
                onChanged: (v) => setState(() => _openToWork = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required NpColors c,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Np.rMd),
        border: Border.all(color: c.line),
      ),
      child: TextField(
        controller: controller,
        style: NpType.body.copyWith(color: c.ink),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: NpType.body.copyWith(color: c.faint),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: Np.s4, vertical: Np.s3),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
