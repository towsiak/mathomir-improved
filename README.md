# Math-o-mir improved

A modified version of Math-o-mir with interaction repairs and automated Windows builds.

## Credit to the original author

**Math-o-mir was originally created by Danijel Gorupec.** The application, original C++ code, mathematical editor, and original design are his work. Thank you, Danijel, for creating Math-o-mir and making its source available.

Original project: [mathomir/Mathomir_GIT](https://github.com/mathomir/Mathomir_GIT).

This repository contains modifications to his application; it does not claim authorship of the original software or imply his endorsement of these changes. The original copyright notice and MIT license are retained in the source and Windows download packages.

## Repair status

Windows builds are produced through GitHub Actions. v13 includes a permanent feature search, move/resize/rotate grips, larger font choices and smart fitting, RAD/DEG controls, π fraction labels for graph axes, expanded function reference cards, US Letter defaults, and interaction/printing repairs.

The Windows runner verifies startup, search filtering, angle-mode controls, the About box, grip movement with Undo, and typing then finishing an annotation above a root. v13 fixes cumulative resize growth and anchors the grip to the object corner. Resize feel, caret behavior and printer dialogs still need hands-on verification. The reported annotated-root crash has not been reproduced; this build includes a defensive change to hover-reference traversal.

Writing has eight colors, including orange, purple and teal, through the **Colors** button or Search. For highlighted text, **R/G/B** select red/green/blue; **Ctrl+B** toggles bold separately. Graphs now have eight colored function slots. Search **Smart fit** to fit the vertical range, or **Reset view** to recover a useful starting window. Zoom changes are gradual and bounded.

For graph labels, search **pi fractions** or **decimal labels**. π mode uses radians for that graph and saves the choice. Drag the four-arrow grip to move an object; use the lower-right grip to resize, holding Shift for finer control.

Download the latest successful **Mathomir-Windows-Repair** artifact under [Actions](https://github.com/towsiak/mathomir-improved/actions), extract the ZIP, and run `Mathomir.exe`.
