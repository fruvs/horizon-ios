# Native launcher design

The SwiftUI launcher uses a system sidebar on iPad and system tabs on iPhone. Play contains a landscape cover, recent-world previews and two shortcuts. Account controls live in one toolbar sheet; signed-in Minecraft names are read-only, while offline names remain editable.

Use semantic UIKit colors and system type so light/dark appearance and Dynamic Type follow the device. Keep Liquid Glass on navigation and controls, using SwiftUI's native glass button styles on iOS 26 and later; older supported systems use bordered buttons and system materials. Content lists retain solid grouped surfaces for legibility. There are no purple theme tokens or bundled custom fonts.

Scenery comes from the player's imported title panorama or their world's thumbnail. Neither game assets nor screenshots are bundled with the launcher. Before imports are available, a simple original landscape fallback keeps the layout usable. Avoid restoring the old promotional splash animation, duplicated account panels or device-status chips on Play.

The launcher branch starts from the device-tested build 16 source, before upstream removed the launcher. Native world creation now sends typed JSON through `world-create`, preserving names/seeds with spaces and mapping mode, difficulty, cheats, world type, structures and bonus chest to the existing `WorldOptions`. Hardcore locks Hard difficulty and disables cheats/bonus chest at both UI and engine boundaries. The separate direct-title experiment remains intact. No PR or push is part of this design iteration.

The official `docs/media/brand/mark-dark.svg` is included unchanged as a template image, displayed monochrome. Worlds supports a thumbnail grid or list, search, sorting, and explicit Play/Rename/Back Up/Delete menus. Server descriptions consume legacy Minecraft color/style/RGB codes, with readable accessibility text and semantic reset styling. Unknown section-sign sequences remain literal text.
