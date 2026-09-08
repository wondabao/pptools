#!/usr/bin/env python3
"""Measure PicPark's 1–35 detail template. Build-time only; never modifies PSD.

PYTHONPATH=.build/psd-deps python3 scripts/measure-picpark.py \
  '/Users/anchor/Desktop/PicPark/详情页（1-35）.psd'
Dependencies: psd-tools==1.10.9 (Pillow is included).
"""
import argparse
import hashlib
import json
from pathlib import Path
from psd_tools import PSDImage

ROOT = Path(__file__).resolve().parents[1]


def measure(source):
    psd = PSDImage.open(source)
    shapes = sorted((l for l in psd if l.kind == 'shape' and l.visible and l.name.isdigit()), key=lambda l: int(l.name))
    if [int(l.name) for l in shapes] != list(range(1, 36)):
        raise ValueError('Expected exactly 35 numbered clipping shapes')
    background = psd[0].topil().convert('RGB')
    extrema = background.getextrema()
    if any(low != high for low, high in extrema):
        raise ValueError('Background is no longer a solid color; re-measure asset requirements')
    rgb = tuple(low for low, high in extrema)
    slots, evidence = [], []
    for layer in shapes:
        origins = layer.origination
        if len(origins) != 1 or layer.has_effects():
            raise ValueError('Unsupported shape origination or layer effects')
        shape = origins[0]
        left, top, right, bottom = map(float, shape.bbox)
        radii = [float(shape.radii[key]) for key in (b'topLeft', b'topRight', b'bottomLeft', b'bottomRight')]
        if max(radii) - min(radii) > 0.0001:
            raise ValueError('Nonuniform radii need a path renderer')
        # Cross-check editable shape descriptors against the actual Bezier path.
        anchors = [k.anchor for path in layer.vector_mask.paths for k in path]
        vector_bbox = [min(a[1] for a in anchors) * psd.width,
                       min(a[0] for a in anchors) * psd.height,
                       max(a[1] for a in anchors) * psd.width,
                       max(a[0] for a in anchors) * psd.height]
        if max(abs(a-b) for a, b in zip(shape.bbox, vector_bbox)) > 0.002:
            raise ValueError('Shape descriptor and actual mask disagree')
        slots.append(dict(x=round(left, 6), y=round(top, 6), width=round(right-left, 6), height=round(bottom-top, 6)))
        evidence.append(dict(page=int(layer.name), rasterBounds=list(layer.bbox),
                             vectorShapeBounds=list(shape.bbox), vectorPathBounds=vector_bbox,
                             cornerRadius=radii[0]))
    if len(set(e['cornerRadius'] for e in evidence)) != 1:
        raise ValueError('Mixed corner radii require per-slot styling')
    template = dict(id='picpark-detail-35', name='PicPark · 详情页（1–35）',
                    width=psd.width, height=psd.height, slots=slots,
                    backgroundHex='#%02X%02X%02X' % rgb,
                    cornerRadius=evidence[0]['cornerRadius'], shadowOpacity=0,
                    imageFit='fill', trimsToContent=True,
                    bottomPadding=round(psd.height-max(s['y']+s['height'] for s in slots), 6),
                    sourceName=source.name)
    return template, evidence


def write_outputs(source):
    template, evidence = measure(source)
    out = ROOT / 'Templates' / 'PicPark_Detail_35'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'template.json').write_text(json.dumps(template, ensure_ascii=False, indent=2)+'\n')
    # Same generated configuration powers the standalone package and bundled app.
    (ROOT / 'Sources/PPTTools/Resources/templates.json').write_text(json.dumps([template], ensure_ascii=False, indent=2)+'\n')
    proof = ROOT / 'docs/template-measurements'
    proof.mkdir(parents=True, exist_ok=True)
    (proof / 'picpark-detail-35-measurements.json').write_text(json.dumps(dict(
        source=source.name, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        coordinateOrigin='top-left', unit='px', method='vogk rounded rectangle verified against vsms Bezier anchors',
        slots=evidence), ensure_ascii=False, indent=2)+'\n')
    # A code-generated wireframe is for measurement QA, not a raster copy of the PSD.
    rects = []
    for i, s in enumerate(template['slots']):
        rects.append(f'<rect x="{s["x"]}" y="{s["y"]}" width="{s["width"]}" height="{s["height"]}" rx="20" fill="white"/>')
        rects.append(f'<text x="{s["x"]+s["width"]/2}" y="{s["y"]+s["height"]/2}" text-anchor="middle" dominant-baseline="middle" font-family="sans-serif" font-size="96" fill="#2457F0">{i+1:02d}</text>')
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1872" height="10234" viewBox="0 0 1872 10234"><rect width="1872" height="10234" fill="{template["backgroundHex"]}"/>'+''.join(rects)+'</svg>'
    (proof / 'picpark-detail-35-wireframe.svg').write_text(svg)
    print(json.dumps(dict(output=str(out/'template.json'), pages=len(evidence), cover=template['slots'][0], firstRow=template['slots'][1:3], bottomPadding=template['bottomPadding']), ensure_ascii=False, indent=2))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    write_outputs(parser.parse_args().source)
