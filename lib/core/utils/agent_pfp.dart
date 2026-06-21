/// Maps an AI agent's name / handle / userId / roster key to its bundled PFP
/// asset. Returns null for humans (so callers keep their normal avatar).
///
/// Filenames intentionally match exactly what's in `assets/` (including the
/// original casing/spelling, e.g. `Vega-pfp.png`, `stricker-pfp.png`).
String? agentPfpAsset(String? idOrName) {
  if (idOrName == null || idOrName.isEmpty) return null;
  final s = idOrName.toLowerCase();
  // Pulse — the house trader. (Human "Puls Trader …" lacks the trailing 'e',
  // so it won't false-match.)
  if (s.contains('pulse') || s.contains('house_pulse')) return 'assets/puls-pfp.png';
  if (s.contains('sage')) return 'assets/sage-pfp.png';
  if (s.contains('vega')) return 'assets/Vega-pfp.png';
  if (s.contains('cygnus')) return 'assets/Cygnus-pfp.png';
  if (s.contains('orion')) return 'assets/orion-pfp.png';
  if (s.contains('atlas')) return 'assets/atlas-pfp.png';
  if (s.contains('nova')) return 'assets/nova-pfp.png';
  if (s.contains('striker') || s.contains('stricker')) return 'assets/stricker-pfp.png';
  return null;
}

/// True when [idOrName] resolves to one of our named house/swarm agents.
bool isNamedAgent(String? idOrName) => agentPfpAsset(idOrName) != null;

/// Display name (with emoji) for a known agent id/handle, else null. Used by
/// surfaces that only have a userId (market activity/holders, signals).
String? agentDisplayName(String? idOrName) {
  if (idOrName == null || idOrName.isEmpty) return null;
  final s = idOrName.toLowerCase();
  if (s.contains('vega')) return 'Vega ⚡';
  if (s.contains('cygnus')) return 'Cygnus 🛡️';
  if (s.contains('orion')) return 'Orion 🔭';
  if (s.contains('atlas')) return 'Atlas 📈';
  if (s.contains('nova')) return 'Nova 🌐';
  if (s.contains('striker') || s.contains('stricker')) return 'Striker ⚽';
  if (s.contains('sage')) return 'Sage 🔮';
  if (s.contains('pulse') || s.contains('house_pulse')) return 'Pulse 🤖';
  return null;
}
