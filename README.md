# cheng-pebble

Pebble-style KV core implemented in Cheng.

## Current State

The core persistence loop is implemented:
- Write path: `Batch Commit -> WAL append -> MemTable apply`.
- Flush path: `MemTable -> SSTable file -> Manifest VersionEdit`.
- Recovery path: `Manifest load -> SSTable reload -> WAL segment replay (tail tolerant configurable)`.
- Read path: snapshot reads merge `MemTable + persisted SSTable history` by sequence number.
- Maintenance path: automatic compaction and old SSTable cleanup after flush.
- Close path: syncs WAL and flushes remaining memtable data when persistent storage is configured.

## Key Modules

- `src/batch/db.cheng`: DB lifecycle, commit/flush/recovery orchestration.
- `src/batch/batch.cheng`: batch operations and WAL payload encode/decode.
- `src/wal/writer.cheng`, `src/wal/reader.cheng`: WAL append/read/sync/reset.
- `src/sstable/table_builder.cheng`, `src/sstable/table_reader.cheng`: SSTable build/read.
- `src/manifest/version_set.cheng`, `src/manifest/store.cheng`: manifest persistence and replay.
- `src/qa/production_closure.cheng`: end-to-end durability/restart scenario checks.

## Persistence Config

`DBConfig` supports persistence controls:
- `walPath`
- `walMaxSegmentBytes`
- `manifestPath`
- `sstableDir`
- `autoFlush`
- `flushLevel`
- `tableBlockSize`
- `tableBloomBitsPerKey`
- `createIfMissing`
- `enableRecovery`
- `replayTailTolerance`
- `resetWalOnFlush`

If persistence paths are provided, startup will recover from manifest + WAL and reads include persisted SSTables.

## QA Entry

Use `RunProductionClosureScenario(rootDir)` from `src/qa.cheng` to run a durability smoke scenario covering restart recovery and delete semantics.
Tooling command: `qa-production [--dir=<path>]`.

## Production Closure

One-command compile + run closure:

```bash
CHENG_LANG_ROOT=/absolute/path/to/cheng-lang \
sh scripts/production_closure.sh --dir=/tmp/pebble_qa_prod
```

Prerequisites:
- `CHENG_LANG_ROOT` contains a runnable backend driver chain (script will auto-probe/rebuild `cheng` when possible).
- The selected backend driver must support current `cheng-pebble` source set in `stage1` compile mode.

The script performs:
- backend driver bootstrap/rebuild (if `CHENG_LANG_ROOT/cheng` is missing or not runnable),
- compile of `src/tooling/qa_production_main.cheng`,
- execution of durability/restart checks with non-zero exit on failure.
- on compile failure, prints the compiler diagnostic tail to help close remaining backend gaps.
