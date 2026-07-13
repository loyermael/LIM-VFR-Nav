import '../core/notam_filter.dart';
import '../core/notam_parser.dart';
import '../models/notam.dart';
import 'notam_source.dart';
import 'storage_service.dart';

/// Orchestrates the NOTAM lifecycle: fetch raw text from a [NotamSource] (on the
/// ground), parse the Q-lines, keep only VFR-relevant ones, and persist them so
/// they're available offline in flight.
class NotamRepository {
  NotamRepository(this._storage);
  final StorageService _storage;

  Future<List<Notam>> loadStored() => _storage.loadNotams();
  DateTime? get syncedAt => _storage.notamSyncedAt;

  /// Sync from a source and replace the stored set. Returns the kept NOTAMs.
  Future<List<Notam>> sync(NotamSource source) async {
    final raw = await source.fetchRaw();
    return importRaw(raw);
  }

  /// Parse a raw NOTAM blob (e.g. pasted from the SIA), filter to VFR, store.
  Future<List<Notam>> importRaw(String raw) async {
    final parsed = NotamParser.parseMany(raw);
    final kept = NotamFilter.vfrOnly(parsed);
    await _storage.saveNotams(kept);
    _storage.notamSyncedAt = DateTime.now();
    return kept;
  }

  Future<void> clear() async {
    await _storage.saveNotams([]);
    _storage.notamSyncedAt = null;
  }
}
