import 'package:flutter/material.dart';
import 'package:hdict/core/database/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:hdict/features/home/widgets/app_drawer.dart';

class ScoreHistoryScreen extends StatefulWidget {
  const ScoreHistoryScreen({super.key});

  @override
  State<ScoreHistoryScreen> createState() => _ScoreHistoryScreenState();
}

class _ScoreHistoryScreenState extends State<ScoreHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _scores = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final scores = await _dbHelper.getFlashCardScores();
    setState(() {
      _scores = scores;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(title: const Text('Score History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scores.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              itemCount: _scores.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final session = _scores[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                  session['timestamp'],
                );
                final percentage = (session['score'] / session['total'] * 100)
                    .toInt();

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getScoreColor(percentage),
                    child: Text(
                      '${session['score']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    'Score: ${session['score']} / ${session['total']}',
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(date),
                  ),
                  trailing: Text(
                    '$percentage%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getScoreColor(percentage),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No scores recorded yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
