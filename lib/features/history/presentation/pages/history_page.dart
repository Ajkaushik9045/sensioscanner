import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/history_item.dart';
import '../../domain/usecases/clear_history_use_case.dart';
import '../../domain/usecases/get_history_use_case.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _getHistory = sl<GetHistoryUseCase>();
  final _clearHistoryUseCase = sl<ClearHistoryUseCase>();
  List<HistoryItem>? _history;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _getHistory();
    if (mounted) {
      setState(() {
        _history = history;
      });
    }
  }

  Future<void> _clearHistory() async {
    await _clearHistoryUseCase();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection History'),
            Text(
              'Past devices you have connected to',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          if (_history != null && _history!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear History',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear History?'),
                    content: const Text('This will remove all past connected devices. Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearHistory();
                        },
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_history == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text('No connection history yet.', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: _history!.length,
      itemBuilder: (context, index) {
        final item = _history![index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF16324F),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF26C6DA).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bluetooth_connected_rounded, color: Color(0xFF26C6DA)),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  item.id,
                  style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(item.timestamp),
                      style: const TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    
    final timeStr = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'Today at $timeStr';
    }
    
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day) {
      return 'Yesterday at $timeStr';
    }
    
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} at $timeStr';
  }
}
