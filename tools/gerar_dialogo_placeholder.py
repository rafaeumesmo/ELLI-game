#!/usr/bin/env python3
"""Gera a arte placeholder do sistema de dialogo em assets/dialogo/.

UI (moldura, aba, rabicho, seta) ja sai "assada" em 3x: 1 pixel de arte = 3 px
de tela, que e o P de UI/dialogo/dialogue_box.gd. Retratos 32x32 sao o sprite
do personagem ampliado 2x + uma marquinha por expressao -- e so substituir pelos
PNGs de verdade (mesmo nome). Bips: onda quadrada curtinha.

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
# Moldura 9-patch 7x7 com cantos chanfrados (margem 3 px de arte = 9 px).
salvar(["..BBB..", ".BFFFB.", "BFFFFFB", "BFFFFFB", "BFFFFFB", ".BFFFB.", "..BBB.."], d + 'moldura.png')
# Aba de nome: 8 linhas visiveis + 3 que cobrem o canto de cima da caixa.
esq = ["..B", ".BF"] + ["BFF"] * 9
meio = ["B"] + ["F"] * 10
dir_ = []
for r in range(11):
    if r < 8:
        dir_.append(''.join('B' if c == r else ('F' if c < r else '.') for c in range(9)))
    elif r == 8:
        dir_.append("FFFFFFFFB")
    else:
        dir_.append("FFFFFFFFF")
salvar([esq[r] + meio[r] + dir_[r] for r in range(11)], d + 'aba_nome.png')
# Rabicho: a 1a linha cobre a borda de baixo da caixa.
salvar(["BFFFFFB", ".BFFFB.", "..BFB..", "...B..."], d + 'rabicho.png')
# Seta de "proxima pagina".
C['B'] = BORDA
salvar(["BBBBB", ".BBB.", "..B.."], d + 'seta.png')
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

# Bips: onda quadrada curtinha com decaimento.
def bip(path, freq, dur=0.045, sr=22050, vol=0.35):
    n = int(sr * dur)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        fr = b''
        for i in range(n):
            env = (1 - i / n) ** 2
            s = vol * env * (1 if math.sin(2 * math.pi * freq * i / sr) >= 0 else -1)
            fr += struct.pack('<h', int(s * 32767))
        w.writeframes(fr)
bip(d + 'sons/bip_caracol.wav', 330)
bip(d + 'sons/bip_elisio.wav', 620)
