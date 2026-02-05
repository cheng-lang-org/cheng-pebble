# cheng-pebble

Cheng rewrite of `nim-pebble` with a minimal, production-focused core. This directory is the new home
for the Cheng implementation; `nim-pebble` remains untouched for reference.

## Status
Ported (Cheng):
- `pebble/core/types.cheng`
- `pebble/runtime/executor.cheng`
- `pebble/runtime/resource_manager.cheng`
- `pebble/mem/types.cheng`
- `pebble/mem/memtable.cheng`
- `pebble/batch/interop.cheng`
- `pebble/batch/types.cheng`
- `pebble/batch/batch.cheng`
- `pebble/batch/db.cheng`
- `pebble/wal/types.cheng`
- `pebble/wal/checksum.cheng`
- `pebble/wal/reader.cheng`
- `pebble/wal/writer.cheng`
- `pebble/wal/recycler.cheng`
- `pebble/vfs/types.cheng`
- `pebble/vfs/faults.cheng`
- `pebble/vfs/posix_fs.cheng`
- `pebble/vfs/buffered_fs.cheng`
- `pebble/vfs/cache_fs.cheng`
- `pebble/vfs/mount_fs.cheng`
- `pebble/vfs/prefetch_rate.cheng`
- `pebble/vfs/compat_report.cheng`
- `pebble/vfs.cheng`
- `pebble/sstable/types.cheng`
- `pebble/sstable/encoding.cheng`
- `pebble/sstable/block.cheng`
- `pebble/sstable/filter.cheng`
- `pebble/sstable/cache.cheng`
- `pebble/sstable/table_builder.cheng`
- `pebble/sstable/table_reader.cheng`
- `pebble/manifest/types.cheng`
- `pebble/manifest/version_edit.cheng`
- `pebble/manifest/version.cheng`
- `pebble/manifest/store.cheng`
- `pebble/manifest/version_set.cheng`
- `pebble/manifest/tools.cheng`
- `pebble/core/module_map.cheng`
- `pebble/config/container.cheng`
- `pebble/config/loader.cheng`
- `pebble/config.cheng`
- `pebble/obs/types.cheng`
- `pebble/obs/metrics.cheng`
- `pebble/obs/events.cheng`
- `pebble/obs/ops.cheng`
- `pebble/obs/profiling.cheng`
- `pebble/obs/manager.cheng`
- `pebble/obs.cheng`
- `pebble/read/types.cheng`
- `pebble/read/iterators.cheng`
- `pebble/read/sources.cheng`
- `pebble/read/trace.cheng`
- `pebble/read.cheng`
- `pebble/compaction/types.cheng`
- `pebble/compaction/planner.cheng`
- `pebble/compaction/scheduler.cheng`
- `pebble/compaction/executor.cheng`
- `pebble/compaction.cheng`
- `pebble/qa/dsl.cheng`
- `pebble/qa/differ.cheng`
- `pebble/qa/metamorphic.cheng`
- `pebble/qa.cheng`
- `pebble/tooling/cli_core.cheng`
- `pebble/tooling/core_commands.cheng`
- `pebble/tooling/sstable_commands.cheng`
- `pebble/tooling.cheng`

Tooling modules (Cheng):
- `pebble/tooling/cli_core.cheng`
- `pebble/tooling/core_commands.cheng`
- `pebble/tooling/sstable_commands.cheng`

Gaps to port (Cheng):
- None (remaining work focuses on integration, tests, and ext/interop if required).

## Notes
- Current import paths reference the local Cheng bootstrap modules. Keep them consistent with your
  compiler include path.
- The executor is synchronous for now. WAL trim now truncates and fsyncs the active segment tail.
- Keys/values currently use `str`, which is not NUL-safe.
- Prefetch dispatch is synchronous for now; rate limiter now applies blocking token-bucket admission.

## Next steps
- Add read-path regression and load tests.
- Extend tooling commands and wire a Cheng CLI entrypoint.
