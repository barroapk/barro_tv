# Génère l'icône de BARRO TV : un « B » rouge avec un bouton lecture dans le ventre.
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
FOND = (11, 11, 15, 255)

def degrade():
    g = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(g)
    a, b, c = (255, 90, 90), (229, 9, 20), (130, 0, 8)
    for i in range(2 * S):
        t = i / (2 * S)
        if t < 0.5:
            u = t * 2; col = tuple(int(a[k] + (b[k] - a[k]) * u) for k in range(3))
        else:
            u = (t - 0.5) * 2; col = tuple(int(b[k] + (c[k] - b[k]) * u) for k in range(3))
        d.line([(i, 0), (0, i)], fill=col + (255,), width=2)
    return g

def dessiner(e, avec_fond, avec_halo=True):
    def P(x, y):  # met à l'échelle autour du centre
        return (S / 2 + (x - S / 2) * e, S / 2 + (y - S / 2) * e)
    def R(x0, y0, x1, y1):
        p0, p1 = P(x0, y0), P(x1, y1)
        return [p0[0], p0[1], p1[0], p1[1]]

    img = Image.new("RGBA", (S, S), FOND if avec_fond else (0, 0, 0, 0))
    dx = 12
    x0, y0, y1, T = 290 + dx, 212, 812, 120
    haut = (x0, y0, 650 + dx, 548)
    bas = (x0, 428, 720 + dx, y1)

    forme = Image.new("L", (S, S), 0)
    f = ImageDraw.Draw(forme)
    f.rounded_rectangle(R(*haut), int(168 * e), fill=255)
    f.rounded_rectangle(R(*bas), int(192 * e), fill=255)
    f.rectangle(R(x0, y0, x0 + T, y1), fill=255)
    # coins gauches bien droits
    f.rectangle(R(x0, y0, x0 + 200, y0 + 200), fill=255)
    f.rectangle(R(x0, y1 - 200, x0 + 200, y1), fill=255)
    # trou du haut
    f.rounded_rectangle(R(x0 + T, y0 + T, 650 + dx - T, 548 - T), int(48 * e), fill=0)

    # halo rouge
    if avec_halo:
        halo = Image.new("RGBA", (S, S), (229, 9, 20, 0))
        halo.putalpha(forme.point(lambda v: int(v * 0.55)).filter(ImageFilter.GaussianBlur(70 * e)))
        img.alpha_composite(halo)

    lettre = degrade()
    lettre.putalpha(forme)
    img.alpha_composite(lettre)

    # bouton lecture blanc dans le ventre du B
    tri = [P(430 + dx, 562), P(430 + dx, 690), P(596 + dx, 626)]
    ombre = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).polygon([(x, y + 10 * e) for x, y in tri], fill=(70, 0, 0, 140))
    img.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(12 * e)))
    ImageDraw.Draw(img).polygon(tri, fill=(255, 255, 255, 255))
    return img

dossier = os.path.dirname(os.path.abspath(__file__))
dessiner(0.95, True).save(os.path.join(dossier, "icone.png"))
dessiner(0.75, False).save(os.path.join(dossier, "icone_fg.png"))
logo = dessiner(1.0, False, False)
logo = logo.crop(logo.getbbox())
logo.thumbnail((256, 256))
logo.save(os.path.join(dossier, "logo.png"))
print("Icônes BARRO TV créées")
