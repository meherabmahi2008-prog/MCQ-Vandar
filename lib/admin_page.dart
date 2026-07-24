import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  // 🔒 নতুন অ্যাডমিন পাসওয়ার্ড
  final String _appPassword = '#Hope001';
  final _passwordController = TextEditingController();
  bool _isLoggedIn = false;

  late TabController _tabController;

  // --- [১. প্রশ্ন আপলোড ফর্মে ব্যবহৃত কন্ট্রোলারসমূহ] ---
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _explanationController = TextEditingController(); 
  
  // মেমরিতে ধরে রাখার জন্য বিষয়, বোর্ড ও সাল
  final _subjectController = TextEditingController();
  final _boardController = TextEditingController();
  final _yearController = TextEditingController();

  int _correctAnswerIndex = 0;
  bool _isUploading = false;

  // --- [২. সার্চ ও ফিল্টারিং ফর্মে ব্যবহৃত কন্ট্রোলারসমূহ] ---
  final _searchController = TextEditingController();
  final _filterSubjectController = TextEditingController();
  final _filterBoardController = TextEditingController();
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

  void _verifyPassword() {
    if (_passwordController.text == _appPassword) {
      setState(() => _isLoggedIn = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ভুল পাসওয়ার্ড! আবার চেষ্টা করুন।'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- [ডাটাবেজে প্রশ্ন আপলোড করার লজিক] ---
  Future<void> _uploadQuestion() async {
    if (_questionController.text.isEmpty ||
        _optionControllers.any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('অনুগ্রহ করে প্রশ্ন ও ৪টি অপশনই পূরণ করুন'),
          backgroundColor: Colors.redAccent,
        ),
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
        'board': _boardController.text.trim().isEmpty
            ? null
            : _boardController.text.trim(),
        'year': int.tryParse(_yearController.text.trim()) ?? 2026,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('প্রশ্ন সফলভাবে আপলোড হয়েছে! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        _clearUploadForm(); // শুধুমাত্র প্রশ্ন, অপশন ও ব্যাখ্যা মুছে যাবে
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ভুল হয়েছে: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // বিষয়, বোর্ড ও সাল মেমরিতে থাকবে; বাকিগুলো মুছে নতুন প্রশ্নের জন্য প্রস্তুত হবে
  void _clearUploadForm() {
    _questionController.clear();
    for (var c in _optionControllers) {
      c.clear();
    }
    _explanationController.clear();
    setState(() => _correctAnswerIndex = 0);
  }

  // --- [ডাটাবেজ থেকে সার্চ ও ফিল্টার করার লজিক] ---
  Future<void> _fetchQuestions() async {
    setState(() => _isSearching = true);

    try {
      dynamic query = Supabase.instance.client.from('questions').select();

      if (_searchController.text.trim().isNotEmpty) {
        query = query.ilike('question_text', '%${_searchController.text.trim()}%');
      }
      if (_filterSubjectController.text.trim().isNotEmpty) {
        query = query.ilike('subject', '%${_filterSubjectController.text.trim()}%');
      }
      if (_filterBoardController.text.trim().isNotEmpty) {
        query = query.ilike('board', '%${_filterBoardController.text.trim()}%');
      }
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

  // --- [প্রশ্ন ডিলেট করার লজিক] ---
  Future<void> _deleteQuestion(int id) async {
    try {
      await Supabase.instance.client.from('questions').delete().eq('id', id);
      if (mounted) {
        Navigator.pop(context); // ডায়ালগ বন্ধ করা
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('প্রশ্নটি মুছে ফেলা হয়েছে!'), backgroundColor: Colors.redAccent),
        );
        _fetchQuestions(); // তালিকা রিফ্রেশ করা
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ডিলিট করতে সমস্যা: $e')),
        );
      }
    }
  }

  // --- [প্রশ্ন এডিট/আপডেট করার ডায়ালগ] ---
  void _showEditDialog(Map<String, dynamic> q) {
    final editQuestionController = TextEditingController(text: q['question_text']);
    final editExplanationController = TextEditingController(text: q['explanation'] ?? '');
    final editSubjectController = TextEditingController(text: q['subject'] ?? '');
    final editBoardController = TextEditingController(text: q['board'] ?? '');
    final editYearController = TextEditingController(text: q['year']?.toString() ?? '');
    
    final List<TextEditingController> editOptionControllers = List.generate(
      4,
      (i) => TextEditingController(text: (q['options'] as List)[i].toString()),
    );
    int editCorrectIndex = q['correct_option_index'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulWidget(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text('প্রশ্ন এডিট করুন (ID: ${q['id']})', style: const TextStyle(color: Colors.redAccent)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editQuestionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'প্রশ্ন', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(4, (i) {
                      return Row(
                        children: [
                          Radio<int>(
                            value: i,
                            groupValue: editCorrectIndex,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              if (val != null) setDialogState(() => editCorrectIndex = val);
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: editOptionControllers[i],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(labelText: 'অপশন ${i + 1}', labelStyle: const TextStyle(color: Colors.white70)),
                            ),
                          ),
                        ],
                      );
                    }),
                    TextField(
                      controller: editExplanationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'ব্যাখ্যা', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: editSubjectController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'বিষয়', labelStyle: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: TextField(
                            controller: editBoardController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'বোর্ড', labelStyle: TextStyle(color: Colors.white70)),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: editYearController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'সাল', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বাতিল', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redDark),
                  onPressed: () async {
                    try {
                      final updatedOptions = editOptionControllers.map((c) => c.text.trim()).toList();
                      await Supabase.instance.client.from('questions').update({
                        'question_text': editQuestionController.text.trim(),
                        'options': updatedOptions,
                        'correct_option_index': editCorrectIndex,
                        'explanation': editExplanationController.text.trim().isEmpty ? null : editExplanationController.text.trim(),
                        'subject': editSubjectController.text.trim(),
                        'board': editBoardController.text.trim().isEmpty ? null : editBoardController.text.trim(),
                        'year': int.tryParse(editYearController.text.trim()) ?? 2026,
                      }).eq('id', q['id']);

                      if (mounted) {
                        Navigator.pop(context); // এডিট পপআপ বন্ধ
                        Navigator.pop(context); // ডিটেইলস পপআপ বন্ধ
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('আপডেট সফল হয়েছে!'), backgroundColor: Colors.green),
                        );
                        _fetchQuestions(); // তালিকা আপডেট
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('আপডেটে সমস্যা: $e')),
                      );
                    }
                  },
                  child: const Text('সেভ করুন', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- [প্রশ্নের ডিটেইলস পপআপ ডায়ালগ (এডিট ও ডিলিট বাটন সহ)] ---
  void _showQuestionDetails(Map<String, dynamic> q) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ID: ${q['id']}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.amber),
                  onPressed: () => _showEditDialog(q),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: const Color(0xFF2C2C2C),
                        title: const Text('নিশ্চিত নিশ্চিত?', style: TextStyle(color: Colors.white)),
                        content: const Text('আপনি কি এই প্রশ্নটি মুছে ফেলতে চান?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('না'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () {
                              Navigator.pop(c);
                              _deleteQuestion(q['id']);
                            },
                            child: const Text('হ্যাঁ, ডিলিট করুন', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('❓ প্রশ্ন: ${q['question_text']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 10),
              const Text('অপশনসমূহ:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
              ...List.generate((q['options'] as List).length, (i) {
                final isCorrect = i == q['correct_option_index'];
                final optionLabel = ['ক', 'খ', 'গ', 'ঘ'][i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    '$optionLabel) ${q['options'][i]} ${isCorrect ? '✅ (সঠিক)' : ''}',
                    style: TextStyle(
                      color: isCorrect ? Colors.greenAccent : Colors.white70,
                      fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              Text('💡 ব্যাখ্যা: ${q['explanation'] ?? 'কোনো ব্যাখ্যা দেওয়া হয়নি'}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text('📚 বিষয়: ${q['subject'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
              Text('🏛️ বোর্ড: ${q['board'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
              Text('📅 সাল: ${q['year'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('বন্ধ করুন', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('অ্যাডমিন লগইন'),
          backgroundColor: Colors.redDark,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 80, color: Colors.redAccent),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'পাসওয়ার্ড দিন',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _verifyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('প্রবেশ করুন', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('অ্যাডমিন প্যানেল'),
        backgroundColor: Colors.redDark,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.redAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle_outline), text: 'প্রশ্ন যুক্ত করুন'),
            Tab(icon: Icon(Icons.search), text: 'সার্চ ও ম্যানেজ'),
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

  // --- [ট্যাব ১: লাল-কালো শেডে প্রশ্ন আপলোড UI] ---
  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _questionController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('প্রশ্ন লিখুন *'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text('৪টি অপশন লিখুন এবং সঠিক উত্তর নির্বাচন করুন:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
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
                    activeColor: Colors.redAccent,
                    onChanged: (val) {
                      if (val != null) setState(() => _correctAnswerIndex = val);
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _optionControllers[index],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('অপশন ${optionLabels[index]} *'),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _explanationController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('উত্তরের ব্যাখ্যা (অপশনাল)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          // বিষয়, বোর্ড ও সাল (যা মেমরিতে থেকে যাবে)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _subjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('বিষয়'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _boardController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('বোর্ড'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _yearController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('সাল (যেমন: 2026)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadQuestion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
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

  // --- [ট্যাব ২: সার্চ, ফিল্টার, এডিট ও ডিলিট UI] ---
  Widget _buildSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('প্রশ্ন দিয়ে খুঁজুন', icon: Icons.search),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _filterSubjectController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('বিষয় ফিল্টার'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _filterBoardController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('বোর্ড ফিল্টার'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _filterYearController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('সাল ফিল্টার'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _isSearching ? null : _fetchQuestions,
            icon: const Icon(Icons.filter_alt),
            label: const Text('খুঁজুন / ফিল্টার করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redDark,
              foregroundColor: Colors.white,
            ),
          ),
          const Divider(height: 20, color: Colors.white24),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                : _searchResults.isEmpty
                    ? const Center(child: Text('কোনো প্রশ্ন পাওয়া যায়নি', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final q = _searchResults[index];
                          return Card(
                            color: const Color(0xFF1E1E1E),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(
                                q['question_text'] ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(
                                'ID: ${q['id']} | বিষয়: ${q['subject'] ?? 'N/A'} | বোর্ড: ${q['board'] ?? 'N/A'} | সাল: ${q['year'] ?? 'N/A'}',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
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

  // ইনপুট ফিল্ডের স্টাইল
  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: icon != null ? Icon(icon, color: Colors.redAccent) : null,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
      fillColor: const Color(0xFF1E1E1E),
      filled: true,
    );
  }
}

// কালার কাস্টমাইজেশন
extension CustomColors on Colors {
  static const Color redDark = Color(0xFF8B0000);
}
