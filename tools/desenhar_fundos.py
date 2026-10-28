"""Gera fundos SVG estáticos nas coordenadas das paredes de cada fase.

Execute da raiz do projeto: python3 tools/desenhar_fundos.py
Não depende da Godot nem executa trabalho durante o jogo.
"""
import base64
from pathlib import Path
import random
import re
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/backgrounds/mapas"


def desenhar(nome, cells, bounds):
    rng = random.Random(nome)
    x0, y0, x1, y1 = bounds
    width, height = x1 - x0, y1 - y0
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="{x0} {y0} {width} {height}">',
             '<defs>'
             '<radialGradient id="ambiente"><stop stop-color="#38394a"/><stop offset="1" stop-color="#282837"/></radialGradient>'
             '<radialGradient id="mineral"><stop stop-color="#7eac96" stop-opacity="0.22"/><stop offset="0.4" stop-color="#658e80" stop-opacity="0.1"/><stop offset="1" stop-color="#658e80" stop-opacity="0"/></radialGradient>'
             '<radialGradient id="contraste"><stop stop-color="#7a7b92" stop-opacity="0.2"/><stop offset="1" stop-color="#7a7b92" stop-opacity="0"/></radialGradient>'
             '</defs>',
             f'<path fill="url(#ambiente)" d="M{x0} {y0}h{width}v{height}H{x0}z"/>']

    def rect(x, y, w, h, color):
        parts.append(f'<path fill="{color}" d="M{x} {y}h{w}v{h}h{-w}z"/>')

    # Massas de pedra em degraus de pixels, com espaços de sombra entre elas.
    # Paleta derivada dos blocos: roxo carvão, terra e verde acinzentado.
    for _ in range(max(12, width * height // 1800)):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        w, h = rng.randrange(16, 60, 4), rng.randrange(8, 32, 4)
        inset = rng.randrange(2, 8, 2)
        color = rng.choice(["#2c2b3b", "#302d3d", "#2d343c", "#34303e"])
        points = [(x+inset,y),(x+w-8,y),(x+w-8,y+2),(x+w,y+2),
                  (x+w,y+h-4),(x+w-4,y+h-4),(x+w-4,y+h),
                  (x+4,y+h),(x+4,y+h-2),(x,y+h-2),(x,y+4),(x+inset,y+4)]
        parts.append(f'<polygon fill="{color}" points="'+ ' '.join(f'{px},{py}' for px,py in points)+'"/>')
        if rng.random() < 0.4:
            rect(x+inset+2, y+2, max(2, w//3), 1, "#3c3947")

    occupied = {(x, y) for x, y, *_ in cells}
    permanent = {(x, y) for x, y, source, *_ in cells if source not in (0, 2, 4, 11, 12)}
    # Raízes discretas nascem no teto real e param antes de outro bloco.
    # O desenho continua atrás dos tiles, preservando a leitura das colisões.
    for x, y in sorted(permanent):
        if (x, y+1) in occupied or rng.random() > 0.24:
            continue
        px, py = x*16+rng.randrange(3, 13), (y+1)*16
        length = rng.randrange(6, 26)
        for step in range(length):
            if (px//16, (py+step)//16) in occupied:
                break
            if step % 4 == 0:
                px += rng.choice([-1, 0, 1])
            rect(px, py+step, 1, 1, "#343a38")
            if step % 6 == 2:
                rect(px+1, py+step, 2, 1, "#3c4940")

    # Fissuras pequenas mantêm a textura de rocha discreta.
    for _ in range(width * height // 1500):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        rect(x, y, rng.randrange(2, 6), 1, "#242431")
        rect(x+1, y+1, 1, 2, "#242431")

    # Luz já desenhada na imagem: sem PointLight2D, shader ou processamento.
    # Um realce neutro atrás de cada espinho destaca sua silhueta escura.
    spikes = [(x*16+8, y*16+8) for x, y, source, *_ in cells if source in (11, 12)]
    for px, py in spikes:
        parts.append(f'<circle cx="{px}" cy="{py}" r="26" fill="url(#contraste)"/>')

    # Minerais presos à rocha de fundo perto de paredes reais, espaçados e
    # afastados dos espinhos para não confundir perigo com decoração.
    candidates = set()
    for x, y in permanent:
        for dx, dy in [(0, -1), (0, 1), (-1, 0), (1, 0)]:
            if (x+dx, y+dy) not in occupied:
                candidates.add(((x+dx)*16+8, (y+dy)*16+8))
    candidates = sorted(candidates)
    rng.shuffle(candidates)
    stones = []
    for px, py in candidates:
        if any((px-sx)**2+(py-sy)**2 < 80**2 for sx, sy in stones):
            continue
        if any((px-sx)**2+(py-sy)**2 < 40**2 for sx, sy in spikes):
            continue
        stones.append((px, py))
        parts.append(f'<circle cx="{px}" cy="{py}" r="48" fill="url(#mineral)"/>')
        # Pequena pedra irregular com veio luminoso, usando pixels inteiros.
        parts.append(f'<path fill="#424e50" d="M{px-4} {py-2}h2v-2h5v2h2v5h-2v1h-6v-2h-1z"/>')
        rect(px-2, py-2, 3, 1, "#7b9f90")
        rect(px, py-1, 1, 3, "#98b7a2")
        rect(px+1, py+1, 2, 1, "#729381")
    parts.append('</svg>')
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / f'{nome}.svg').write_text('\n'.join(parts) + '\n')


def atualizar(path):
    text = path.read_text()
    layer = re.search(r'\[node name="Blocos"[^\n]*\]\n(.*?)(?=\n\[|\Z)', text, re.S)
    cells = []
    if layer:
        data = re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', layer[1])
        raw = base64.b64decode(data[1])
        # Godot 4: cabeçalho uint16 seguido de registros de 12 bytes.
        assert len(raw) % 12 == 2
        cells = [struct.unpack_from('<hhHHHH', raw, i) for i in range(2, len(raw), 12)]
        bounds = (min(c[0] for c in cells)*16-128, min(c[1] for c in cells)*16-128,
                  (max(c[0] for c in cells)+1)*16+128, (max(c[1] for c in cells)+1)*16+128)
    else:
        # A abertura usa Polygon2D, com paredes em x=0 e x=48, y=0..600.
        assert path.stem == 'queda_inicial'
        bounds = (-528, -256, 576, 856)
    desenhar(path.stem, cells, bounds)
    text = re.sub(r'^\[ext_resource[^\n]*id="fundo_compartilhado"\]\n', '', text, flags=re.M)
    # Retira somente os sprites de fundo antigos; preserva luzes e objetos.
    text = re.sub(r'\n\[node name="(?:FundoCompartilhado|FundoCaverna|FundoMapa01V2|FundoDaFase)"[^\n]*\]\n.*?(?=\n\[|\Z)', '\n', text, flags=re.S)
    text = re.sub(r'^\[ext_resource[^\n]*path="res://assets/backgrounds/fundo_mapa_01_v2.png"[^\n]*\]\n', '', text, flags=re.M)
    text = re.sub(r'\n\[sub_resource[^\n]*id="(?:Shader_fundo_claro|ShaderMaterial_fundo_claro)"\]\n.*?(?=\n\[|\Z)', '\n', text, flags=re.S)
    text = re.sub(r'^\[ext_resource[^\n]*id="fundo_exclusivo"\]\n', '', text, flags=re.M)
    at = text.index('[sub_resource') if '[sub_resource' in text else text.index('[node')
    resource = f'[ext_resource type="Texture2D" path="res://assets/backgrounds/mapas/{path.stem}.svg" id="fundo_exclusivo"]\n\n'
    text = text[:at] + resource + text[at:]
    material = '[sub_resource type="CanvasItemMaterial" id="Material_fundo_estatico"]\nlight_mode = 1\n\n'
    if 'id="Material_fundo_estatico"' not in text:
        at = text.index('[node')
        text = text[:at] + material + text[at:]
    text += f'\n[node name="FundoDaFase" type="Sprite2D" parent="."]\nz_index = -100\ntexture_filter = 1\nmaterial = SubResource("Material_fundo_estatico")\nposition = Vector2({bounds[0]}, {bounds[1]})\ntexture = ExtResource("fundo_exclusivo")\ncentered = false\n'
    path.write_text(text)
    print(f'{path.stem}: {bounds[2]-bounds[0]} × {bounds[3]-bounds[1]} px; {len(cells)} tiles')


if __name__ == '__main__':
    for scene in sorted(ROOT.glob('mapa_*.tscn')) + [ROOT/'tutorial.tscn', ROOT/'queda_inicial.tscn']:
        atualizar(scene)
