"""Gera rochas fixas SVG de 16px para composição dos mapas.

Apesar do nome histórico da pasta, estes tiles NÃO caem.

Execute da raiz: python3 tools/gerar_blocos_instaveis.py
Fontes fixas no blocos_tileset.tres: 19 (ardósia), 20 (verde), 21 (terra).
"""
from pathlib import Path
import random

ROOT = Path(__file__).resolve().parents[1]
PALETAS = {
    "ardosia": ["#292935", "#33333f", "#40404c", "#20202b", "#51505b"],
    "verde": ["#293330", "#333e38", "#434e43", "#202925", "#566153"],
    "terra": ["#38302c", "#443b33", "#54493e", "#2b2524", "#685a4b"],
}


def desenhar(nome, cores):
    rng = random.Random(nome)
    partes = ['<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">']

    def rect(x, y, w, h, cor):
        partes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{cor}"/>')

    rect(0, 0, 16, 16, cores[0])
    for y in (1, 5, 9, 13):
        for x in (1, 8):
            rect(x + rng.randrange(2), y, rng.randrange(4, 7), 2, cores[1])
    for _ in range(12):
        rect(rng.randrange(1, 14), rng.randrange(1, 15), 1, 1, rng.choice(cores[1:3]))
    # Estratos quebrados, sem desenhar uma grade ou contornar o tile.
    for x, y, w in ((2, 4, 4), (9, 8, 5), (1, 12, 5)):
        rect(x, y, w, 1, cores[3])
        rect(x, y - 1, max(1, w - 2), 1, cores[2])
    rect(12, 3, 2, 1, cores[4])
    partes.append('</svg>')
    return '\n'.join(partes) + '\n'


if __name__ == "__main__":
    pasta = ROOT / "assets/blocos_instaveis"
    pasta.mkdir(exist_ok=True)
    for nome, cores in PALETAS.items():
        (pasta / f"{nome}.svg").write_text(desenhar(nome, cores))
