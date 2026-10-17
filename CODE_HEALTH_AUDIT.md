# Math-o-mir code audit — 17 October 2026

Baseline: `18c0710b8d4b56287958f519f6607cda0058afdb`, branch `fix/resize-equality-freeze`.

The code has real defects beyond cosmetic duplication. The highest priorities are document I/O and the interaction state model. Passing the existing UI suite did not cover several failure paths.

## Confirmed defects repaired in this change

| Priority | Finding and trigger | Evidence | Repair |
| --- | --- | --- | --- |
| P1 | Choosing Save on close could close the document after a failed save or canceled Save As. Deleting all objects bypassed the prompt entirely. | Extracted the actual `SaveModified` body and injected save failure/cancellation. Three pre-fix checks failed. | Close proceeds only after a successful save or explicit discard. Empty modified documents retain the prompt. |
| P1 | Save As renamed the document and cleared its modified flag even if `SaveMOMFile` failed; `OnSaveDocument` always returned success. | Direct control-flow inspection in `MathomirDoc.cpp`; callback failure reproduced with the actual extracted body. | Propagate the save result and guard Save As metadata changes. |
| P1 | A compressed token could write beyond the output allocation when the file understated its expanded length. Truncated repeat tokens also read beyond input. | AddressSanitizer caught a heap write overflow in the exact extracted decompression loop with a two-byte payload. | One bounded token decoder checks every expansion and repeat read; compressed header length, output length, allocation, and salt length are checked. |
| P1 | An XML attribute ending in a backslash read the byte after its terminating NUL. | AddressSanitizer caught a heap read overflow in the actual extracted `XML_read_attribute`. | Check lookahead in order; reject null input and zero output capacity. |
| P2 | Ten checked-in C++ checks were not invoked by the workflow or its scripts. The derivative test also included a nonexistent sibling checkout. | Workflow/script reachability inventory and failed standalone derivative compilation. | Compile/run every checked-in C++ test through one runner; fix the derivative include. |
| P2 | The 29-patch assembly sequence was copied into three build blocks. | Exact comparison of the Release, memory, and resize workflow sequences. They matched at the baseline, but required three coordinated edits. | One ordered manifest and one preparation script now serve all three builds, rejecting duplicate manifest entries. |

The missing C++ checks were canvas grid, number display, piecewise math, polygons, font resizing, scalar functions, smart shading, statistics, step endpoints, and symbolic derivatives. Their previous absence does not mean their features were entirely untested: some had separate native UI coverage.

## Significant weaknesses still open

| Priority | Finding | Consequence and next repair |
| --- | --- | --- |
| P1 | Ordinary saves open the destination with `fopen(filename,"w+b")` before writing. Recovery snapshots use a safer replacement flow, but ordinary saves do not. | A failed write or power loss can damage the previous file. Write a complete sibling temporary file, flush it, then replace the destination. The modified-flag repairs above do not make ordinary saves atomic. |
| P1 | `OpenMOMFile` clears the live document before reading, decoding, and validating the replacement. The parser also accepts some partial imports through a common end label. | An invalid replacement file can discard the current in-memory document. Parse into a temporary document and swap only after complete validation. The bounded decoder does not make the whole loader transactional. |
| P1 | Normal serialization catches per-object exceptions and continues; only recovery saving aborts those branches. | A normal save can report success after skipping or partially serializing an object. Treat any serialization failure as a failed save and retain the old destination. This is a source-confirmed path; no native fault injection was performed for an actual object exception. |
| P2 | Document opening uses `r+b` although it only needs to read; the open-error text concatenates a filename into a fixed 280-byte buffer. | Read-only files can fail to open; a sufficiently long path/error combination can overrun the message buffer. Use read-only opening and a length-safe string. Other legacy file/parser paths still need systematic malformed-input testing. |
| P2 | `AddDocumentObject` assigns `realloc` directly to `TheDocument` and reconstructs pointers before checking failure. Similar patterns occur elsewhere. | Allocation failure can lose the original allocation and document references. Allocate to a temporary pointer, check it, and only then commit storage and reference changes. Not reproduced under forced allocation failure here. |
| P2 | Hover, click, right-click, double-click, drag, and insertion still have separate targeting/commit paths. Formula insertion logic is duplicated in three active handlers. Many commands hand-reset clipboard and mouse globals. | Fixes can disagree between gestures. Introduce one resolved target and one explicit interaction transition API, then migrate handlers under regression coverage. Containment improvements are incremental; the whole selection engine has not been redesigned. |
| P2 | Hit testing repeatedly scans document objects and expression trees; center-grip placement can try 49 candidate positions while checking other objects. | Dense documents can make pointer movement expensive. Measure large documents, cache geometry by document revision, and use a spatial index. This is a structural cost finding, not a measured latency claim. |
| P2 | Graph workers retain access to live drawing/document structures, while UI code can replace or reallocate them. Destruction waits for a worker, sometimes without a timeout. | Ownership and cancellation remain complex, with possible responsiveness and race risks. Prefer immutable worker inputs and UI-thread result publication. This audit did not reproduce a new graph-worker race. |
| P3 | Several UI suites import helper source by slicing and evaluating a large smoke-test script. | Test setup depends on source text markers and aliases. Move common Win32 helpers into an explicit shared module. Existing successful UI checks remain useful but are not proof that every gesture path is equivalent. |

## Table-dialog improvement requested during the audit

The new Windows preview test also exposed an existing native formatting defect: setting the next row erased the header separator. Shared borders are now computed by boundary index on both adjacent cells, repairing preview and placement together.

The table dialog now has a live layout preview. Row count, column count, font, borders, and alignment update it. Preview and placement use one native table constructor. Optional sample text makes alignment visible and is never inserted into the document. The preview scales to fit; text content determines the eventual native cell widths. Invalid settings disable placement, and Cancel must preserve the document.

## Verification and limits

- Eighteen existing platform-independent C++ checks passed locally with AddressSanitizer and UndefinedBehaviorSanitizer after repairing the derivative include. The native Windows presentation test requires Windows.
- The new decoder check covers legacy tokens, exact output capacities, truncated repeats, and 25,000 deterministic malformed payloads.
- The source-extraction regression checks save/close outcomes and 59 truncated XML prefixes at two output capacities. These run actual extracted function bodies with controlled dependencies, not a full MFC process.
- A fresh replay of the ordered patches was compared byte for byte with the assembled source. Windows compilation and UI validation are recorded by the associated Actions run.
- Linux LeakSanitizer cannot inspect processes in this environment, so leak detection was disabled locally. Address/undefined-behavior checks remained enabled. Windows AddressSanitizer coverage is separate.
- This is a targeted static/dynamic audit, not an exhaustive proof of correctness. In particular, atomic saves, transactional loading, all allocation-failure paths, and a unified interaction engine remain open.

Recommended order: atomic save plus serialization failure handling; transactional loader; shared interaction targeting/state; worker ownership; performance measurements. Avoid a wholesale refactor without retaining the current native regression coverage.
