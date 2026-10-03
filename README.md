# Math-o-mir improved

A modified version of Math-o-mir with interaction repairs and automated Windows builds.

## Credit to the original author

**Math-o-mir was originally created by Danijel Gorupec.** The application, original C++ code, mathematical editor, and original design are his work. Thank you, Danijel, for creating Math-o-mir and making its source available.

Original project: [mathomir/Mathomir_GIT](https://github.com/mathomir/Mathomir_GIT).

This repository contains modifications to his application; it does not claim authorship of the original software or imply his endorsement of these changes. The original copyright notice and MIT license are retained in the source and Windows download packages.

## Repair status

Windows builds are produced through GitHub Actions. v11 includes a permanent feature search, move/resize/rotate grips, larger font choices and smart fitting, RAD/DEG controls, expanded function reference cards, US Letter defaults, and interaction/printing repairs.

The Windows runner verifies startup, search filtering, angle-mode controls, and the About box. Annotation insertion, dragging, caret behavior and printer dialogs still need hands-on verification. The reported annotated-root crash has not been reproduced; this build includes a defensive change to hover-reference traversal.

Download the latest successful **Mathomir-Windows-Repair** artifact under [Actions](https://github.com/towsiak/mathomir-improved/actions), extract the ZIP, and run `Mathomir.exe`.
