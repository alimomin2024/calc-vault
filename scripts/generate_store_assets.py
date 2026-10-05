import os
import shutil
from PIL import Image, ImageDraw, ImageFont, ImageFilter

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(BASE_DIR, "store_assets", "raw_screenshots")
PHONE_DIR = os.path.join(BASE_DIR, "store_assets", "phone")
FEATURE_DIR = os.path.join(BASE_DIR, "store_assets", "feature_graphic")
LISTING_DIR = os.path.join(BASE_DIR, "store_assets", "listing")

FONT_SANS = os.path.join(BASE_DIR, "assets", "fonts", "PlusJakartaSans.ttf")
FONT_SERIF = os.path.join(BASE_DIR, "assets", "fonts", "PlayfairDisplay.ttf")
ICON_PATH = os.path.join(BASE_DIR, "assets", "branding", "calculator_icon.png")
AI_BG_PATH = os.path.join(FEATURE_DIR, "ai_bg.jpg")

os.makedirs(PHONE_DIR, exist_ok=True)
os.makedirs(FEATURE_DIR, exist_ok=True)
os.makedirs(LISTING_DIR, exist_ok=True)

def round_corners(image, radius):
    mask = Image.new("L", image.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), image.size], radius=radius, fill=255)
    result = image.copy()
    result.putalpha(mask)
    return result

def create_gradient(width, height, color1, color2):
    base = Image.new("RGBA", (width, height), color1)
    top = Image.new("RGBA", (width, height), color2)
    mask = Image.new("L", (width, height))
    mask_data = []
    for y in range(height):
        ratio = y / height
        mask_data.extend([int(255 * ratio)] * width)
    mask.putdata(mask_data)
    base.paste(top, (0, 0), mask)
    return base

def add_glow_orb(image, cx, cy, radius, color):
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse([(cx - radius, cy - radius), (cx + radius, cy + radius)], fill=color)
    blurred = overlay.filter(ImageFilter.GaussianBlur(radius // 2))
    image.alpha_composite(blurred)

def generate_phone_screenshot(index, filename, raw_name, pill_text, title_text, sub_text, accent_color):
    W, H = 1080, 2400
    canvas = create_gradient(W, H, (14, 15, 18, 255), (24, 25, 30, 255))
    
    # Subtle accent glow
    add_glow_orb(canvas, W // 2, 260, 320, (*accent_color, 35))
    add_glow_orb(canvas, W // 2, H - 300, 380, (*accent_color, 20))
    
    draw = ImageDraw.Draw(canvas)
    
    font_pill = ImageFont.truetype(FONT_SANS, 22)
    font_title = ImageFont.truetype(FONT_SANS, 56)
    font_sub = ImageFont.truetype(FONT_SANS, 26)
    
    # 1. Category Pill
    bbox = draw.textbbox((0, 0), pill_text, font=font_pill)
    pw = bbox[2] - bbox[0] + 48
    ph = 44
    px = (W - pw) // 2
    py = 110
    
    draw.rounded_rectangle(
        [(px, py), (px + pw, py + ph)],
        radius=22,
        fill=(28, 30, 36, 230),
        outline=(*accent_color, 180),
        width=2,
    )
    # Glowing dot
    draw.ellipse([(px + 16, py + 16), (px + 28, py + 28)], fill=accent_color)
    draw.text((px + 36, py + 9), pill_text, font=font_pill, fill=(255, 255, 255, 250))
    
    # 2. Main Title (Centered)
    title_lines = title_text.split("\n")
    ty = 185
    for line in title_lines:
        t_box = draw.textbbox((0, 0), line, font=font_title)
        tw = t_box[2] - t_box[0]
        tx = (W - tw) // 2
        draw.text((tx, ty), line, font=font_title, fill=(255, 255, 255, 255))
        ty += 70
        
    # 3. Subtitle
    sub_box = draw.textbbox((0, 0), sub_text, font=font_sub)
    sw = sub_box[2] - sub_box[0]
    sx = (W - sw) // 2
    draw.text((sx, ty + 15), sub_text, font=font_sub, fill=(175, 178, 190, 240))
    
    # 4. Device Mockup Frame
    raw_path = os.path.join(RAW_DIR, raw_name)
    if os.path.exists(raw_path):
        screen = Image.open(raw_path).convert("RGBA")
        
        # Target phone dimensions inside 1080x2400 canvas
        screen_w = 820
        scale = screen_w / screen.width
        screen_h = int(screen.height * scale)
        screen_resized = screen.resize((screen_w, screen_h), Image.Resampling.LANCZOS)
        
        corner_r = 38
        screen_rounded = round_corners(screen_resized, corner_r)
        
        # Outer bezel
        bezel_pad = 12
        frame_w = screen_w + (bezel_pad * 2)
        frame_h = screen_h + (bezel_pad * 2)
        
        frame = Image.new("RGBA", (frame_w, frame_h), (0, 0, 0, 0))
        f_draw = ImageDraw.Draw(frame)
        f_draw.rounded_rectangle(
            [(0, 0), (frame_w, frame_h)],
            radius=corner_r + bezel_pad,
            fill=(26, 27, 33, 255),
            outline=(*accent_color, 120),
            width=3,
        )
        # Inner dark border
        f_draw.rounded_rectangle(
            [(bezel_pad - 1, bezel_pad - 1), (frame_w - bezel_pad + 1, frame_h - bezel_pad + 1)],
            radius=corner_r + 1,
            outline=(10, 11, 14, 255),
            width=2,
        )
        
        frame.paste(screen_rounded, (bezel_pad, bezel_pad), screen_rounded)
        
        # Camera punch hole
        punch_w, punch_h = 24, 24
        f_draw.ellipse(
            [(frame_w // 2 - 12, bezel_pad + 14), (frame_w // 2 + 12, bezel_pad + 38)],
            fill=(10, 10, 14, 255),
        )
        
        # Soft Drop Shadow
        shadow = Image.new("RGBA", (frame_w + 100, frame_h + 100), (0, 0, 0, 0))
        s_draw = ImageDraw.Draw(shadow)
        s_draw.rounded_rectangle(
            [(50, 50), (frame_w + 50, frame_h + 50)],
            radius=corner_r + bezel_pad,
            fill=(0, 0, 0, 160),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(32))
        
        dest_x = (W - frame_w) // 2
        dest_y = 480
        
        canvas.paste(shadow, (dest_x - 50, dest_y - 40), shadow)
        canvas.paste(frame, (dest_x, dest_y), frame)
        
    out_path = os.path.join(PHONE_DIR, filename)
    canvas.convert("RGB").save(out_path, "PNG", quality=95)
    print(f"Generated phone listing screenshot: {out_path}")

def generate_feature_graphic_ai():
    W, H = 1024, 500
    if os.path.exists(AI_BG_PATH):
        bg = Image.open(AI_BG_PATH).convert("RGBA")
        bg = bg.resize((W, H), Image.Resampling.LANCZOS)
    else:
        bg = create_gradient(W, H, (14, 15, 20, 255), (24, 26, 36, 255))
        
    # High-contrast dark vignette overlay for readability
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for x in range(W):
        factor = max(0.0, min(1.0, 1.0 - (x / (W * 0.72))))
        alpha = int(220 * factor + 50)
        line_overlay = Image.new("RGBA", (1, H), (12, 13, 18, alpha))
        overlay.paste(line_overlay, (x, 0))
    bg.alpha_composite(overlay)
    
    draw = ImageDraw.Draw(bg)
    font_title = ImageFont.truetype(FONT_SERIF, 54)
    font_sub = ImageFont.truetype(FONT_SANS, 22)
    font_desc = ImageFont.truetype(FONT_SANS, 20)
    font_tag = ImageFont.truetype(FONT_SANS, 16)
    
    # App Icon
    if os.path.exists(ICON_PATH):
        icon = Image.open(ICON_PATH).convert("RGBA")
        icon = icon.resize((108, 108), Image.Resampling.LANCZOS)
        icon_rounded = round_corners(icon, 24)
        
        icon_shadow = Image.new("RGBA", (132, 132), (0, 0, 0, 0))
        is_draw = ImageDraw.Draw(icon_shadow)
        is_draw.rounded_rectangle([(12, 12), (120, 120)], radius=26, fill=(0, 0, 0, 160))
        icon_shadow = icon_shadow.filter(ImageFilter.GaussianBlur(14))
        
        bg.paste(icon_shadow, (48, 68), icon_shadow)
        bg.paste(icon_rounded, (60, 80), icon_rounded)
        
    # Title & Subtitle
    draw.text((192, 90), "CalcVault", font=font_title, fill=(255, 255, 255, 255))
    draw.text((195, 155), "SECRET CALCULATOR & PHOTO LOCKER", font=font_sub, fill=(166, 138, 86, 255))
    
    # Description
    desc = "Military-grade AES-256 vault hidden behind a functional calculator.\nZero accounts. Zero cloud leaks. Complete peace of mind."
    draw.text((60, 230), desc, font=font_desc, fill=(215, 218, 228, 240), spacing=8)
    
    # Feature Badges
    pills = [
        ("AES-256 Encryption", (166, 138, 86)),
        ("Dual-PIN Decoy Vault", (168, 85, 247)),
        ("Break-in Intruder Selfie", (239, 68, 68)),
        ("100% Offline & Private", (46, 107, 77)),
    ]
    px = 60
    py = 370
    for text, color in pills:
        bbox = draw.textbbox((0, 0), text, font=font_tag)
        pw = bbox[2] - bbox[0] + 40
        ph = 38
        draw.rounded_rectangle(
            [(px, py), (px + pw, py + ph)],
            radius=19,
            fill=(20, 22, 28, 220),
            outline=(*color, 160),
            width=2,
        )
        draw.ellipse([(px + 12, py + 14), (px + 22, py + 24)], fill=color)
        draw.text((px + 28, py + 9), text, font=font_tag, fill=(255, 255, 255, 240))
        px += pw + 14
        
    out_path = os.path.join(FEATURE_DIR, "feature_graphic_ai.png")
    bg.convert("RGB").save(out_path, "PNG", quality=95)
    bg.convert("RGB").save(os.path.join(LISTING_DIR, "featured_graphic.png"), "PNG", quality=95)
    print(f"Generated AI Feature Graphic: {out_path}")

def generate_feature_graphic_clean():
    W, H = 1024, 500
    canvas = create_gradient(W, H, (14, 15, 18, 255), (26, 27, 34, 255))
    add_glow_orb(canvas, 180, 160, 260, (166, 138, 86, 45))
    add_glow_orb(canvas, 800, 260, 300, (46, 107, 77, 35))
    
    draw = ImageDraw.Draw(canvas)
    font_title = ImageFont.truetype(FONT_SERIF, 56)
    font_sub = ImageFont.truetype(FONT_SANS, 22)
    font_desc = ImageFont.truetype(FONT_SANS, 20)
    font_tag = ImageFont.truetype(FONT_SANS, 16)
    
    # App Icon
    if os.path.exists(ICON_PATH):
        icon = Image.open(ICON_PATH).convert("RGBA")
        icon = icon.resize((108, 108), Image.Resampling.LANCZOS)
        icon_rounded = round_corners(icon, 24)
        canvas.paste(icon_rounded, (60, 80), icon_rounded)
        
    draw.text((192, 90), "CalcVault", font=font_title, fill=(255, 255, 255, 255))
    draw.text((195, 155), "SECRET CALCULATOR & PHOTO LOCKER", font=font_sub, fill=(166, 138, 86, 255))
    
    desc = "Disguised everyday calculator hiding an encrypted private safe.\nIn-memory decryption. Panic flip lock. 100% on-device security."
    draw.text((60, 230), desc, font=font_desc, fill=(215, 218, 228, 240), spacing=8)
    
    pills = [
        ("Military AES-256", (166, 138, 86)),
        ("Dual-PIN Decoy Safe", (168, 85, 247)),
        ("100% Offline", (46, 107, 77)),
    ]
    px = 60
    py = 375
    for text, color in pills:
        bbox = draw.textbbox((0, 0), text, font=font_tag)
        pw = bbox[2] - bbox[0] + 40
        ph = 38
        draw.rounded_rectangle(
            [(px, py), (px + pw, py + ph)],
            radius=19,
            fill=(22, 24, 30, 230),
            outline=(*color, 160),
            width=2,
        )
        draw.ellipse([(px + 12, py + 14), (px + 22, py + 24)], fill=color)
        draw.text((px + 28, py + 9), text, font=font_tag, fill=(255, 255, 255, 240))
        px += pw + 14
        
    # Floating angled phone on the right
    phone_preview_path = os.path.join(RAW_DIR, "01_calculator_disguise.png")
    if os.path.exists(phone_preview_path):
        p_img = Image.open(phone_preview_path).convert("RGBA")
        p_scale = 320 / p_img.width
        p_w = 320
        p_h = int(p_img.height * p_scale)
        p_scaled = p_img.resize((p_w, p_h), Image.Resampling.LANCZOS)
        p_rounded = round_corners(p_scaled, 30)
        
        bezel = Image.new("RGBA", (p_w + 8, p_h + 8), (0, 0, 0, 0))
        b_draw = ImageDraw.Draw(bezel)
        b_draw.rounded_rectangle(
            [(0, 0), (p_w + 8, p_h + 8)],
            radius=34,
            fill=(24, 25, 30, 255),
            outline=(166, 138, 86, 180),
            width=3,
        )
        bezel.paste(p_rounded, (4, 4), p_rounded)
        
        p_shadow = Image.new("RGBA", (p_w + 60, p_h + 60), (0, 0, 0, 0))
        ps_draw = ImageDraw.Draw(p_shadow)
        ps_draw.rounded_rectangle([(20, 20), (p_w + 40, p_h + 40)], radius=36, fill=(0, 0, 0, 160))
        p_shadow = p_shadow.filter(ImageFilter.GaussianBlur(25))
        
        px_pos = 665
        py_pos = 45
        canvas.paste(p_shadow, (px_pos - 15, py_pos - 10), p_shadow)
        canvas.paste(bezel, (px_pos, py_pos), bezel)
        
    out_path = os.path.join(FEATURE_DIR, "feature_graphic_clean.png")
    canvas.convert("RGB").save(out_path, "PNG", quality=95)
    print(f"Generated Clean Feature Graphic: {out_path}")

def generate_app_icon():
    if os.path.exists(ICON_PATH):
        icon = Image.open(ICON_PATH).convert("RGBA")
        icon_512 = icon.resize((512, 512), Image.Resampling.LANCZOS)
        out_path = os.path.join(LISTING_DIR, "app_icon_512.png")
        icon_512.save(out_path, "PNG")
        print(f"Generated 512x512 App Icon: {out_path}")

if __name__ == "__main__":
    print("Generating CalcVault Store Assets...")
    
    # 1. 512x512 App Icon
    generate_app_icon()
    
    # 2. Feature Graphics (AI and Clean)
    generate_feature_graphic_ai()
    generate_feature_graphic_clean()
    
    # 3. 6 Phone Mockup Screenshots
    screenshots = [
        (
            1,
            "01_stealth_calculator.png",
            "01_calculator_disguise.png",
            "STEALTH DISGUISE",
            "SECRET CALCULATOR\nHIDING A VAULT",
            "Fully functional math calculator until you enter your secret PIN",
            (166, 138, 86),  # Khaki Gold
        ),
        (
            2,
            "02_encrypted_vault.png",
            "02_secure_vault.png",
            "AES-256-GCM",
            "MILITARY-GRADE\nENCRYPTED VAULT",
            "Hardware-backed keys protect private photos, videos & folders",
            (46, 107, 77),  # Green
        ),
        (
            3,
            "03_decoy_system.png",
            "03_decoy_vault.png",
            "DURESS PROTECTION",
            "DUAL-PIN DECOY\nISOLATED VAULT",
            "Enter a decoy PIN to open a separate vault with harmless files",
            (168, 85, 247),  # Purple
        ),
        (
            4,
            "04_security_alerts.png",
            "04_security_center.png",
            "BREAK-IN DEFENSE",
            "INTRUDER SELFIE\n& PANIC FLIP",
            "Captures break-in attempts • Flip face-down to lock immediately",
            (239, 68, 68),  # Red
        ),
        (
            5,
            "05_offline_privacy.png",
            "05_stealth_setup.png",
            "100% OFFLINE",
            "ZERO ACCOUNTS\nTOTAL PRIVACY",
            "No cloud, no telemetry, no internet • 100% on-device storage",
            (14, 165, 233),  # Blue
        ),
        (
            6,
            "06_passwords_notes.png",
            "06_encrypted_passwords.png",
            "CONFIDENTIAL RECORDS",
            "PASSWORDS &\nBANK CARDS",
            "Encrypted offline storage for passwords, cards & private notes",
            (217, 119, 6),  # Amber
        ),
    ]
    
    for idx, fname, raw, pill, title, sub, color in screenshots:
        generate_phone_screenshot(idx, fname, raw, pill, title, sub, color)
        
    print("All store assets generated successfully!")
