"""Sinh icon app cho iOS và Android từ nhãn hiệu nextplease.

Vì sao vẽ bằng code chứ không dán ảnh: icon phải tồn tại ở 12 kích cỡ cho iOS
và 5 cho Android. Xuất tay một lần thì lần sau đổi màu hay đổi hình phải làm
lại toàn bộ, và gần như chắc chắn sót một cỡ nào đó.

Hình lấy nguyên từ FE/public/favicon.svg — nền emerald, chữ "n" ghép bằng hình
khối, chấm hổ phách thay dấu hai chấm trong "nextplease:". Nhờ vậy icon trên
màn hình chính và favicon trên tab trình duyệt là CÙNG một vật, không phải hai
biến thể hao hao nhau.

    python3 tool/make_app_icon.py
"""

from PIL import Image, ImageDraw

# Màu lấy đúng từ favicon.svg của web. KHÔNG dùng #2EE87F (màu nhấn của app):
# màu đó sáng hơn, hợp để tô nút trên nền trắng, nhưng ở cỡ 60px trên hình nền
# bất kỳ thì nó bệt và nhạt. Emerald đậm giữ được hình ở cỡ nhỏ.
BG = (16, 185, 129)       # #10b981
INK = (11, 15, 14)        # #0b0f0e
AMBER = (245, 158, 11)    # #f59e0b

BASE = 64  # hệ toạ độ gốc của favicon.svg


def _glyph(k: float, size: int) -> Image.Image:
    """Vẽ riêng chữ "n" và chấm trên nền trong suốt, chưa căn chỉnh."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx, cy, r, w = 28 * k, 31 * k, 10.5 * k, 9 * k

    # Vòm. PIL nới bề rộng nét VÀO TRONG từ khung bao, nên khung phải tính theo
    # bán kính NGOÀI (bán kính tâm nét + nửa nét), không phải bán kính tâm nét.
    outer = r + w / 2
    d.arc([cx - outer, cy - outer, cx + outer, cy + outer],
          start=180, end=360, fill=INK, width=round(w))

    # Bo hai đầu vòm bằng tay. PIL không có stroke-linecap, và đầu nét phẳng
    # gặp góc bo của thân chữ tạo ra một cái KHẤC nhìn rõ ở cỡ lớn.
    for ex in (cx - r, cx + r):
        d.ellipse([ex - w / 2, cy - w / 2, ex + w / 2, cy + w / 2], fill=INK)

    d.rounded_rectangle([13 * k, 19 * k, 22 * k, 47 * k], radius=4.5 * k, fill=INK)
    # Thân phải: hai góc TRÊN để vuông. Chúng nằm khuất dưới vòm, mà bo tròn
    # thì mép bo thò ra cạnh đầu vòm và tạo một cái khấc thấy rõ ở cỡ lớn.
    d.rounded_rectangle([34 * k, 31 * k, 43 * k, 47 * k], radius=4.5 * k,
                        fill=INK, corners=(False, False, True, True))
    d.ellipse([47 * k, 38 * k, 56 * k, 47 * k], fill=AMBER)
    return img


def draw_mark(size: int, rounded: bool) -> Image.Image:
    """Vẽ nhãn hiệu ở kích cỡ bất kỳ.

    `rounded`: bo góc sẵn hay không.
      - iOS: KHÔNG bo. Hệ điều hành tự áp mặt nạ siêu ê-líp; bo sẵn nữa thì
        góc bị cắt hai lần và viền hiện ra một vệt tối.
      - Android: CÓ bo, vì launcher cũ hiển thị ic_launcher.png nguyên trạng.
    """
    # Vẽ ở 4× rồi thu nhỏ: PIL không khử răng cưa cho hình khối, nên vẽ thẳng
    # ở 48px sẽ ra cạnh nham nhở.
    s = size * 4
    k = s / BASE

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if rounded:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=19 * k, fill=BG)
    else:
        d.rectangle([0, 0, s - 1, s - 1], fill=BG)

    # Căn giữa theo BBOX THẬT của phần đã vẽ, không theo khung 64×64 của
    # favicon. Trong favicon, chữ "n" cộng chấm nằm lệch phải và thấp so với
    # khung — ở cỡ 16px không ai nhận ra, ở cỡ icon thì thấy rõ ngay.
    glyph = _glyph(k, s)
    box = glyph.getbbox()
    gw, gh = box[2] - box[0], box[3] - box[1]

    # Chiếm 66% bề rộng. Rộng hơn thì góc dưới-trái của chữ chạm vào mặt nạ
    # siêu ê-líp của iOS; hẹp hơn thì icon trông rỗng.
    scale = (s * 0.66) / gw
    glyph = glyph.crop(box).resize(
        (max(1, round(gw * scale)), max(1, round(gh * scale))), Image.LANCZOS)

    img.paste(glyph,
              ((s - glyph.width) // 2, (s - glyph.height) // 2),
              glyph)
    return img.resize((size, size), Image.LANCZOS)


def write_ios() -> None:
    # Cỡ lấy đúng từ Contents.json mà Flutter tạo sẵn.
    sizes = {
        "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60, "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120, "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180, "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152, "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    out = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, px in sizes.items():
        # App Store từ chối icon có kênh alpha, nên dán lên nền đặc rồi mới lưu.
        mark = draw_mark(px, rounded=False)
        icon = Image.new("RGB", (px, px), BG)
        icon.paste(mark, (0, 0), mark)
        icon.save(f"{out}/{name}")
    print(f"iOS: {len(sizes)} tệp")


def write_android() -> None:
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for bucket, px in sizes.items():
        draw_mark(px, rounded=True).save(
            f"android/app/src/main/res/mipmap-{bucket}/ic_launcher.png")
    print(f"Android: {len(sizes)} tệp")


if __name__ == "__main__":
    write_ios()
    write_android()
