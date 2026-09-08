#!/usr/bin/env python3
"""Measure PicPark's RedBook (小红书v2.0) template. Build-time only; never modifies PSD.

PYTHONPATH=.build/psd-deps python3 scripts/measure-picpark-redbook.py \
  '/Users/anchor/Desktop/PicPark/小红书v2.0.psd'
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
from psd_tools import PSDImage

ROOT = Path(__file__).resolve().parents[1]

SLIDE_NAMES = {str(i) for i in range(1, 36)} | {'矩形 1'}


def draw_clean_layers(container, canvas, offset_x, offset_y):
    for l in container:
        if l.name in SLIDE_NAMES and (l.kind == 'smartobject' or l.kind == 'shape'):
            continue
        if l.name == '组 1':
            # Extract only the circular avatar from 组 1 without the editable title text
            g1_comp = l.composite()
            if g1_comp:
                avatar = g1_comp.crop((1230 - 71, 72 - 71, 1378 - 71, 220 - 71))
                canvas.alpha_composite(avatar, (1230 - offset_x, 72 - offset_y))
            continue
        if l.kind == 'group':
            draw_clean_layers(l, canvas, offset_x, offset_y)
        elif l.visible:
            im = l.topil()
            if im:
                lx = l.bbox[0] - offset_x
                ly = l.bbox[1] - offset_y
                canvas.alpha_composite(im.convert('RGBA'), (lx, ly))


def measure(source):
    psd = PSDImage.open(source)
    artboards = list(psd)
    if len(artboards) != 5:
        raise ValueError('Expected exactly 5 artboards in 小红书v2.0.psd')

    artboard_manifests = []
    evidence = []

    roles = [
        "小红书 1 · 封面展示",
        "小红书 2 · 内页浏览（一）",
        "小红书 3 · 内页浏览（二）",
        "小红书 4 · 内页浏览（三）",
        "小红书 5 · 尾页与主页引导"
    ]

    all_banner_slots = []

    for ab_idx, ab in enumerate(artboards):
        ab_x, ab_y = ab.bbox[0], ab.bbox[1]
        ab_w, ab_h = ab.bbox[2] - ab_x, ab.bbox[3] - ab_y

        slots = []
        ab_evidence = []

        for l in ab:
            if l.kind == 'shape' and (l.name.isdigit() or l.name == '矩形 1'):
                origins = getattr(l, 'origination', [])
                if origins and origins[0]:
                    orig = origins[0]
                    box = orig.bbox
                    radii = getattr(orig, 'radii', None)
                    r = 20.0
                    if radii:
                        r = max(float(v) for k, v in radii.items() if k != b'unitValueQuadVersion')

                    has_shadow = l.has_effects()
                    effects = list(l.effects) if has_shadow else []
                    eff = effects[0] if effects else None

                    page_num = 1 if l.name == '矩形 1' else int(l.name)

                    slot_dict = {
                        'page': page_num,
                        'x': round(box[0] - ab_x, 4),
                        'y': round(box[1] - ab_y, 4),
                        'width': round(box[2] - box[0], 4),
                        'height': round(box[3] - box[1], 4),
                        'cornerRadius': r,
                    }
                    if eff:
                        slot_dict['shadowOpacity'] = round(eff.opacity / 100.0, 2)
                        slot_dict['shadowBlur'] = float(eff.size)
                        slot_dict['shadowOffsetY'] = -float(eff.distance)
                        clr = getattr(eff, 'color', {})
                        r = int(round(float(clr.get(b'Rd  ', 0))))
                        g = int(round(float(clr.get(b'Grn ', 0))))
                        b = int(round(float(clr.get(b'Bl  ', 0))))
                        slot_dict['shadowColorHex'] = f"#{r:02X}{g:02X}{b:02X}"

                    st = getattr(l, 'stroke', None)
                    if st and st.enabled:
                        slot_dict['strokeWidth'] = float(st.line_width)
                        sclr = st.content.get(b'Clr ', {}) if st.content else {}
                        sr = int(sclr.get(b'Rd  ', 255))
                        sg = int(sclr.get(b'Grn ', 255))
                        sb = int(sclr.get(b'Bl  ', 255))
                        slot_dict['strokeColorHex'] = f"#{sr:02X}{sg:02X}{sb:02X}"

                    slots.append(slot_dict)
                    ab_evidence.append({
                        'layerName': l.name,
                        'vectorBox': list(box),
                        'artboardRelBox': [slot_dict['x'], slot_dict['y'], slot_dict['x'] + slot_dict['width'], slot_dict['y'] + slot_dict['height']],
                        'cornerRadius': r,
                        'hasShadow': has_shadow,
                        'strokeWidth': slot_dict.get('strokeWidth')
                    })

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
            if 'shadowOpacity' in s:
                ms['shadowOpacity'] = s['shadowOpacity']
                ms['shadowBlur'] = s['shadowBlur']
                ms['shadowOffsetY'] = s['shadowOffsetY']
                if 'shadowColorHex' in s:
                    ms['shadowColorHex'] = s['shadowColorHex']
            if 'strokeWidth' in s:
                ms['strokeWidth'] = s['strokeWidth']
                if 'strokeColorHex' in s:
                    ms['strokeColorHex'] = s['strokeColorHex']
            manifest_slots.append(ms)

            # For banner preview (stitched horizontal)
            bs = dict(ms)
            bs['x'] = round(ms['x'] + ab_x, 4)
            bs['y'] = round(ms['y'] + ab_y, 4)
            all_banner_slots.append(bs)

        bg_name = f'redbook_bg_{ab_idx+1}.png'
        manifest = {
            'id': f'picpark-redbook-{ab_idx+1}',
            'name': f'PicPark · {roles[ab_idx]}',
            'width': int(ab_w),
            'height': int(ab_h),
            'slots': manifest_slots,
            'cornerRadius': 20.0,
            'shadowOpacity': 0.0,
            'shadowColorHex': '#B1C4E9',
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

    # Combined RedBook Manifest (7600 x 1920)
    redbook_manifest = {
        'id': 'picpark-redbook',
        'name': 'PicPark · 小红书卡片（1–34）',
        'width': 7600,
        'height': 1920,
        'slots': all_banner_slots,
        'cornerRadius': 20.0,
        'shadowOpacity': 0.0,
        'shadowColorHex': '#B1C4E9',
        'imageFit': 'fill',
        'backgroundImageName': 'redbook_bg_banner.png',
        'sourceName': source.name,
        'subTemplates': artboard_manifests
    }

    return redbook_manifest, evidence


def export_assets_and_manifests(source):
    psd = PSDImage.open(source)
    artboards = list(psd)

    out_tpl = ROOT / 'Templates' / 'PicPark_RedBook'
    out_tpl_assets = out_tpl / 'assets'
    out_tpl_assets.mkdir(parents=True, exist_ok=True)

    out_bundle_assets = ROOT / 'Sources' / 'PPTTools' / 'Resources' / 'HeroAssets'
    out_bundle_assets.mkdir(parents=True, exist_ok=True)

    print("Generating clean redbook banner and artboard backgrounds...")
    banner_canvas = Image.new('RGBA', (7600, 1920), (0, 0, 0, 0))

    for ab_idx, ab in enumerate(artboards):
        canvas = Image.new('RGBA', (1440, 1920), (0, 0, 0, 0))
        draw_clean_layers(ab, canvas, ab.bbox[0], ab.bbox[1])
        banner_canvas.alpha_composite(canvas, (ab.bbox[0], ab.bbox[1]))
        bg_filename = f'redbook_bg_{ab_idx+1}.png'
        canvas.save(out_tpl_assets / bg_filename, 'PNG')
        canvas.save(out_bundle_assets / bg_filename, 'PNG')
        print(f"  Saved {bg_filename}")

    banner_canvas.save(out_tpl_assets / 'redbook_bg_banner.png', 'PNG')
    banner_canvas.save(out_bundle_assets / 'redbook_bg_banner.png', 'PNG')
    print("  Saved redbook_bg_banner.png")

    redbook_manifest, evidence = measure(source)

    # Save template.json in Templates/PicPark_RedBook
    (out_tpl / 'template.json').write_text(json.dumps(redbook_manifest, ensure_ascii=False, indent=2) + '\n')

    # Update Sources/PPTTools/Resources/templates.json
    res_tpl_path = ROOT / 'Sources' / 'PPTTools' / 'Resources' / 'templates.json'
    existing = []
    if res_tpl_path.exists():
        existing = json.loads(res_tpl_path.read_text())

    # Keep non-redbook templates
    updated = [t for t in existing if not t.get('id', '').startswith('picpark-redbook')]
    updated.append(redbook_manifest)

    res_tpl_path.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + '\n')
    print(f"Updated {res_tpl_path} with redbook template (total {len(updated)} templates).")

    # Documentation
    proof = ROOT / 'docs' / 'template-measurements'
    proof.mkdir(parents=True, exist_ok=True)
    (proof / 'picpark-redbook-measurements.json').write_text(json.dumps({
        'source': source.name,
        'sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'artboards': evidence
    }, ensure_ascii=False, indent=2) + '\n')
    print(f"Saved measurement proof to {proof / 'picpark-redbook-measurements.json'}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    export_assets_and_manifests(parser.parse_args().source)
