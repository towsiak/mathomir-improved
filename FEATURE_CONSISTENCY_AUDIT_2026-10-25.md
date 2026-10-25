# Feature consistency and performance audit — 25 October 2026

Baseline: `a262b6af4a119525a8a3515a035df555801c4c46`, branch `fix/resize-equality-freeze`.

This pass follows the accumulated native feature integrations: basic/implicit/
parametric graphs, typed point lists, graph units, sliders and animation,
linked value tables, table plots, layers/connectors, step presentation,
placement previews, and presentation/alignment overlays. It addresses shared
state and repeated work. It does not claim that the whole legacy application
has been proved correct or that every interaction now uses one state machine.

## Findings repaired

| Finding | Result |
| --- | --- |
| Feature synchronization built separate document inventories, and each linked table could trigger another whole-document search and repeat the same graph checksum. | One fresh inventory is shared by teaching and interactive synchronization. An ID index resolves references within that pass, and each referenced graph is checksummed once per pass. Connector geometry still receives exact measurements when required. No object-pointer cache survives a frame or document transition. |
| An open slider panel used a 16 ms timer even while idle; animation rewrote range/step controls that had not changed. | Idle polling is 125 ms. Playback and thumb dragging retain 16 ms updates. Animation updates values and positions; full range/step refreshes remain for actual settings changes. The panel reuses the graph lookup already needed for synchronization. |
| Inline axis edits, graph-tool fields, and table-plot options could apply stale copies of names/units over newer edits made elsewhere. | All use the same axis validation and fieldwise merge. A field unchanged since the editor's baseline preserves the current graph value. An explicitly edited or cleared field is applied. The graph-tool fields refresh without discarding pending edits. |
| Typed point lists were parsed separately for the canvas legend and graph worker, including on repeated repaints with unchanged input. | Each graph slot shares an immutable result keyed by its complete source text. Changed and invalid inputs replace the entry; prior worker/UI snapshots retain valid ownership. No document pointers enter this cache. |
| The inline unit editor repeated unchanged child-window layout and registered a window class with an instance-owned brush. Its parent did not explicitly clip child controls during repaint. | Child controls are laid out only after a geometry change. A shared stock class brush has a valid lifetime; instance painting supplies the background. The canvas clips its children. Lifetime/identity checks continue. |
| Alignment-guide and Spotlight pens left scope before being deselected from the drawing context. A later DC restore occurred after their attempted destruction. | Each pen is restored before its local owner is destroyed. Native validation checks graphics-handle growth during repeated Spotlight redraws. |
| Updating a table plot whose target had been deleted fell through to the new-graph constructor. | A missing update target reports its removal and preserves the page. Creating a new graph remains an explicit new-plot action. |
| Graph editing controls could appear in prepared-object previews. | Native graph controls and the inline units button share hover visibility. Inactive graphs, carried previews, printing and read-only views exclude editing controls. Strict preview/placement pixel comparison remains enabled. |

## Evidence and verification

- `feature-consistency-check.cpp` checks stale axis forms, independent edits,
  clearing and conflicting changes, shared limits, idle/active cadence, cache
  invalidation, invalid input, and concurrent immutable point snapshots.
- A local parsing microbenchmark with 100 constant-expression points and 1,000
  reads measured about 83 ms for repeated parsing versus 0.08 ms for cache
  lookup in one optimized Linux run. This is a parser measurement, not an
  end-to-end graph or UI speed claim. The test does not assert wall-clock speed.
- `feature-audit-smoke.ps1` uses 12 native linked tables on one graph. Diagnostic
  work counts check one shared document walk and at most one graph checksum per
  synchronization pass. Native controls exercise simultaneous edits in both
  axis editors, table-option updates, deleted-target behavior, unchanged
  window layout, slider cadence, and graphics resources over 120 redraws.
- The normal basic-grapher, teaching, slider/animation, connector, step-reveal,
  preview, editing, printing, and native memory suites remain required.
- All source overlays are replayed from the pinned upstream source and compared
  with the assembled native files before publishing a build.

Final native results are recorded in the associated Windows workflow and
release notes. Benchmarks and diagnostic output are not production UI features.

## Remaining structural weaknesses

The confirmed legacy save/load and allocation weaknesses recorded in
`CODE_HEALTH_AUDIT.md` remain separate work: ordinary-save atomic replacement,
transactional loading, serialization-failure propagation, and some allocation
failure paths. This feature audit does not repair those I/O paths. Native graph
workers still use parts of the live drawing model, and the legacy global input
state has not been replaced with a single interaction state machine. The
per-pass inventory and immutable point results deliberately avoid introducing
long-lived caches of document pointers into that design.
