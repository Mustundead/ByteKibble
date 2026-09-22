# ByteKibble native icon — 2026-09-12

Current candidate after junction regression fix: `output/acceptance/release.Vah7Of/ByteKibble.app`. The side/base Bezier join now has aligned tangent directions, restoring a rounded continuous bottom corner without restoring the removed outer shadow strip. Inspected white-background 3x detail and native dark glass render; all icon previews regenerated. Packaging and signature verification passed. All earlier candidate paths below are historical.

Latest lower-right refinement: removed the remaining baked brown ground-shadow strip with a targeted curve adjustment. White-background 3x detail in `IconPreviews/edge-detail.png` confirms the orange rim now meets the transparent boundary directly. Current candidate: `output/acceptance/release.DdDc8Y/ByteKibble.app`, superseding all paths below. Native light/dark/64px renders regenerated and local signature verification passed; glass settings unchanged.

Latest edge correction: user identified leftover background on the right flank, left slope and base. Refit the matte to measured source color-transition coordinates, inset about 1.5–2 source pixels at contaminated boundaries. Inspected the raw cutout on black and white at 1024px before re-enabling native glass; preserved the source bag artwork and full-layer glass settings. Current candidate is `output/acceptance/release.dsdkdg/ByteKibble.app`; it supersedes release.JV8Vd7 below. Both appearances and the 64px dark preview were regenerated. Local package/signature verification passed. Black/white diagnostic renders: `output/icon-work/black-matte-v2.png` and `white-matte-v2.png`.

Current source: `ByteKibble.icon`. The older `AppIcon.icon`, `AppIcon.icns` and `Assets.xcassets` are historical and no longer consumed by either packaging script.

## Source and treatment

User-approved `IconReference.png` is the exact supplied two-icon sheet (SHA-256 `f41a5e08b9c44d19e55d8895a664f233fed370bd0ca33e2be9ea60d9f8d9e23d`). Only the left bag is used. Its original pixels, paw and perspective are retained, resampled into a transparent 1024px canvas. A 4x supersampled CoreGraphics Bezier matte follows the silhouette and avoids clipping.

Rejected: two ImageGen extractions had baked-in checkerboards/no alpha; neither is used. Native Vision initially produced noisy contours and holes, visibly exaggerated by glass. Those masks were replaced with the deterministic smooth matte. No generated foreground or painted glass border is in the final source.

Reproduce cutout: `swift scripts/extract-icon.swift Resources/IconReference.png Resources/ByteKibble.icon/Assets/bag.png`.

## Native material and compilation

Icon Composer document has the full bag layer's glass enabled, with 65% refraction strength/depth, 40% translucency and inside specular. The document uses warm light and charcoal dark background specializations. Both appearance previews were inspected at 512px; dark was also inspected at 64px. Native Icon Composer UI confirmed the enabled settings and smooth full-size appearance. Preview PNGs in `IconPreviews/` are Apple ictool renders, not the actual runtime icon format.

The approach follows [Apple Icon Composer](https://developer.apple.com/icon-composer/): imported transparent artwork gets native materials, while the system supplies the icon shape/appearance treatment. Adopted native rendering and separate background/foreground; rejected an opaque precomposed tile and uncompiled `.icon` copied into the bundle.

`bash scripts/compile-icon.sh output/icon-work` compiles with Apple's actool. Outputs are `Assets.car` (appearance/material resources), `ByteKibble.icns` (legacy fallback), and icon metadata. Both packaging scripts consume these outputs and set `CFBundleIconName` and `CFBundleIconFile` to ByteKibble.

Current candidate: `output/acceptance/release.JV8Vd7/ByteKibble.app`, 1.2.0 (40). This supersedes release.j0zDEm's icon despite the unchanged app version. Signature verification passed; assetutil confirmed Aqua/DarkAqua and icon-size renditions. Assets.car SHA-256: `afbb3f17af7ea3a8d9f95fecc73e9d1b7edac012891395bdb627b0a3bc34b67d`.

Not installed or notarized. Actual Finder/Dock appearance switching and older-macOS runtime remain unverified; static ICNS alone does not provide dynamic Liquid Glass. Full build.sh was syntax-checked, not executed (to avoid its unrelated release/install-state effects); the updated local packaging path was built and signed successfully.
