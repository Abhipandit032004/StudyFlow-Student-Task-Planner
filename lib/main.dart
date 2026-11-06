import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseReady = false;
  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey.startsWith('YOUR_') || options.projectId.startsWith('YOUR_')) {
      throw StateError('Firebase options are placeholders');
    }
    await Firebase.initializeApp(options: options);
    firebaseReady = true;
  } catch (error) {
    debugPrint('Firebase is not configured yet: $error');
  }
  runApp(StudyFlowApp(firebaseReady: firebaseReady));
}

const Color brand = Color(0xFF6257E8);
const Color brandDark = Color(0xFF4B40C8);
const Color pageBg = Color(0xFFF6F7FB);
const Color ink = Color(0xFF20243A);
const Color secondaryInk = Color(0xFF85899D);
const Color borderColor = Color(0xFFE9EAF2);

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key, required this.firebaseReady});
  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyFlow | Student Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: pageBg,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, primary: brand),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F8FC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: brand, width: 1.5)),
        ),
      ),
      home: firebaseReady ? const AuthGate() : const FirebaseSetupScreen(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const _LoadingTransition();
      }
      return snapshot.data == null ? const AuthPage() : const PlannerShell();
    },
  );
}

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: borderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [brand, brandDark]), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 28)),
        const SizedBox(height: 22), const Text('One setup step left', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(height: 10), const Text('StudyFlow is ready for Firebase, but this copy does not have your Firebase project configuration yet. Connect your own Firebase project before using real student accounts.', style: TextStyle(color: secondaryInk, height: 1.6)),
        const SizedBox(height: 20), const Text('In the project terminal:', style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF6F7FB), borderRadius: BorderRadius.circular(12)), child: const SelectableText('dart pub global activate flutterfire_cli\nflutterfire configure', style: TextStyle(fontFamily: 'monospace', height: 1.7, color: ink))),
        const SizedBox(height: 12), const Text('Then enable Email/Password in Firebase Authentication, create a Cloud Firestore database, apply the security rules in README.md, and restart the app.', style: TextStyle(color: secondaryInk, height: 1.6)),
      ])),
    ))),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AnimationController _animation = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  bool _register = false;
  bool _hidePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _animation.dispose(); _name.dispose(); _email.dispose(); _password.dispose(); super.dispose(); }

  String _friendlyError(FirebaseAuthException e) => switch (e.code) {
    'email-already-in-use' => 'An account already exists for this email.',
    'invalid-email' => 'Enter a valid email address.',
    'weak-password' => 'Use a stronger password with at least 6 characters.',
    'user-not-found' => 'No account found. Please create a new account.',
'wrong-password' || 'invalid-credential' => 'Email or password is incorrect. Please check your details.',
    'network-request-failed' => 'Network error. Check your internet connection.',
    'too-many-requests' => 'Too many attempts. Please try again later.',
    _ => e.message ?? 'Unable to authenticate right now. Please try again.',
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
        final displayName = _name.text.trim();
        if (displayName.isNotEmpty) await credential.user?.updateDisplayName(displayName);
        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid, 'name': displayName, 'email': _email.text.trim(), 'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await auth.signInWithEmailAndPassword(email: _email.text.trim(), password: _password.text);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) { setState(() => _error = 'Enter your email above, then tap Forgot password.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _error = 'If an account exists for that email, a reset link has been sent.');
    } on FirebaseAuthException catch (e) { if (mounted) setState(() => _error = _friendlyError(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 820;
    final form = _authForm();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1050), child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: borderColor), boxShadow: const [BoxShadow(color: Color(0x100D1230), blurRadius: 36, offset: Offset(0, 16))]),
          child: ClipRRect(borderRadius: BorderRadius.circular(30), child: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: _authIllustration()), Expanded(flex: 5, child: Padding(padding: const EdgeInsets.all(42), child: form))])
            : Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(height: 145, child: _authIllustration()), Padding(padding: const EdgeInsets.fromLTRB(25, 12, 25, 25), child: form)]),
          ),
        )),
      ))),
    );
  }

  Widget _authForm() => ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
    Row(children: [Container(width: 42, height: 42, decoration: BoxDecoration(gradient: const LinearGradient(colors: [brand, brandDark]), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.school_rounded, color: Colors.white)), const SizedBox(width: 11), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('StudyFlow', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)), Text('YOUR PERSONAL STUDY SPACE', style: TextStyle(fontSize: 8, letterSpacing: 1.2, color: secondaryInk, fontWeight: FontWeight.w700))])]),
    const SizedBox(height: 30), Text(_register ? 'Create your account' : 'Welcome back', style: const TextStyle(fontSize: 28, height: 1.1, letterSpacing: -.7, fontWeight: FontWeight.w900, color: ink)),
    const SizedBox(height: 8), Text(_register ? 'Build better study habits, one task at a time.' : 'Sign in to continue with your goals.', style: const TextStyle(color: secondaryInk, height: 1.5)),
    const SizedBox(height: 23),
    if (_register) ...[TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)), validator: (v) => _register && (v == null || v.trim().length < 2) ? 'Enter your name' : null), const SizedBox(height: 13)],
    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline_rounded)), validator: (v) => v == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? 'Enter a valid email address' : null),
    const SizedBox(height: 13), TextFormField(controller: _password, obscureText: _hidePassword, autofillHints: _register ? const [AutofillHints.newPassword] : const [AutofillHints.password], decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => _hidePassword = !_hidePassword), icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null, onFieldSubmitted: (_) { if (!_busy) _submit(); }),
    Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: _busy ? null : _forgotPassword,
    child: const Text('Forgot password?'),
  ),
),
    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _error!.startsWith('If an account') ? const Color(0xFFE8F7EF) : const Color(0xFFFFEEEE), borderRadius: BorderRadius.circular(12)), child: Text(_error!, style: TextStyle(color: _error!.startsWith('If an account') ? const Color(0xFF18764D) : const Color(0xFFB42332), fontSize: 12, height: 1.4)))),
    const SizedBox(height: 8), SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: _busy ? null : _submit, style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _busy ? const SizedBox(key: ValueKey('loading'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Row(key: const ValueKey('label'), mainAxisAlignment: MainAxisAlignment.center, children: [Text(_register ? 'Create account' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 9), const Icon(Icons.arrow_forward_rounded, size: 18)])))),
   const SizedBox(height: 14),


const SizedBox(height: 16),
Center(
  child: Wrap(
    alignment: WrapAlignment.center,
    children: [
      Text(
        _register ? 'Already have an account? ' : 'New to StudyFlow? ',
        style: const TextStyle(color: secondaryInk, fontSize: 12),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _register = !_register;
                  _error = null;
                }),
        child: Text(_register ? 'Sign in' : 'Create account'),
      ),
    ],
  ),
),
const SizedBox(height: 8),
     const Center(child: Text('Your tasks. Your pace. Your progress.', style: TextStyle(color: secondaryInk, fontSize: 11))),
  ])));

  Widget _authIllustration() {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final orbitSize = compact ? 112.0 : 190.0;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF27215F), Color(0xFF6257E8), Color(0xFF8A80F4)])),
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.hardEdge, children: [
        Positioned(top: -40, right: -30, child: _orb(compact ? 100 : 180, const Color(0x33FFFFFF))),
        Positioned(bottom: -55, left: -35, child: _orb(compact ? 110 : 190, const Color(0x22FFFFFF))),
        Container(width: orbitSize, height: orbitSize, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x66FFFFFF), width: 1.5))),
        AnimatedBuilder(animation: _animation, builder: (context, child) {
          final angle = _animation.value * math.pi * 2;
          return Transform.translate(offset: Offset(math.cos(angle) * (compact ? 56 : 95), math.sin(angle) * (compact ? 56 : 95)), child: child);
        }, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFFFD37B), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10)]), child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF5A3B00), size: 19))),
        Icon(Icons.school_rounded, color: Colors.white, size: compact ? 42 : 72),
        if (!compact) ...[
          Positioned(top: 52, left: 34, child: _floatCard(Icons.check_circle_rounded, 'Tasks organized', const Color(0xFF16845B))),
          Positioned(right: 28, top: 105, child: _floatCard(Icons.alarm_rounded, 'Deadlines clear', const Color(0xFFA86A08))),
          Positioned(left: 35, bottom: 115, child: _floatCard(Icons.trending_up_rounded, 'Progress grows', const Color(0xFF216BB3))),
          const Positioned(left: 32, right: 32, bottom: 30, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Make room for\nyour best work.', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.1, fontWeight: FontWeight.w900)), SizedBox(height: 10), Text('A calmer way to plan, focus and finish what matters.', style: TextStyle(color: Color(0xFFDCD9FF), height: 1.5))])),
        ],
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  Widget _floatCard(IconData icon, String label, Color tint) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: tint, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800))]));
}

class _LoadingTransition extends StatefulWidget {
  const _LoadingTransition({super.key});
  @override
  State<_LoadingTransition> createState() => _LoadingTransitionState();
}
class _LoadingTransitionState extends State<_LoadingTransition> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: pageBg, body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [RotationTransition(turns: _controller, child: const Icon(Icons.auto_awesome_rounded, size: 46, color: brand)), const SizedBox(height: 16), const Text('Getting your study space ready…', style: TextStyle(color: secondaryInk, fontWeight: FontWeight.w700))])));
}

enum Priority { low, medium, high }
enum TaskFilter { all, today, upcoming, completed }

class StudyTask {
  StudyTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.priority,
    this.notes = '',
    this.isDone = false,
    required this.createdAt,
  });

  final String id;
  String title;
  String subject;
  DateTime dueDate;
  Priority priority;
  String notes;
  bool isDone;
  final DateTime createdAt;

  bool get isOverdue => !isDone && dueDate.isBefore(DateTime.now()) && !_sameDay(dueDate, DateTime.now());

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'subject': subject, 'dueDate': dueDate.toIso8601String(),
    'priority': priority.name, 'notes': notes, 'isDone': isDone, 'createdAt': createdAt.toIso8601String(),
  };

  factory StudyTask.fromJson(Map<String, dynamic> json) => StudyTask(
    id: json['id'] as String,
    title: json['title'] as String,
    subject: json['subject'] as String? ?? 'General',
    dueDate: json['dueDate'] is Timestamp ? (json['dueDate'] as Timestamp).toDate() : DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
    priority: Priority.values.firstWhere((p) => p.name == json['priority'], orElse: () => Priority.medium),
    notes: json['notes'] as String? ?? '',
    isDone: json['isDone'] as bool? ?? false,
    createdAt: json['createdAt'] is Timestamp ? (json['createdAt'] as Timestamp).toDate() : DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateLabel(DateTime date) {
  final now = DateTime.now();
  if (_sameDay(date, now)) return 'Today';
  if (_sameDay(date, now.add(const Duration(days: 1)))) return 'Tomorrow';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]}';
}
String _timeLabel(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
}

class PlannerShell extends StatefulWidget {
  const PlannerShell({super.key});
  @override
  State<PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<PlannerShell> {
  final List<StudyTask> _tasks = [];
  bool _loading = true;
  int _navIndex = 0;
  TaskFilter _filter = TaskFilter.all;
  String _query = '';
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('tasks').orderBy('createdAt', descending: true).get();
      _tasks
        ..clear()
        ..addAll(snapshot.docs.map((doc) => StudyTask.fromJson({...doc.data(), 'id': doc.id})));
    } catch (e) {
      if (mounted) _snack('Could not load cloud tasks. Check your connection and Firestore rules.');
      debugPrint('StudyFlow load error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final now = DateTime.now();
          final dueCount = _tasks.where((task) => !task.isDone && (task.isOverdue || _sameDay(task.dueDate, now))).length;
          if (dueCount > 0) _snack('Reminder: $dueCount task(s) are due today or overdue. Tap the bell for details.');
        });
      }
    }
  }

  Future<void> _saveTask(StudyTask task) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('tasks').doc(task.id).set({
        ...task.toJson(),
        'createdAt': Timestamp.fromDate(task.createdAt),
        'dueDate': Timestamp.fromDate(task.dueDate),
      });
    } catch (e) {
      debugPrint('StudyFlow save error: $e');
      if (mounted) _snack('Could not sync this task. Check internet and Firestore rules.');
    }
  }

  Future<void> _removeTaskFromCloud(String taskId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('tasks').doc(taskId).delete();
    } catch (e) {
      debugPrint('StudyFlow delete error: $e');
      if (mounted) _snack('Could not sync task deletion. Check internet and Firestore rules.');
    }
  }

  int get _completed => _tasks.where((t) => t.isDone).length;
  int get _pending => _tasks.length - _completed;
  double get _progress => _tasks.isEmpty ? 0 : _completed / _tasks.length;

  List<StudyTask> get _visibleTasks {
    final q = _query.trim().toLowerCase();
    final list = _tasks.where((task) {
      final matchesQuery = q.isEmpty || task.title.toLowerCase().contains(q) || task.subject.toLowerCase().contains(q) || task.notes.toLowerCase().contains(q);
      final matchesFilter = switch (_filter) {
        TaskFilter.all => true,
        TaskFilter.today => _sameDay(task.dueDate, DateTime.now()) && !task.isDone,
        TaskFilter.upcoming => task.dueDate.isAfter(DateTime.now()) && !_sameDay(task.dueDate, DateTime.now()) && !task.isDone,
        TaskFilter.completed => task.isDone,
      };
      return matchesQuery && matchesFilter;
    }).toList()..sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.dueDate.compareTo(b.dueDate);
    });
    return list;
  }

  Future<void> _openTaskEditor({StudyTask? task}) async {
    final result = await showDialog<StudyTask>(context: context, builder: (_) => TaskEditorDialog(task: task));
    if (result == null || !mounted) return;
    setState(() {
      if (task == null) {
        _tasks.insert(0, result);
      } else {
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) _tasks[index] = result;
      }
    });
    await _saveTask(result);
    if (mounted) _snack(task == null ? 'Task created' : 'Task updated');
  }

  Future<void> _toggleTask(StudyTask task, bool value) async {
    setState(() => task.isDone = value);
    await _saveTask(task);
  }

  Future<void> _deleteTask(StudyTask task) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete task?'),
      content: Text('“${task.title}” will be permanently removed from this device.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD94D5C)), child: const Text('Delete'))],
    ));
    if (confirm == true && mounted) {
      setState(() => _tasks.removeWhere((t) => t.id == task.id));
      await _removeTaskFromCloud(task.id);
      if (mounted) _snack('Task deleted');
    }
  }

  void _showReminders() {
    final now = DateTime.now();
    final reminders = _tasks.where((task) => !task.isDone && (task.isOverdue || _sameDay(task.dueDate, now) || _sameDay(task.dueDate, now.add(const Duration(days: 1))))).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Row(children: [Icon(Icons.notifications_active_outlined, color: brand), SizedBox(width: 10), Text('Reminder center')]),
      content: SizedBox(width: 440, child: reminders.isEmpty
        ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('You are all caught up. No overdue or upcoming deadlines need your attention.', style: TextStyle(height: 1.5)))
        : ListView.separated(shrinkWrap: true, itemCount: reminders.length, separatorBuilder: (_, __) => const Divider(height: 18), itemBuilder: (_, index) {
          final task = reminders[index];
          final overdue = task.isOverdue;
          final dueToday = _sameDay(task.dueDate, now);
          final label = overdue ? 'OVERDUE — complete this task as soon as possible' : dueToday ? 'DUE TODAY — remember to finish before the deadline' : 'DUE TOMORROW — plan time to complete this task';
          return ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(backgroundColor: overdue ? const Color(0xFFFFE7EA) : const Color(0xFFFFF2DC), child: Icon(overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded, color: overdue ? const Color(0xFFD94D5C) : const Color(0xFFC88717))), title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('$label\n${_dateLabel(task.dueDate)} · ${_timeLabel(task.dueDate)}', style: const TextStyle(height: 1.45, fontSize: 11))), isThreeLine: true);
        })),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
    ));
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, width: 320));

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;
    return Scaffold(
      body: SafeArea(child: Row(children: [
        if (wide) _Sidebar(selected: _navIndex, onSelect: (i) => setState(() => _navIndex = i)),
        Expanded(child: Column(children: [
          _TopBar(searchOpen: _searchOpen, query: _query, onSearchToggle: () => setState(() => _searchOpen = !_searchOpen), onQuery: (v) => setState(() => _query = v), onAdd: () => _openTaskEditor(), onLogout: () => FirebaseAuth.instance.signOut(), onReminders: _showReminders, userEmail: FirebaseAuth.instance.currentUser?.email ?? ''),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: brand)) : _navIndex == 1 ? _tasksPage(wide) : _navIndex == 2 ? _CalendarPage(tasks: _tasks, onToggle: _toggleTask, onEdit: (t) => _openTaskEditor(task: t)) : _navIndex == 3 ? _InsightsPage(tasks: _tasks) : _dashboard(wide)),
          if (!wide) _MobileNav(selected: _navIndex, onSelect: (i) => setState(() => _navIndex = i)),
        ])),
      ])),
      // On mobile, New Task lives in the top bar so it never overlaps bottom navigation.
    );
  }

  Widget _tasksPage(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 26, wide ? 34 : 18, 28),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('My tasks', style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      const Text('Keep every assignment and deadline in one place.', style: TextStyle(color: secondaryInk)),
      const SizedBox(height: 20),
      _taskPanel(),
    ]))),
  );

  Widget _dashboard(bool wide) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(wide ? 34 : 18, 26, wide ? 34 : 18, 100),
    child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1280), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Greeting(onAdd: () => _openTaskEditor()),
      const SizedBox(height: 25),
      LayoutBuilder(builder: (context, c) {
        final columns = c.maxWidth > 850 ? 4 : c.maxWidth > 520 ? 2 : 1;
        final itemWidth = (c.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          SizedBox(width: itemWidth, child: _MetricCard(title: 'Total tasks', value: '${_tasks.length}', caption: 'Across your subjects', icon: Icons.checklist_rounded, tint: const Color(0xFFEDEAFF), iconColor: brand)),
          SizedBox(width: itemWidth, child: _MetricCard(title: 'Completed', value: '$_completed', caption: 'Tasks finished', icon: Icons.task_alt_rounded, tint: const Color(0xFFE2F7ED), iconColor: const Color(0xFF1A9A6B))),
          SizedBox(width: itemWidth, child: _MetricCard(title: 'Pending', value: '$_pending', caption: 'Still on your list', icon: Icons.hourglass_bottom_rounded, tint: const Color(0xFFFFF2DC), iconColor: const Color(0xFFC88717))),
          SizedBox(width: itemWidth, child: _MetricCard(title: 'Completion', value: '${(_progress * 100).round()}%', caption: 'Overall progress', icon: Icons.trending_up_rounded, tint: const Color(0xFFE3F1FF), iconColor: const Color(0xFF3186D8))),
        ]);
      }),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, c) {
        final stacked = c.maxWidth < 820;
        final taskPanel = _taskPanel();
        final sidePanel = _focusPanel();
        return stacked ? Column(children: [taskPanel, const SizedBox(height: 18), sidePanel]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: taskPanel), const SizedBox(width: 18), Expanded(flex: 4, child: sidePanel)]);
      }),
    ]))),
  );

  Widget _taskPanel() => _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your tasks', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)), SizedBox(height: 4), Text('Plan your work and protect your focus', style: TextStyle(color: secondaryInk, fontSize: 12))])), IconButton(onPressed: () => _openTaskEditor(), icon: const Icon(Icons.add_circle_outline_rounded, color: brand), tooltip: 'Create task')]),
    const SizedBox(height: 12),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      _FilterChip(label: 'All', count: _tasks.length, selected: _filter == TaskFilter.all, onTap: () => setState(() => _filter = TaskFilter.all)),
      const SizedBox(width: 7), _FilterChip(label: 'Today', count: _tasks.where((t) => _sameDay(t.dueDate, DateTime.now()) && !t.isDone).length, selected: _filter == TaskFilter.today, onTap: () => setState(() => _filter = TaskFilter.today)),
      const SizedBox(width: 7), _FilterChip(label: 'Upcoming', selected: _filter == TaskFilter.upcoming, onTap: () => setState(() => _filter = TaskFilter.upcoming)),
      const SizedBox(width: 7), _FilterChip(label: 'Completed', selected: _filter == TaskFilter.completed, onTap: () => setState(() => _filter = TaskFilter.completed)),
    ])),
    const SizedBox(height: 8),
    if (_visibleTasks.isEmpty) _EmptyTasks(onAdd: () => _openTaskEditor()) else ..._visibleTasks.map((task) => _TaskCard(task: task, onToggle: (v) => _toggleTask(task, v), onEdit: () => _openTaskEditor(task: task), onDelete: () => _deleteTask(task))),
  ]));

  Widget _focusPanel() => Column(children: [
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Today’s focus', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
      const SizedBox(height: 5), const Text('Consistency beats cramming.', style: TextStyle(fontSize: 12, color: secondaryInk)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(16)), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.bolt_rounded, color: brand)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_pending == 0 ? 'All caught up!' : 'One step at a time', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 4), Text(_pending == 0 ? 'You have no pending tasks.' : '$_pending task${_pending == 1 ? '' : 's'} waiting for you.', style: const TextStyle(color: secondaryInk, fontSize: 12))]))])),
      const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Overall progress', style: TextStyle(fontWeight: FontWeight.w700, color: ink)), Text('${(_progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, color: brand))]),
      const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _progress, minHeight: 9, backgroundColor: const Color(0xFFECECF4), color: brand)),
      const SizedBox(height: 8), Text('$_completed of ${_tasks.length} tasks completed', style: const TextStyle(color: secondaryInk, fontSize: 12)),
    ])),
    const SizedBox(height: 18),
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Study smarter', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ink)), const SizedBox(height: 14), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFFFFF1D9), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFC88717))), const SizedBox(width: 12), const Expanded(child: Text('Use 25-minute focus sessions followed by a 5-minute break. Start with your highest-priority task.', style: TextStyle(color: secondaryInk, height: 1.5, fontSize: 13)))])])),
  ]);
}

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({super.key, this.task});
  final StudyTask? task;
  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _subject;
  late final TextEditingController _notes;
  late DateTime _due;
  late Priority _priority;
  late bool _done;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _subject = TextEditingController(text: task?.subject ?? '');
    _notes = TextEditingController(text: task?.notes ?? '');
    _due = task?.dueDate ?? DateTime.now().add(const Duration(hours: 2));
    _priority = task?.priority ?? Priority.medium;
    _done = task?.isDone ?? false;
  }

  @override
  void dispose() { _title.dispose(); _subject.dispose(); _notes.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _due, firstDate: DateTime(2020), lastDate: DateTime(2100), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: brand)), child: child!));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (time != null && mounted) setState(() => _due = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.task;
    Navigator.pop(context, StudyTask(id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(), title: _title.text.trim(), subject: _subject.text.trim().isEmpty ? 'General' : _subject.text.trim(), dueDate: _due, priority: _priority, notes: _notes.text.trim(), isDone: _done, createdAt: existing?.createdAt ?? DateTime.now()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'Create a task' : 'Edit task', style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
    content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TASK DETAILS', style: TextStyle(fontSize: 10, color: secondaryInk, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 8), TextFormField(controller: _title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Task title', hintText: 'e.g. Finish assignment'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a task title' : null),
      const SizedBox(height: 12), TextFormField(controller: _subject, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Subject or category', hintText: 'e.g. Computer Science')),
      const SizedBox(height: 12), TextFormField(controller: _notes, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Notes (optional)', hintText: 'Add details or a checklist…')),
      const SizedBox(height: 18), const Text('SCHEDULE & PRIORITY', style: TextStyle(fontSize: 10, color: secondaryInk, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      const SizedBox(height: 8), InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF8F8FC), border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.calendar_month_outlined, color: brand), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Due date and time', style: TextStyle(color: secondaryInk, fontSize: 11)), const SizedBox(height: 4), Text('${_dateLabel(_due)} · ${_due.day.toString().padLeft(2, '0')}/${_due.month.toString().padLeft(2, '0')}/${_due.year} at ${_timeLabel(_due)}', style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12))])), const Icon(Icons.chevron_right_rounded, color: secondaryInk)]))),
      const SizedBox(height: 12), DropdownButtonFormField<Priority>(value: _priority, decoration: const InputDecoration(labelText: 'Priority'), items: Priority.values.map((p) => DropdownMenuItem(value: p, child: Text('${p.name[0].toUpperCase()}${p.name.substring(1)} priority'))).toList(), onChanged: (v) => setState(() => _priority = v ?? Priority.medium)),
      const SizedBox(height: 8), CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: _done, onChanged: (v) => setState(() => _done = v ?? false), title: const Text('Mark as completed', style: TextStyle(fontSize: 13, color: ink))),
    ])))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: _save, style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white), child: Text(widget.task == null ? 'Create task' : 'Save changes'))],
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.searchOpen, required this.query, required this.onSearchToggle, required this.onQuery, required this.onAdd, required this.onLogout, required this.onReminders, required this.userEmail});
  final bool searchOpen;
  final String query;
  final VoidCallback onSearchToggle, onAdd, onLogout, onReminders;
  final ValueChanged<String> onQuery;
  final String userEmail;
  @override
  Widget build(BuildContext context) => 
Container(
  padding: EdgeInsets.symmetric(
    horizontal: MediaQuery.sizeOf(context).width >= 980 ? 32 : 8,
    vertical: 10,
  ),
 decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: borderColor)),), child: Row(children: [
    Container(width: 39, height: 39, decoration: BoxDecoration(gradient: const LinearGradient(colors: [brand, brandDark]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.school_rounded, color: Colors.white, size: 21)),
    const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('StudyFlow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: ink, letterSpacing: -.4)), Text('STUDENT WORKSPACE', style: TextStyle(fontSize: 8, color: secondaryInk, letterSpacing: 1.25, fontWeight: FontWeight.w700))]),
    const Spacer(),
    if (searchOpen && MediaQuery.sizeOf(context).width > 550) SizedBox(width: 220, child: TextField(onChanged: onQuery, decoration: const InputDecoration(hintText: 'Search tasks…', prefixIcon: Icon(Icons.search_rounded, size: 18), isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 9)))),
    IconButton(onPressed: onSearchToggle, tooltip: 'Search tasks', icon: const Icon(Icons.search_rounded, color: secondaryInk)),
    IconButton(onPressed: onReminders, tooltip: 'Reminders', icon: const Icon(Icons.notifications_none_rounded, color: secondaryInk)),
    const SizedBox(width: 4), if (MediaQuery.sizeOf(context).width >= 980) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New task'), style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))) else IconButton.filled(onPressed: onAdd, tooltip: 'New task', style: IconButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white), icon: const Icon(Icons.add_rounded)),
    const SizedBox(width: 4), PopupMenuButton<String>(tooltip: userEmail, onSelected: (value) { if (value == 'logout') onLogout(); }, itemBuilder: (context) => [PopupMenuItem<String>(enabled: false, value: 'email', child: SizedBox(width: 190, child: Text(userEmail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))), const PopupMenuDivider(), const PopupMenuItem<String>(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: Color(0xFFD94D5C)), SizedBox(width: 10), Text('Log out')]))], child: CircleAvatar(radius: 17, backgroundColor: const Color(0xFFECE9FF), child: Text(userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'S', style: const TextStyle(color: brand, fontWeight: FontWeight.w800, fontSize: 11)))),
  ]));
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$greeting, ${FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? 'Student'} 👋', style: TextStyle(fontSize: MediaQuery.sizeOf(context).width < 500 ? 23 : 29, fontWeight: FontWeight.w900, color: ink, letterSpacing: -.8)), const SizedBox(height: 7), const Text('Your study goals, organized in one place.', style: TextStyle(color: secondaryInk, fontSize: 13))])), if (MediaQuery.sizeOf(context).width >= 980) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add new task'), style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))]);
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(19), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor), boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 18, offset: Offset(0, 6))]), child: child);
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.caption, required this.icon, required this.tint, required this.iconColor});
  final String title, value, caption;
  final IconData icon;
  final Color tint, iconColor;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(title, style: const TextStyle(color: secondaryInk, fontSize: 12, fontWeight: FontWeight.w600))), Container(width: 36, height: 36, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 19))]), const SizedBox(height: 12), Text(value, style: const TextStyle(color: ink, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.8)), const SizedBox(height: 4), Text(caption, style: const TextStyle(color: secondaryInk, fontSize: 10))]));
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.count});
  final String label;
  final bool selected;
  final int? count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9), decoration: BoxDecoration(color: selected ? const Color(0xFFECE9FF) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? const Color(0xFFD9D3FF) : borderColor)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label, style: TextStyle(color: selected ? brand : secondaryInk, fontSize: 11, fontWeight: FontWeight.w800)), if (count != null) ...[const SizedBox(width: 6), Text('$count', style: TextStyle(color: selected ? brand : secondaryInk, fontSize: 10))]])));
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onToggle, required this.onEdit, required this.onDelete});
  final StudyTask task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit, onDelete;
  Color get priorityColor => switch (task.priority) { Priority.high => const Color(0xFFD94D5C), Priority.medium => const Color(0xFFC88717), Priority.low => const Color(0xFF1A9A6B) };
  @override
  Widget build(BuildContext context) {
    final dueColor = task.isOverdue ? const Color(0xFFD94D5C) : secondaryInk;
    return Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: task.isDone ? const Color(0xFFFCFCFE) : Colors.white, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(15)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Checkbox(value: task.isDone, onChanged: (v) => onToggle(v ?? false), activeColor: brand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)), visualDensity: VisualDensity.compact),
      const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(task.title, style: TextStyle(color: task.isDone ? secondaryInk : ink, fontWeight: FontWeight.w800, fontSize: 13, decoration: task.isDone ? TextDecoration.lineThrough : null)),
        const SizedBox(height: 4), Text(task.subject, style: const TextStyle(color: secondaryInk, fontSize: 11)),
        if (task.notes.isNotEmpty) ...[const SizedBox(height: 5), Text(task.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: secondaryInk, fontSize: 11, height: 1.35))],
        const SizedBox(height: 9), Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.schedule_rounded, size: 13, color: dueColor), const SizedBox(width: 4), Text('${_dateLabel(task.dueDate)} · ${_timeLabel(task.dueDate)}${task.isOverdue ? ' · Overdue' : ''}', style: TextStyle(color: dueColor, fontSize: 10, fontWeight: task.isOverdue ? FontWeight.w800 : FontWeight.w500))]), Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: priorityColor.withOpacity(.10), borderRadius: BorderRadius.circular(6)), child: Text(task.priority.name.toUpperCase(), style: TextStyle(color: priorityColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .3)))]),
      ])),
      PopupMenuButton<String>(tooltip: 'Task options', icon: const Icon(Icons.more_horiz_rounded, color: secondaryInk), onSelected: (v) { if (v == 'edit') onEdit(); if (v == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Edit task')])), PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFD94D5C)), SizedBox(width: 10), Text('Delete task')]))]),
    ]));
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12), child: Column(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFECE9FF), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.checklist_rounded, color: brand, size: 28)), const SizedBox(height: 14), const Text('Nothing on this list', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)), const SizedBox(height: 6), const Text('Try another filter or create a new task.', style: TextStyle(color: secondaryInk, fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 14), OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Create task'))]));
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(width: 224, color: Colors.white, padding: const EdgeInsets.fromLTRB(16, 27, 16, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(left: 12, bottom: 18), child: Text('WORKSPACE', style: TextStyle(color: secondaryInk, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800))), _SideItem(icon: Icons.dashboard_rounded, label: 'Dashboard', active: selected == 0, onTap: () => onSelect(0)), _SideItem(icon: Icons.checklist_rounded, label: 'My tasks', active: selected == 1, onTap: () => onSelect(1)), _SideItem(icon: Icons.calendar_month_rounded, label: 'Calendar', active: selected == 2, onTap: () => onSelect(2)), _SideItem(icon: Icons.insights_rounded, label: 'Insights', active: selected == 3, onTap: () => onSelect(3)), const Spacer(), Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF3F1FF), borderRadius: BorderRadius.circular(15)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.tips_and_updates_outlined, color: brand), SizedBox(height: 10), Text('Build your routine', style: TextStyle(color: ink, fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Small daily actions lead to meaningful progress.', style: TextStyle(color: secondaryInk, fontSize: 11, height: 1.4))]))]));
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 6), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), decoration: BoxDecoration(color: active ? const Color(0xFFECE9FF) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, size: 19, color: active ? brand : secondaryInk), const SizedBox(width: 12), Text(label, style: TextStyle(color: active ? brand : secondaryInk, fontSize: 13, fontWeight: FontWeight.w700))]))));
}

class _MobileNav extends StatelessWidget {
  const _MobileNav({required this.selected, required this.onSelect});
  final int selected; final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Container(decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: borderColor))), padding: const EdgeInsets.symmetric(vertical: 7), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [ _MobileItem(icon: Icons.dashboard_rounded, label: 'Home', active: selected == 0, onTap: () => onSelect(0)), _MobileItem(icon: Icons.checklist_rounded, label: 'Tasks', active: selected == 1, onTap: () => onSelect(1)), _MobileItem(icon: Icons.calendar_month_rounded, label: 'Calendar', active: selected == 2, onTap: () => onSelect(2)), _MobileItem(icon: Icons.insights_rounded, label: 'Insights', active: selected == 3, onTap: () => onSelect(3))]));
}
class _MobileItem extends StatelessWidget {
  const _MobileItem({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? brand : secondaryInk, size: 20), const SizedBox(height: 3), Text(label, style: TextStyle(color: active ? brand : secondaryInk, fontSize: 10, fontWeight: FontWeight.w700))])));
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage({required this.tasks, required this.onToggle, required this.onEdit});

  final List<StudyTask> tasks;
  final Future<void> Function(StudyTask, bool) onToggle;
  final ValueChanged<StudyTask> onEdit;

  @override
  Widget build(BuildContext context) {
    final upcoming = tasks.where((task) => !task.isDone).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule',
                style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your upcoming deadlines, in chronological order.',
                style: TextStyle(color: secondaryInk),
              ),
              const SizedBox(height: 22),
              _Panel(
                child: upcoming.isEmpty
                    ? const _EmptySchedule()
                    : Column(
                        children: upcoming.map((task) {
                          return InkWell(
                            onTap: () => onEdit(task),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECE9FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '${task.dueDate.day}',
                                          style: const TextStyle(
                                            color: brand,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 19,
                                          ),
                                        ),
                                        Text(
                                          ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][task.dueDate.month - 1],
                                          style: const TextStyle(
                                            color: brand,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${task.subject} · ${_timeLabel(task.dueDate)}',
                                          style: const TextStyle(color: secondaryInk, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    task.priority.name,
                                    style: TextStyle(
                                      color: task.priority == Priority.high
                                          ? const Color(0xFFD94D5C)
                                          : task.priority == Priority.medium
                                              ? const Color(0xFFC88717)
                                              : const Color(0xFF1A9A6B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Checkbox(
                                    value: task.isDone,
                                    onChanged: (value) => onToggle(task, value ?? false),
                                    activeColor: brand,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _EmptySchedule extends StatelessWidget { const _EmptySchedule(); @override Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(25), child: Center(child: Text('No upcoming tasks. You are all caught up!', style: TextStyle(color: secondaryInk)))); }

class _InsightsPage extends StatelessWidget {
  const _InsightsPage({required this.tasks});
  final List<StudyTask> tasks;
  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    final pending = tasks.length - done;
    final high = tasks.where((t) => t.priority == Priority.high && !t.isDone).length;
    final overdue = tasks.where((t) => t.isOverdue).length;
    final subjects = <String, int>{};
    for (final task in tasks.where((t) => t.isDone)) { subjects[task.subject] = (subjects[task.subject] ?? 0) + 1; }
    final sortedSubjects = subjects.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Insights', style: TextStyle(color: ink, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 7), const Text('A snapshot of your task workload and progress.', style: TextStyle(color: secondaryInk)), const SizedBox(height: 22), LayoutBuilder(builder: (context, c) { final columns = c.maxWidth > 600 ? 4 : 2; final width = (c.maxWidth - (columns - 1) * 12) / columns; return Wrap(spacing: 12, runSpacing: 12, children: [SizedBox(width: width, child: _MetricCard(title: 'Completed', value: '$done', caption: 'Finished tasks', icon: Icons.task_alt_rounded, tint: const Color(0xFFE2F7ED), iconColor: const Color(0xFF1A9A6B))), SizedBox(width: width, child: _MetricCard(title: 'Pending', value: '$pending', caption: 'Open tasks', icon: Icons.hourglass_bottom_rounded, tint: const Color(0xFFFFF2DC), iconColor: const Color(0xFFC88717))), SizedBox(width: width, child: _MetricCard(title: 'High priority', value: '$high', caption: 'Needs attention', icon: Icons.flag_rounded, tint: const Color(0xFFFFE7EA), iconColor: const Color(0xFFD94D5C))), SizedBox(width: width, child: _MetricCard(title: 'Overdue', value: '$overdue', caption: 'Past deadline', icon: Icons.alarm_rounded, tint: const Color(0xFFFFE7EA), iconColor: const Color(0xFFD94D5C)))]); }), const SizedBox(height: 18), _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Completion rate', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text('${(progress * 100).round()}% of all tasks are complete', style: const TextStyle(color: secondaryInk, fontSize: 12)), const SizedBox(height: 16), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: const Color(0xFFECECF4), color: brand)), const SizedBox(height: 8), Text('$done completed · $pending remaining', style: const TextStyle(color: secondaryInk, fontSize: 11))])), const SizedBox(height: 18), _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Completed tasks by subject', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('Based on your saved task list; no external analytics.', style: TextStyle(color: secondaryInk, fontSize: 12)), const SizedBox(height: 15), if (sortedSubjects.isEmpty) const Text('Complete a task to start building your subject breakdown.', style: TextStyle(color: secondaryInk, fontSize: 12)) else ...sortedSubjects.map((entry) { final maxValue = sortedSubjects.first.value; return Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(children: [Row(children: [Expanded(child: Text(entry.key, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700))), Text('${entry.value}', style: const TextStyle(color: secondaryInk, fontSize: 12))]), const SizedBox(height: 7), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: entry.value / maxValue, minHeight: 7, backgroundColor: const Color(0xFFECECF4), color: brand))])); })]))]))));
  }
}
