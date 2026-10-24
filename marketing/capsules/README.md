# Steam capsule artwork

The store art uses the game's actual `menu_diorama.gd` voxel board and
`godot/assets/icon.svg` cube. The title is composed as vector typography in
ivory and amber. Each aspect ratio has its own composition; these are capsule
illustrations, not gameplay screenshots. There are no review quotes, discount
badges, release dates, feature promises, or Steam Deck verification claims.

## Outputs

Files go to ignored `release/marketing/capsules/`.

| File | Dimensions | Steam field |
| --- | --- | --- |
| `header-capsule.png` | 920 × 430 | Header Capsule |
| `small-capsule.png` | 462 × 174 | Small Capsule |
| `main-capsule.png` | 1232 × 706 | Main Capsule |
| `vertical-capsule.png` | 748 × 896 | Vertical Capsule |
| `library-capsule.png` | 600 × 900 | Library Capsule |
| `library-header.png` | 920 × 430 | Library Header |
| `library-hero.png` | 3840 × 1240 | Library Hero; no text or logo |
| `library-logo.png` | 1280 × 500 | Library Logo; transparent background |
| `page-background.png` | 1438 × 810 | Optional page background; no text |
| `shortcut-icon.png` | 512 × 512 | Shortcut icon |
| `app-icon.jpg` | 184 × 184 | App icon |
| `linux-icons.zip` | 16 through 512 px | Optional native Linux icon set |

`capsule-proof.jpg` shows the compositions at reduced sizes for internal visual
QA; it is not a Steam upload. The manifest records exact dimensions, byte
counts, and SHA-256 hashes. The logo is intended to be placed toward the
lower-left in Steam's library logo placement tool, over the hero's empty area.

## Rebuild

Dependencies: Godot 4.7.2, a real GLES renderer (Mesa/Xvfb is sufficient for
this Canvas drawing), Inkscape, DejaVu Sans, Python 3 with Pillow. From the
repository root, choose a free X display number and run:

```bash
xvfb-run -n 237 -l \
  -s '-screen 0 1280x800x24 -nolisten local -nolisten unix -listen tcp' \
  env DISPLAY=127.0.0.1:237 /path/to/godot \
  --path godot --audio-driver Dummy --rendering-method gl_compatibility \
  --rendering-driver opengl3_es --script ../marketing/capsules/capture_diorama.gd
python3 marketing/capsules/render_capsules.py
```

The capture reads the shipping menu-art script without modifying it. Every
vector export is rendered into a unique temporary directory and fully decoded
before it is copied to the final output. This prevents accepting a partial
PNG export. Final title readability was checked at 231 × 87 (small capsule),
460 × 215 (header), and corresponding reduced library sizes.

Dimensions were checked against the Steamworks upload fields and Valve's
[store artwork](https://partner.steamgames.com/doc/store/assets/standard) and
[library artwork](https://partner.steamgames.com/doc/store/assets/libraryassets)
documentation on October 24, 2026. Recheck those requirements before future
platform artwork changes.
