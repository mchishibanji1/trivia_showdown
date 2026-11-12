import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TriviaShowdownApp());
}

class TriviaShowdownApp extends StatelessWidget {
  const TriviaShowdownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API-to-Cloud Trivia Showdown',
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const TriviaShowdownScreen(),
    );
  }
}

class TriviaException implements Exception {
  final String message;
  TriviaException(this.message);

  @override
  String toString() => message;
}

class Question {
  final String questionText;
  final String correctAnswer;
  final List<String> options;

  Question({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final incorrect = List<String>.from(json['incorrect_answers'] as List);
    final correct = json['correct_answer'] as String;
    final allOptions = [...incorrect, correct]..shuffle();

    return Question(
      questionText: _clean(json['question'] as String),
      correctAnswer: _clean(correct),
      options: allOptions.map(_clean).toList(),
    );
  }

  static String _clean(String value) {
    var text = value;
    const replacements = {
      '&quot;': '"',
      '&#039;': "'",
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
      '&amp;': '&',
    };

    replacements.forEach((encoded, decoded) {
      text = text.replaceAll(encoded, decoded);
    });

    return text;
  }
}

class TriviaService {
  static const String endpoint =
      'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple';

  Future<List<Question>> fetchQuestions() async {
    final response = await http
        .get(Uri.parse(endpoint))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw TriviaException('Server error: ${response.statusCode}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw TriviaException('Unexpected response format from trivia API.');
    }

    final responseCode = decoded['response_code'];
    if (responseCode != 0) {
      throw TriviaException(
        'Trivia API returned response code $responseCode. Please try again.',
      );
    }

    final results = decoded['results'];
    if (results is! List || results.isEmpty) {
      throw TriviaException(
        'No trivia questions were returned. Please try again.',
      );
    }

    return results
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

class TriviaShowdownScreen extends StatefulWidget {
  const TriviaShowdownScreen({super.key});

  @override
  State<TriviaShowdownScreen> createState() => _TriviaShowdownScreenState();
}

class _TriviaShowdownScreenState extends State<TriviaShowdownScreen> {
  final TriviaService _triviaService = TriviaService();

  // Replace with your instructor-provided endpoint if one is supplied.
  // Leave null to use the clearly labeled classroom simulation.
  static const String? _leaderboardEndpoint = null;

  List<Question> _questions = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _selectedOption;
  bool _isSynced = false;
  bool _isSyncing = false;
  int _roundId = 0;

  bool get _hasRealEndpoint =>
      _leaderboardEndpoint != null && _leaderboardEndpoint!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    final roundId = _roundId;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final questions = await _triviaService.fetchQuestions();

      if (!mounted || roundId != _roundId) return;

      setState(() {
        _questions = questions;
        _isLoading = false;
        _error = '';
      });
    } on TimeoutException {
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _error = 'Connection timed out. Check your network and try again.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _error = e is TriviaException ? e.message : 'Connection failed: $e';
        _isLoading = false;
      });
    }
  }

  void _answerQuestion(String option) {
    if (_answered) return;

    setState(() {
      _answered = true;
      _selectedOption = option;

      if (option == _questions[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentIndex < _questions.length - 1) {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      } else {
        _currentIndex++;
      }
    });
  }

  Map<String, dynamic> _buildSubmissionPayload() {
    return {
      'score': _score,
      'total': _questions.length,
      'roundId': _roundId,
      'submittedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'CSC4360 In-Class 15',
    };
  }

  Future<void> _syncScoreToCloud() async {
    if (_isSyncing || _isSynced) return;

    final roundId = _roundId;
    final payload = _buildSubmissionPayload();

    setState(() {
      _isSyncing = true;
    });

    try {
      if (_hasRealEndpoint) {
        final response = await http
            .post(
              Uri.parse(_leaderboardEndpoint!),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw TriviaException(
            'Leaderboard rejected the score: HTTP ${response.statusCode}',
          );
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 900));
      }

      if (!mounted || roundId != _roundId) return;

      setState(() {
        _isSyncing = false;
        _isSynced = true;
      });

      final message = _hasRealEndpoint
          ? 'Score synced to leaderboard.'
          : 'Simulated sync complete; no backend request was sent.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$message Payload: ${jsonEncode(payload)}')),
      );
    } catch (e) {
      if (!mounted || roundId != _roundId) return;

      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    }
  }

  void _restart() {
    _roundId++;

    setState(() {
      _isLoading = true;
      _error = '';
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _isSynced = false;
      _isSyncing = false;
    });

    _loadTriviaData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Trivia Showdown: API Edition')),
      body: Padding(padding: const EdgeInsets.all(20.0), child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentIndex >= _questions.length) {
      return _buildResultsScreen();
    }

    return _buildQuestionScreen();
  }

  Widget _buildQuestionScreen() {
    final question = _questions[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.orange.shade100,
          color: Colors.deepOrange,
        ),
        const SizedBox(height: 16),
        Text(
          'Question ${_currentIndex + 1} of ${_questions.length}',
          style: const TextStyle(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              question.questionText,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...question.options.map((option) {
          Color buttonColor = Colors.white;

          if (_answered) {
            if (option == question.correctAnswer) {
              buttonColor = Colors.green.shade200;
            } else if (option == _selectedOption) {
              buttonColor = Colors.red.shade200;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _answerQuestion(option),
              child: Text(option, style: const TextStyle(fontSize: 16)),
            ),
          );
        }),
        const Spacer(),
        if (_answered)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _nextQuestion,
            child: Text(
              _currentIndex < _questions.length - 1
                  ? 'Next Question →'
                  : 'View Final Score',
            ),
          ),
      ],
    );
  }

  Widget _buildResultsScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Showdown Complete!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Final Score: $_score / ${_questions.length}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 24),
          if (!_isSynced)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: _isSyncing ? null : _syncScoreToCloud,
              icon: const Icon(Icons.cloud_upload),
              label: Text(
                _isSyncing
                    ? 'Syncing...'
                    : _hasRealEndpoint
                    ? 'Sync Score to Leaderboard'
                    : 'Simulate Score Sync',
              ),
            )
          else
            const Text(
              '✓ Sync Complete',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 16),
          TextButton(onPressed: _restart, child: const Text('Play Again')),
        ],
      ),
    );
  }
}
