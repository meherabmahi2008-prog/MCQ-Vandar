import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  // 🔒 অ্যাডমিন পাসওয়ার্ড
  final String _appPassword = '1234';
  final _passwordController = TextEditingController();
  bool _isLoggedIn = false;

  late TabController _tabController;

  // --- [১. প্রশ্ন আপলোড ফর্মে ব্যবহৃত কন্ট্রোলারসমূহ] ---
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _explanationController = TextEditingController(); // ব্যাখ্যা (অপশনাল)
  final _subjectController = TextEditingController();
  final _yearController = TextEditingController();

  int _correctAnswerIndex = 0;
  bool _isUploading = false;

  // --- [২. সার্চ ও ফিল্টারিং ফর্মে ব্যবহৃত কন্ট্রোলারসমূহ] ---
  final _searchController = TextEditingController();
  final _filterSubjectController = TextEditingController();
  final _filterYearController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // পাসওয়ার্ড যাচাই
  void _verifyPassword() {
    if (_passwordController.text == _appPassword) {
      setState(() => _isLoggedIn = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ভুল পাসওয়ার্ড! আবার চেষ্টা করুন।')),
      );
    }
  }

  // --- [ডাটাবেজে প্রশ্ন আপলোড লজিক] ---
  Future<void> _uploadQuestion() async {
    if (_questionController.text.isEmpty ||
        _optionControllers.any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('অনুগ্রহ করে প্রশ্ন ও ৪টি অপশনই পূরণ করুন')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final options = _optionControllers.map((c) => c.text.trim()).toList();

      await Supabase.instance.client.from('questions').insert({
        'question_text': _questionController.text.trim(),
        'options': options,
        'correct_option_index': _correctAnswerIndex,
        'explanation': _explanationController.text.trim().isEmpty
            ? null
            : _explanationController.text.trim(),
        'subject': _subjectController.text.trim().isEmpty
            ? 'General'
            : _subjectController.text.trim(),
        'year': int.tryParse(_yearController.text.trim()) ?? 2026,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('প্রশ্ন সফলভাবে আপলোড হয়েছে! 🎉')),
        );
        _clearUploadForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ভুল হয়েছে: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearUploadForm() {
    _questionController.clear();
    for (var c in _optionControllers) {
      c.clear();
    }
    _explanationController.clear();
    _subjectController.clear();
    _yearController.clear();
    setState(() => _correctAnswerIndex = 0);
  }

  // --- [ডাটাবেজ থেকে সার্চ ও ফিল্টার করার লজিক] ---
  Future<void> _fetchQuestions() async {
    setState(() => _isSearching = true);

    try {
      dynamic query = Supabase.instance.client.from('questions').select();

      // টেক্সট সার্চ (প্রশ্নের অংশ নিয়ে)
      if (_searchController.text.trim().isNotEmpty) {
        query = query.ilike('question_text', '%${_searchController.text.trim()}%');
      }

      // বিষয়/বোর্ড ফিল্টার
      if (_filterSubjectController.text.trim().isNotEmpty) {
        query = query.ilike('subject', '%${_filterSubjectController.text.trim()}%');
      }

      // সাল ফিল্টার
      if (_filterYearController.text.trim().isNotEmpty) {
        final yearVal = int.tryParse(_filterYearController.text.trim());
        if (yearVal != null) {
          query = query.eq('year', yearVal);
        }
      }

      final response = await query.order('id', ascending: false);

      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('সার্চে সমস্যা হয়েছে: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // --- [প্রশ্নের ডিটেইলস পপআপ ডায়ালগ] ---
  void _showQuestionDetails(Map<String, dynamic> q) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('প্রশ্ন ID: ${q['id']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('❓ প্রশ্ন: ${q['question_text']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              const Text('অপশনসমূহ:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...List.generate((q['options'] as List).length, (i) {
                final isCorrect = i == q['correct_option_index'];
                final optionLabel = ['ক', 'খ', 'গ', 'ঘ'][i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    '$optionLabel) ${q['options'][i]} ${isCorrect ? '✅ (সঠিক)' : ''}',
                    style: TextStyle(
                      color: isCorrect ? Colors.green : Colors.black,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              Text('💡 ব্যাখ্যা: ${q['explanation'] ?? 'কোনো ব্যাখ্যা দেওয়া হয়নি'}'),
              const SizedBox(height: 8),
              Text('📌 বিষয়/বোর্ড: ${q['subject'] ?? 'N/A'}'),
              Text('📅 সাল: ${q['year'] ?? 'N/A'}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('অ্যাডমিন লগইন')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 70, color: Colors.deepPurple),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'পাসওয়ার্ড দিন',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _verifyPassword,
                  child: const Text('প্রবেশ করুন'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('অ্যাডমিন প্যানেল'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'প্রশ্ন যুক্ত করুন'),
            Tab(icon: Icon(Icons.search), text: 'সার্চ ও ভিউ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUploadTab(),
          _buildSearchTab(),
        ],
      ),
    );
  }

  // --- [ট্যাব ১: নতুন প্রশ্ন আপলোড UI] ---
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'প্রশ্ন লিখুন *',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text('৪টি অপশন লিখুন এবং সঠিক উত্তর নির্বাচন করুন:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(4, (index) {
            final optionLabels = ['ক', 'খ', 'গ', 'ঘ'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: _correctAnswerIndex,
                    onChanged: (val) {
                      if (val != null) setState(() => _correctAnswerIndex = val);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'অপশন ${optionLabels[index]} *',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _explanationController,
            decoration: const InputDecoration(
              labelText: 'উত্তরের ব্যাখ্যা (অপশনাল)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'বিষয় / বোর্ড',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'সাল (যেমন: 2026)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isUploading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('ডাটাবেজে সেভ করুন', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // --- [ট্যাব ২: সার্চ ও ফিল্টার UI] ---
  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'প্রশ্ন বা প্রশ্নের অংশ দিয়ে খুঁজুন',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterSubjectController,
                  decoration: const InputDecoration(
                    labelText: 'বিষয়/বোর্ড ফিল্টার',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _filterYearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'সাল ফিল্টার',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isSearching ? null : _fetchQuestions,
            icon: const Icon(Icons.filter_alt),
            label: const Text('খুঁজুন / ফিল্টার করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? const Center(child: Text('কোনো প্রশ্ন পাওয়া যায়নি'))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final q = _searchResults[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(
                                q['question_text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'ID: ${q['id']} | বোর্ড: ${q['subject'] ?? 'N/A'} | সাল: ${q['year'] ?? 'N/A'}',
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showQuestionDetails(q),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
