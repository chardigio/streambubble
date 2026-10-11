"""Writes squircle.path: Apple's continuous-corner rounded rectangle for a macOS app icon.

An 824 x 824 shape at (100, 100) on a 1024 canvas, corner radius 185. A plain rounded
rectangle (arcs) has a visible kink where the corner meets the side; Apple's shape blends
into the side over a longer run, and an icon with arcs looks wrong next to Apple's own.
The coefficients are the published approximation of that curve, in units of the radius.
"""

import pathlib

X0 = Y0 = 100.0
SIZE = 824.0
R = 185.0
A, B, C, D, E, F, G = 1.52866483, 1.08849323, 0.86840689, 0.63149399, 0.37282392, 0.16905899, 0.07491100


def point(x: float, y: float) -> str:
    return f"{x:.2f},{y:.2f}"


def squircle_path() -> str:
    x1, y1 = X0 + SIZE, Y0 + SIZE
    r = R
    parts = [
        f"M{point(X0 + A * r, Y0)}",
        f"L{point(x1 - A * r, Y0)}",
        f"C{point(x1 - B * r, Y0)} {point(x1 - C * r, Y0)} {point(x1 - D * r, Y0 + G * r)}",
        f"C{point(x1 - E * r, Y0 + F * r)} {point(x1 - F * r, Y0 + E * r)} {point(x1 - G * r, Y0 + D * r)}",
        f"C{point(x1, Y0 + C * r)} {point(x1, Y0 + B * r)} {point(x1, Y0 + A * r)}",
        f"L{point(x1, y1 - A * r)}",
        f"C{point(x1, y1 - B * r)} {point(x1, y1 - C * r)} {point(x1 - G * r, y1 - D * r)}",
        f"C{point(x1 - F * r, y1 - E * r)} {point(x1 - E * r, y1 - F * r)} {point(x1 - D * r, y1 - G * r)}",
        f"C{point(x1 - C * r, y1)} {point(x1 - B * r, y1)} {point(x1 - A * r, y1)}",
        f"L{point(X0 + A * r, y1)}",
        f"C{point(X0 + B * r, y1)} {point(X0 + C * r, y1)} {point(X0 + D * r, y1 - G * r)}",
        f"C{point(X0 + E * r, y1 - F * r)} {point(X0 + F * r, y1 - E * r)} {point(X0 + G * r, y1 - D * r)}",
        f"C{point(X0, y1 - C * r)} {point(X0, y1 - B * r)} {point(X0, y1 - A * r)}",
        f"L{point(X0, Y0 + A * r)}",
        f"C{point(X0, Y0 + B * r)} {point(X0, Y0 + C * r)} {point(X0 + G * r, Y0 + D * r)}",
        f"C{point(X0 + F * r, Y0 + E * r)} {point(X0 + E * r, Y0 + F * r)} {point(X0 + D * r, Y0 + G * r)}",
        f"C{point(X0 + C * r, Y0)} {point(X0 + B * r, Y0)} {point(X0 + A * r, Y0)}",
        "Z",
    ]
    return " ".join(parts)


if __name__ == "__main__":
    (pathlib.Path(__file__).parent / "squircle.path").write_text(squircle_path() + "\n")
