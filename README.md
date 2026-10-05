# Math-o-mir improved

A modified version of Math-o-mir with interaction repairs and automated Windows builds.

## Credit to the original author

**Math-o-mir was originally created by Danijel Gorupec.** The application, original C++ code, mathematical editor, and original design are his work. Thank you, Danijel, for creating Math-o-mir and making its source available.

Original project: [mathomir/Mathomir_GIT](https://github.com/mathomir/Mathomir_GIT).

This repository contains modifications to his application; it does not claim authorship of the original software or imply his endorsement of these changes. The original copyright notice and MIT license are retained in the source and Windows download packages.

## Repair status

Windows builds are produced through GitHub Actions. v20 includes a permanent feature search, move/resize/rotate grips, larger font choices and smart fitting, RAD/DEG controls, π fraction labels for graph axes, expanded function reference cards, US Letter defaults, and interaction/printing repairs.

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

Default math shortcuts (v20): type the name and press Space in math mode. inf/infty, pi, frac, sqrt/root, lim, int/iint/iiint/oint, sum/prod, vec/vec2/vec3, mat/mat3, eq/neq/leq/geq/approx, pm/mp/times/cdot/div/to, cup/cap/subset/subseteq/in/notin/forall/exists, nabla/partial/binom/case, alpha/beta/gamma/delta/theta/lambda/mu/sigma/omega, sin/cos/tan/sec/csc/ln/log. vec is a three-cell column vector; mat is 2x2. Text mode and longer names do not expand. Existing custom easycasts remain available.

V17 page width: starts fitted to the available window width. The visible Fit width button beside Search (also View > Fit page width) removes gray side strips and follows window resizing. Manual zoom or horizontal scrolling exits fit mode; click Fit width to restore it. US Letter printing dimensions are unchanged.

Search focus repair: choosing a result returns keyboard focus to the document. The dropdown reopens through an explicit Search click, typing, arrow keys, or Ctrl+K, rather than a Windows focus-restoration notification. Result clicks dispatch after the mouse event finishes, and view commands run directly even when a toolbar held focus. Windows checks cover mouse selection, pointer movement, and opening/closing a searched dialog.

V18: Fit width rounds down to keep both paper edges visible and disables horizontal scrollbar travel while fitting. Manual zoom restores scrolling. Graphs inspect original divisors and negative-power bases for excluded points, numerically check two-sided finite limits, and paint holes with open circles. Pole crossings break the curve. Real odd-denominator rational powers retain their negative-x branch; plotted domain endpoints are refined, the last sample is drawn, and fitting preserves ordinary extrema and updates after editing a function. Detection is numerical within the visible x window, not a symbolic proof for every possible expression.

Print guide: a faint dashed quarter-inch safety inset on every page, enlarged to printer hardware margins measured from a print/preview DC when available. A warning pulses for three seconds when page content crosses the inset and clears when safe. The guide and warning never print.
Unit circle maker: drawing palette circle icon or Search 'unit circle'; configure start/end angles in degrees or radians (pi/6 etc.), arc direction, radius, angle labels, exact endpoint coordinates, common angle ticks, and an end-angle right triangle. Click OK then click to place; native grips move, scale and rotate the grouped drawing.

Unit-circle points: filled start/end markers are enabled by default; common angles can also be marked. Enter optional extra point angles separated by commas (up to 32) in degrees or radians; angle and coordinate labels follow the existing switches. Extra points are marked even when automatic endpoint markers are off.
Vertical lines: enter x=3, x=-2, x=0, or x=1/2 in any colored graph slot. Constant expressions are evaluated with the usual math engine, and the line spans the visible height alongside ordinary functions. Saving, zooming and printing retain the equation. Variable-dependent x= equations are not supported.

Graph header layout: a reserved top row for zoom/Fit/analysis/axis-label controls; colored function expressions wrap in rows beneath it. The right-hand function button column stays clear.

## Geometry palette

Open **Geometry** on the menu bar, or the dedicated triangle-icon toolbox palette, to place a triangle, right triangle, square, rectangle, parallelogram, trapezoid, circle, or ellipse. Four more entries provide parallel lines and Z (alternate), F (corresponding), and U (co-interior) angle diagrams, with parallel marks, angle arcs, and thicker pattern strokes. Click in the document to place; move, resize, or rotate with the normal drawing grips. Search **Geometry** finds the same presets.

## Piecewise function grapher

Open **Graph > Piecewise function grapher** or search **piecewise**. The editor has eight formula rows, lower/upper bounds and independent endpoint inclusion checkboxes. Leave unused formulas blank. Blank bounds or `-inf`/`inf` give unbounded intervals; fractions and `pi` expressions work in bounds. Equal finite bounds with both endpoints included create an isolated point. Intervals may have gaps, but overlaps—including two included ends at the same boundary—are rejected.

Formulas accept x, numbers, pi, e, arithmetic, powers, implicit multiplication (such as 2x), and sin, cos, tan, sqrt, abs, exp, ln and base-10 log. Functions require parentheses. The radians checkbox governs trig independently of the graph's axis-label mode. **Check definition** validates rows; **Evaluate f(x)** identifies the active branch or explains why a value is undefined. Jump, absolute-value and step examples are provided. Set all four graph-window bounds before placing.

The graph shows each formula and its interval in matching colors, clips branches to their intervals, and draws open/filled endpoint markers. A closed point is painted after open dots when they coincide. Natural domain restrictions and discontinuities remain in effect. Definitions survive save/reopen, copying and Undo. Select or point at an existing piecewise graph and reopen the editor to update it; its colored formula buttons also open the editor. The usual zoom, fit, move and resize controls apply.

The portable math checks can be run with `g++ -std=c++11 -I source/Mathomir tools/piecewise-math-check.cpp -o piecewise-check`, followed by `./piecewise-check`, after preparing the patched upstream source. Windows UI checks additionally verify interval clipping, endpoint dots and persistence.

The geometry palette also includes an **obtuse triangle**. The drawing palette and Geometry menu offer **Fine bold hatch downward/upward** brushes. They use 40% of the original hatch spacing and approximately three times its line width; apply both directions for a crosshatch with smaller openings. The original hatch tools remain available.

## Smart shader and typed backgrounds

**Smart hatch downward/upward** are separate brushes in the drawing palette and Geometry menu. They recognize closed polygon/circle outlines, nested contours and holes, clip each hatch stroke at boundaries, and leave a small inset to avoid edge overshoot. Outside closed outlines they can follow a standalone straight line: start beside the line on the side you want to shade; that side stays fixed for the stroke. Open lines shorter than 40 drawing units are ignored as guides. Graph containers and bitmap images are not outline sources. Original and fine/bold hatch brushes remain available.

Use the visible **Background** button, **Colors > Background colors**, or **Edit > Typed object background** to color the background of typed math or text objects. Eight light colors, a custom color chooser, and clear/transparent are available. Apply while editing, to the last touched typed object, or to selected typed objects. The background is part of the editable expression and survives copying, save/reopen, and Undo.
