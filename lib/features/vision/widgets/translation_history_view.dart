import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/translation_log.dart';

/// Halaman riwayat terjemahan (Hive offline persistence)
class TranslationHistoryView extends StatefulWidget {
  const TranslationHistoryView({super.key});

  @override
  State<TranslationHistoryView> createState() => _TranslationHistoryViewState();
}

class _TranslationHistoryViewState extends State<TranslationHistoryView> {
  late Box<TranslationLog> _box;
  List<TranslationLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    try {
      _box = Hive.box<TranslationLog>('translation_logs');
      _logs = _box.values.toList().reversed.toList();
    } catch (_) {
      _logs = [];
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131315),
      appBar: AppBar(
        title: const Text(
          "Riwayat Terjemahan",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1F1F21),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Color(0xFFEF5350)),
              onPressed: () => _confirmClear(),
            ),
        ],
      ),
      body: _logs.isEmpty ? _buildEmptyState() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _buildLogCard(_logs[index]),
    );
  }

  Widget _buildLogCard(TranslationLog log) {
    final timeStr = DateFormat('dd MMM yyyy, HH:mm:ss', 'id_ID').format(log.timestamp);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F21),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1A06B6D4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                log.text,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF06B6D4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Terdeteksi: \"${log.text}\"",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$timeStr · Model: ${log.modelType}",
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white12),
          SizedBox(height: 12),
          Text(
            "Belum ada riwayat terjemahan",
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1F21),
        title: const Text(
          "Hapus Semua Riwayat?",
          style: TextStyle(color: Colors.white, fontFamily: 'Inter'),
        ),
        content: const Text(
          "Semua data riwayat terjemahan akan dihapus permanen.",
          style: TextStyle(color: Colors.white54, fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _box.clear();
              Navigator.pop(ctx);
              _loadLogs();
            },
            child: const Text("Hapus", style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
  }
}
