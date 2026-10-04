# Math-o-mir improved

A modified version of Math-o-mir with interaction repairs and automated Windows builds.

## Credit to the original author

**Math-o-mir was originally created by Danijel Gorupec.** The application, original C++ code, mathematical editor, and original design are his work. Thank you, Danijel, for creating Math-o-mir and making its source available.

Original project: [mathomir/Mathomir_GIT](https://github.com/mathomir/Mathomir_GIT).

This repository contains modifications to his application; it does not claim authorship of the original software or imply his endorsement of these changes. The original copyright notice and MIT license are retained in the source and Windows download packages.

## Repair status

Windows builds are produced through GitHub Actions. v18 includes a permanent feature search, move/resize/rotate grips, larger font choices and smart fitting, RAD/DEG controls, π fraction labels for graph axes, expanded function reference cards, US Letter defaults, and interaction/printing repairs.

The Windows runner verifies startup, search filtering, angle-mode controls, the About box, grip movement with Undo, and typing then finishing an annotation above a root. v13 fixes cumulative resize growth and anchors the grip to the object corner. Resize feel, caret behavior and printer dialogs still need hands-on verification. The reported annotated-root crash has not been reproduced; this build includes a defensive change to hover-reference traversal.

Writing has eight colors, including orange, purple and teal, through the **Colors** button or Search. For highlighted text, **R/G/B** select red/green/blue; **Ctrl+B** toggles bold separately. Graphs now have eight colored function slots. Search **Smart fit** to fit the vertical range, or **Reset view** to recover a useful starting window. Zoom changes are gradual and bounded.

For graph labels, search **pi fractions** or **decimal labels**. π mode uses radians for that graph and saves the choice. Drag the four-arrow grip to move an object; use the lower-right grip to resize, holding Shift for finer control.

Download the latest successful **Mathomir-Windows-Repair** artifact under [Actions](https://github.com/towsiak/mathomir-improved/actions), extract the ZIP, and run `Mathomir.exe`.

## Crash recovery

Recovery saves automatically about one second after edits stop, or every five seconds while editing continues. A running graph calculation or active drag must finish first. Each snapshot is an independent timestamped `.mom` file, and `Latest.mom` is replaced only after a complete, flushed snapshot is available. Earlier versions are retained.

To reopen work after a crash, launch the app and type **recover** in the visible Search box. Choose `Latest.mom` or an earlier timestamp. Files are stored in `%LOCALAPPDATA%\MathomirImproved\Recovery`; unwanted old versions can be deleted there. This recovery works independently of the legacy autosave-frequency setting. A few recent unsnapshotted edits can still be lost in a sudden crash.

## Braces, shapes and interval diagrams

Ordinary drawings—including braces, arrows, lines, shapes and groups of drawings—now use the round mouse rotation grip. Hover over the object or use **Rotate**, drag to turn, hold Shift for 15-degree steps, or press Escape to cancel. Nested text labels turn with the diagram. Live graphs, bitmap images and special drawing containers are not included in this geometry rotation.

Search **number line** or **interval** to choose `(a,b)`, `[a,b]`, `(a,b]`, or `[a,b)`, then click to place. The endpoints use hollow circles or filled dots, with editable a/b labels and a thicker interval segment. They can be moved, resized and rotated like other drawing objects.

## Tables and palette shortcuts

The brace/arrow drawing palette has five new icons: a configurable table and the four interval presets. The table dialog sets rows, columns, font size, cell alignment, and full-grid/outer/header/no borders before placement. Choose **Place table**, click in the document, and use the native editable cells for text or equations. Search **table** opens the same setup.

A second move grip sits immediately to the right and slightly below the resize corner. Both move grips take priority over object selection. Grips clear when the pointer leaves the object/grip area or the document view, while active drags retain their handles.

Default math shortcuts (v18): type the name and press Space in math mode. inf/infty, pi, frac, sqrt/root, lim, int/iint/iiint/oint, sum/prod, vec/vec2/vec3, mat/mat3, eq/neq/leq/geq/approx, pm/mp/times/cdot/div/to, cup/cap/subset/subseteq/in/notin/forall/exists, nabla/partial/binom/case, alpha/beta/gamma/delta/theta/lambda/mu/sigma/omega, sin/cos/tan/sec/csc/ln/log. vec is a three-cell column vector; mat is 2x2. Text mode and longer names do not expand. Existing custom easycasts remain available.

V17 page width: starts fitted to the available window width. The visible Fit width button beside Search (also View > Fit page width) removes gray side strips and follows window resizing. Manual zoom or horizontal scrolling exits fit mode; click Fit width to restore it. US Letter printing dimensions are unchanged.

Search focus repair: choosing a result returns keyboard focus to the document. The dropdown reopens through an explicit Search click, typing, arrow keys, or Ctrl+K, rather than a Windows focus-restoration notification. Result clicks dispatch after the mouse event finishes, and view commands run directly even when a toolbar held focus. Windows checks cover mouse selection, pointer movement, and opening/closing a searched dialog.

V18: Fit width rounds down to keep both paper edges visible and disables horizontal scrollbar travel while fitting. Manual zoom restores scrolling. Graphs inspect original divisors and negative-power bases for excluded points, numerically check two-sided finite limits, and paint holes with open circles. Pole crossings break the curve. Real odd-denominator rational powers retain their negative-x branch; plotted domain endpoints are refined, the last sample is drawn, and fitting preserves ordinary extrema and updates after editing a function. Detection is numerical within the visible x window, not a symbolic proof for every possible expression.
