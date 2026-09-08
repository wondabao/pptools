#!/usr/bin/env python3
"""Measure PicPark's Hero (主图) template. Build-time only; never modifies PSD.

PYTHONPATH=.build/psd-deps python3 scripts/measure-picpark-hero.py \
  '/Users/anchor/Desktop/PicPark/主图.psd'
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from psd_tools import PSDImage

ROOT = Path(__file__).resolve().parents[1]

SLIDE_NAMES = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', '23', '24'}


def draw_clean_layers(container, canvas, offset_x, offset_y):
    for l in container:
        if l.name in SLIDE_NAMES:
            continue
        if l.name in ['背景', '背景图']:
            continue
        if l.kind == 'group':
            draw_clean_layers(l, canvas, offset_x, offset_y)
        elif l.visible:
            im = l.topil()
            if im:
                if l.opacity < 255:
                    alpha = im.split()[-1]
                    alpha = alpha.point(lambda p: int(p * l.opacity / 255))
                    im.putalpha(alpha)
                lx = l.bbox[0] - offset_x
                ly = l.bbox[1] - offset_y
                canvas.alpha_composite(im.convert('RGBA'), (lx, ly))


def measure(source):
    psd = PSDImage.open(source)
    artboards = list(psd)
    if len(artboards) != 6:
        raise ValueError('Expected exactly 6 artboards in 主图.psd')

    artboard_manifests = []
    evidence = []

    # Artboard names and roles
    roles = [
        "主图 1 · 封面合集",
        "主图 2 · 亮点展示（一）",
        "主图 3 · 亮点展示（二）",
        "主图 4 · 亮点展示（三）",
        "主图 5 · 亮点展示（四）",
        "主图 6 · 服务保障"
    ]

    all_banner_slots = []

    for ab_idx, ab in enumerate(artboards):
        ab_x, ab_y = ab.bbox[0], ab.bbox[1]
        ab_w, ab_h = ab.bbox[2] - ab_x, ab.bbox[3] - ab_y

        slots = []
        ab_evidence = []

        # Find slide shapes in order
        for l in ab:
            if l.kind == 'shape':
                origins = getattr(l, 'origination', [])
                if origins and origins[0] and l.name.isdigit():
                    orig = origins[0]
                    box = orig.bbox
                    radii = getattr(orig, 'radii', None)
                    r = 0.0
                    corner_radii = None
                    if radii:
                        tl = float(radii.get(b'topLeft', 0.0))
                        tr = float(radii.get(b'topRight', 0.0))
                        br = float(radii.get(b'bottomRight', 0.0))
                        bl = float(radii.get(b'bottomLeft', 0.0))
                        r = max(tl, tr, br, bl)
                        if not (tl == tr == br == bl):
                            corner_radii = [tl, tr, br, bl]
                    
                    has_shadow = l.has_effects()
                    
                    slot_dict = {
                        'page': int(l.name),
                        'x': round(box[0] - ab_x, 4),
                        'y': round(box[1] - ab_y, 4),
                        'width': round(box[2] - box[0], 4),
                        'height': round(box[3] - box[1], 4),
                        'cornerRadius': r,
                    }
                    if corner_radii:
                        slot_dict['cornerRadii'] = corner_radii
                    if has_shadow:
                        slot_dict['shadowOpacity'] = 0.15
                        slot_dict['shadowBlur'] = 16.0
                        slot_dict['shadowOffsetY'] = -8.0

                    stroke = getattr(l, 'stroke', None)
                    if stroke:
                        s_data = getattr(stroke, '_data', {})
                        if s_data.get(b'strokeEnabled', False):
                            sw = s_data.get(b'strokeStyleLineWidth', 0.0)
                            if sw > 0:
                                slot_dict['strokeWidth'] = float(sw)
                                slot_dict['strokeColorHex'] = '#FFFFFF'

                    slots.append(slot_dict)
                    ab_evidence.append({
                        'layerName': l.name,
                        'vectorBox': list(box),
                        'artboardRelBox': [slot_dict['x'], slot_dict['y'], slot_dict['x'] + slot_dict['width'], slot_dict['y'] + slot_dict['height']],
                        'cornerRadius': r,
                        'hasShadow': has_shadow,
                        'strokeWidth': slot_dict.get('strokeWidth')
                    })

        # Sort slots by page number
        # Special case for Artboard 5 (主图6): the slide is top card (page 20 in PSD, but role is slide 24)
        if ab_idx == 5:
            # Artboard 5 has two shapes named '20'. Top card is y ≈ 33.39
            top_slots = [s for s in slots if s['y'] < 300]
            slots = top_slots
            if slots:
                slots[0]['page'] = 24

        slots.sort(key=lambda s: s['page'])

        manifest_slots = []
        for s in slots:
            ms = {
                'x': s['x'],
                'y': s['y'],
                'width': s['width'],
                'height': s['height'],
                'cornerRadius': s['cornerRadius']
            }
            if 'cornerRadii' in s:
                ms['cornerRadii'] = s['cornerRadii']
            if 'shadowOpacity' in s:
                ms['shadowOpacity'] = s['shadowOpacity']
                ms['shadowBlur'] = s['shadowBlur']
                ms['shadowOffsetY'] = s['shadowOffsetY']
            if 'strokeWidth' in s:
                ms['strokeWidth'] = s['strokeWidth']
                ms['strokeColorHex'] = s['strokeColorHex']
            manifest_slots.append(ms)

            # For banner
            bs = dict(ms)
            bs['x'] = round(ms['x'] + ab_x, 4)
            bs['y'] = round(ms['y'] + ab_y, 4)
            all_banner_slots.append(bs)

        bg_name = f'clean_bg_{ab_idx+1}.png'
        manifest = {
            'id': f'picpark-hero-{ab_idx+1}',
            'name': f'PicPark · {roles[ab_idx]}',
            'width': int(ab_w),
            'height': int(ab_h),
            'slots': manifest_slots,
            'backgroundHex': '#81AAFE' if ab_idx == 5 else '#F5F7FB',
            'cornerRadius': 20.0,
            'shadowOpacity': 0.0,
            'imageFit': 'fill',
            'backgroundImageName': bg_name,
            'sourceName': source.name
        }
        artboard_manifests.append(manifest)
        evidence.append({
            'artboardIndex': ab_idx,
            'name': ab.name,
            'bbox': list(ab.bbox),
            'slots': ab_evidence
        })

    # Combined Hero Manifest (6500 x 1000) as specified in requirements: PicPark·电商主图 (6500 × 1000 px)
    hero_manifest = {
        'id': 'picpark-hero',
        'name': 'PicPark · 电商主图',
        'width': 6500,
        'height': 1000,
        'slots': all_banner_slots,
        'backgroundHex': '#F5F7FB',
        'cornerRadius': 20.0,
        'shadowOpacity': 0.0,
        'imageFit': 'fill',
        'backgroundImageName': 'clean_bg_banner.png',
        'sourceName': source.name,
        'subTemplates': artboard_manifests
    }

    return hero_manifest, evidence


def export_assets_and_manifests(source):
    psd = PSDImage.open(source)
    artboards = list(psd)

    out_tpl = ROOT / 'Templates' / 'PicPark_Hero'
    out_tpl_assets = out_tpl / 'assets'
    out_tpl_assets.mkdir(parents=True, exist_ok=True)

    out_bundle_assets = ROOT / 'Sources' / 'PPTTools' / 'Resources' / 'HeroAssets'
    out_bundle_assets.mkdir(parents=True, exist_ok=True)

    print("Generating clean banner and artboard backgrounds...")
    solid_bg_color = (245, 247, 251, 255)
    banner_canvas = Image.new('RGBA', (6500, 1000), solid_bg_color)

    for ab_idx, ab in enumerate(artboards):
        if ab_idx == 5:
            # Artboard 5 (主图 6 · 服务保障):
            # 顶部卡片槽位放 1 张图，图片下方（网盘图标、发货文字、有用徽章）与底部文字（其它演示图请查看详情）固定
            for l in ab:
                if l.name == '20' and l.kind == 'smartobject':
                    l.visible = False
            canvas = ab.composite()
        else:
            canvas = Image.new('RGBA', (1000, 1000), solid_bg_color)
            draw_clean_layers(ab, canvas, ab.bbox[0], ab.bbox[1])
        banner_canvas.alpha_composite(canvas, (ab.bbox[0], ab.bbox[1]))
        bg_filename = f'clean_bg_{ab_idx+1}.png'
        canvas.save(out_tpl_assets / bg_filename, 'PNG')
        canvas.save(out_bundle_assets / bg_filename, 'PNG')
        print(f"  Saved {bg_filename}")

    banner_canvas.save(out_tpl_assets / 'clean_bg_banner.png', 'PNG')
    banner_canvas.save(out_bundle_assets / 'clean_bg_banner.png', 'PNG')
    print("  Saved clean_bg_banner.png")

    hero_manifest, evidence = measure(source)

    # Save template.json in Templates/PicPark_Hero
    (out_tpl / 'template.json').write_text(json.dumps(hero_manifest, ensure_ascii=False, indent=2) + '\n')

    # Update Sources/PPTTools/Resources/templates.json
    res_tpl_path = ROOT / 'Sources' / 'PPTTools' / 'Resources' / 'templates.json'
    existing = []
    if res_tpl_path.exists():
        existing = json.loads(res_tpl_path.read_text())

    # Keep non-hero templates
    updated = [t for t in existing if not t.get('id', '').startswith('picpark-hero')]
    updated.append(hero_manifest)

    res_tpl_path.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + '\n')
    print(f"Updated {res_tpl_path} with hero template (total {len(updated)} templates).")

    # Documentation
    proof = ROOT / 'docs' / 'template-measurements'
    proof.mkdir(parents=True, exist_ok=True)
    (proof / 'picpark-hero-measurements.json').write_text(json.dumps({
        'source': source.name,
        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'artboards': evidence
    }, ensure_ascii=False, indent=2) + '\n')
    print(f"Saved measurement proof to {proof / 'picpark-hero-measurements.json'}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    export_assets_and_manifests(parser.parse_args().source)
