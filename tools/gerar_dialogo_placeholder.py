#!/usr/bin/env python3
"""Gera a arte placeholder do sistema de dialogo em assets/dialogo/.

UI (ornamento, broto, vagalume do avancar) ja sai "assada" em 3x: 1 pixel de
arte = 3 px de tela, que e o P de UI/dialogo/dialogue_box.gd. Retratos 32x32 sao o sprite
do personagem ampliado 2x + uma marquinha por expressao -- e so substituir pelos
PNGs de verdade (mesmo nome). Vozes: 4 resmungos curtos por personagem.

Uso:  python3 tools/gerar_dialogo_placeholder.py
"""
import math, os, struct, wave
from PIL import Image
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = 3
NAVY = (0x1a, 0x1a, 0x2e, 255)
BORDA = (0xe8, 0xe8, 0xf0, 255)
T = (0, 0, 0, 0)
C = {'.': T, 'B': BORDA, 'F': NAVY}

def salvar(linhas, path, escala=P):
    h, w = len(linhas), len(linhas[0])
    img = Image.new('RGBA', (w * escala, h * escala), T)
    for y, l in enumerate(linhas):
        for x, ch in enumerate(l):
            for dy in range(escala):
                for dx in range(escala):
                    img.putpixel((x * escala + dx, y * escala + dy), C[ch])
    img.save(path)

d = R + '/assets/dialogo/'
# Ornamento: linha fina pontilhada (repete na horizontal) + broto no meio.
ORN = (0xc9, 0xc2, 0xa8, 255)
C['o'] = ORN; C['g'] = (0x8f, 0xd1, 0x7a, 255); C['v'] = (0x5e, 0x9e, 0x4f, 255)
salvar(["ooooo."], d + 'ornamento_linha.png')
salvar(["....g.g....",
        "...ggvgg...",
        "....gvg....",
        ".....v.....",
        "oooo.v.oooo"], d + 'ornamento_broto.png')
# Vagalume do "avancar": miolo azul + brilho em volta.
C['a'] = (0x7e, 0xc8, 0xff, 255); C['l'] = (0x7e, 0xc8, 0xff, 110); C['w'] = (0xe6, 0xf6, 0xff, 255)
salvar([".l.l.", "laaal", ".awa.", "laaal", ".l.l."], d + 'vagalume_avancar.png')
# Indicador "!" no mundo (escala 1: pixel do mundo, igual ao resto da arte).
C['L'] = BORDA; C['#'] = (0x10, 0x10, 0x1c, 255)
salvar([".###.", ".#L#.", ".#L#.", ".#L#.", ".#L#.", ".###.", ".#L#.", ".###."], d + 'indicador.png', 1)

# Retratos placeholder 32x32: frame do sprite ampliado 2x + marquinha da expressao.
MARCAS = {
    'neutro': [],
    'surpreso': [(27, 2), (27, 3), (27, 4), (27, 6), (28, 2), (28, 3), (28, 4), (28, 6)],
    'feliz': [(25, 3), (27, 3), (24, 4), (25, 4), (26, 4), (27, 4), (28, 4), (25, 5), (26, 5), (27, 5), (26, 6)],
    'triste': [(27, 2), (26, 3), (27, 3), (28, 3), (26, 4), (27, 4), (28, 4), (27, 5)],
}
COR_MARCA = {'surpreso': (255, 230, 120, 255), 'feliz': (255, 120, 160, 255), 'triste': (120, 180, 255, 255)}
def retratos(nome, sheet, regiao):
    src = Image.open(R + '/assets/' + sheet).convert('RGBA').crop(regiao).resize((32, 32), Image.NEAREST)
    for expr, pts in MARCAS.items():
        img = src.copy()
        for p in pts:
            img.putpixel(p, COR_MARCA[expr])
        img.save(d + 'retratos/%s_%s.png' % (nome, expr))
retratos('caracol', 'caracol.png', (64, 0, 80, 16))
retratos('elisio', 'Eli.png', (0, 0, 16, 16))

# Vozes (estilo Hollow Knight): resmungos curtos, cada um com uma curva de
# pitch diferente. O jogo sorteia um a cada ~4-6 letras e varia o pitch.
def resmungo(path, freq, glide, dur, sr=22050, vol=0.32):
    n = int(sr * dur)
    fase = 0.0
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        fr = b''
        for i in range(n):
            t = i / n
            f = freq * (1 + glide * t) * (1 + 0.03 * math.sin(2 * math.pi * 28 * i / sr))
            fase += 2 * math.pi * f / sr
            env = min(1.0, t * 12) * (1 - t) ** 1.5
            s = math.sin(fase) + 0.45 * math.sin(2 * fase) + 0.25 * math.sin(3 * fase + 0.5)
            fr += struct.pack('<h', int(max(-1, min(1, vol * env * s / 1.4)) * 32767))
        w.writeframes(fr)
for nome, base in (('caracol', 210), ('elisio', 300)):
    for i, (mult, glide, dur) in enumerate([(1.0, 0.25, 0.09), (1.12, -0.2, 0.08), (0.92, 0.4, 0.11), (1.05, -0.35, 0.07)], 1):
        resmungo(d + 'sons/voz_%s_%d.wav' % (nome, i), base * mult, glide, dur)
