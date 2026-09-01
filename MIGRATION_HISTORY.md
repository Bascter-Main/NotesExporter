# NotesExporter migration history

This repository was extracted from the temporary development branch `Bascter-Main/daily-update:notes-exporter-ios17-build` after device testing on iOS 17.0.

The standalone repository keeps a clean source-oriented history. GitHub Actions bot commits that only published generated dylib files were intentionally not replayed. Because the source was extracted into a new Git repository rather than mirroring the unrelated `daily-update` history, the new commit SHAs differ from the originals.

## Original source-development commits

- `a1a1094e596af37653d20951c5b6c7d1ec7efdc4` — Add NotesExporter TrollFools build config
- `d69763226fda444faa1373f86ae134b05b4770af` — Add NotesExporter package metadata
- `c88cb43aff0440cd3c80ad6e2e94dcda86dbc317` — Add iOS 17 Notes batch export implementation
- `6c9f3c1ca96dbf7cf11d31040e89a415127b7349` — Add GitHub Actions iOS dylib compiler
- `409fefbabe07772a56d802970ecd6e7e733261f9` — Enable PR build for NotesExporter
- `e263387219f532975c541d26c7ae2134039a0a4d` — Trigger PR build for iOS 17 exporter
- `8e9dde2e0b986a6e1ff046f575f006801cdf0f03` — Fix deprecated UIApplication.windows build error
- `87051d6aa0ddfe7385a0c771ed4f44cda23dd141` — Publish verified dylib directly to branch instead of Actions artifacts
- `8d6e37a0c6a019f8300abb71b68d1584d1a124d9` — Fix workflow to validate merged universal dylib
- `3a665be3731210a12087c3ec0246e81d3d75d6cd` — Fix iOS 17 selection detection and add batch/context-menu export UI
- `24bc75e1c3859532c125d18353470851de2976a3` — Fix build: remove unused NotesOnly helper
- `8183f8f710779c474d9697eeee76d57bb4602a1b` — Improve iOS 17 note resolution using recursive wrappers and cell title fallback
- `9034be47b1013970716328f8ec0328c2b083cf6a` — Stabilize multi-select diagnostics and remove unsafe private-object traversal
- `4a3b4a4c61e694ef172dffd1948634990dbb506e` — Fix diagnostic button visibility by scanning only current top view
- `6ab0e6f8a757d7be1c98692713c96969ec9818f9` — Implement stable Core Data note export from selected NSManagedObjectIDs
- `ee1ab0cde7de4a14e5a60efa8f97e560ab7303b0` — Link CoreData for NSManagedObjectID based Notes export
- `05e8580fd2cb06cbf644d07e7517a4b50909143f` — Read real ICNote text and remove crashing context-menu hook
- `5bf56e697efb3474ddaf546d83bf740104a9249c` — Add safe per-list long-press export via collection view delegate hook
- `4e9ad106eccd9d680c264ae21849367938466175` — Fix iOS 17 SDK compile by reading context-menu providers via runtime selectors
- `777c0674a06fad58561fd7cdf951bc7ff28f1f34` — Hide export actions inside note editor view
- `e4e97941476afdd9217e35cbf8ee2a1ede7a1f3d` — Prevent transient batch export flash during note navigation

## Generated build commits omitted from replay

The temporary branch also contained `github-actions[bot]` commits with message `build: publish verified NotesExporter dylib [skip ci]`. They only contained generated `build-output/NotesExporter.dylib` and its SHA-256 file, so they are not part of the standalone source history. The standalone workflow rebuilds these artifacts on `main`.
