import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _bg = Color(0xFF0B0E14);
const _panel = Color(0xFF121722);
const _panelSoft = Color(0xFF171D2A);
const _border = Color(0xFF293246);
const _accent = Color(0xFF8B7CFF);
const _muted = Color(0xFF8D98AD);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _BundledBackend.start();
  runApp(const MdkAgentApp());
}

class _BundledBackend {
  static Future<void> start() async {
    if (!Platform.isWindows) return;
    final appDirectory = File(Platform.resolvedExecutable).parent.path;
    final backendPath = '$appDirectory\\backend\\mdk-agent-api.exe';
    if (!File(backendPath).existsSync()) return;
    try {
      await Process.start(backendPath, const [], workingDirectory: appDirectory);
    } catch (_) {
      // The backend may already be running; the UI will show connection status.
    }
  }
}

class MdkAgentApp extends StatelessWidget {
  const MdkAgentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MDK Agent',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
          surface: _panel,
        ),
        fontFamily: 'Segoe UI',
        useMaterial3: true,
      ),
      home: const AgentHomePage(),
    );
  }
}

class AgentEvent {
  final String kind;
  final String title;
  final String detail;
  final String status;

  const AgentEvent({
    required this.kind,
    required this.title,
    required this.detail,
    required this.status,
  });

  factory AgentEvent.fromJson(Map<String, dynamic> json) => AgentEvent(
        kind: json['kind'] ?? 'info',
        title: json['title'] ?? 'Agent update',
        detail: json['detail'] ?? '',
        status: json['status'] ?? 'done',
      );
}

class AgentRun {
  final String answer;
  final String status;
  final List<AgentEvent> events;
  final String? approvalId;
  final Map<String, dynamic>? pendingAction;

  const AgentRun({
    required this.answer,
    required this.status,
    required this.events,
    this.approvalId,
    this.pendingAction,
  });

  factory AgentRun.fromJson(Map<String, dynamic> json) => AgentRun(
        answer: json['answer'] ?? 'No response received.',
        status: json['status'] ?? 'completed',
        approvalId: json['approval_id'],
        pendingAction: json['pending_action'] is Map
            ? Map<String, dynamic>.from(json['pending_action'])
            : null,
        events: ((json['events'] as List?) ?? [])
            .map((e) => AgentEvent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AgentApi {
  // Run the backend on the same Windows machine. Override with:
  // flutter run -d windows --dart-define=AGENT_API_BASE_URL=http://127.0.0.1:8000
  static const baseUrl = String.fromEnvironment(
    'AGENT_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  Future<AgentRun> run(String message) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/agent/run'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'message': message, 'session_id': 'desktop-default'}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Agent server returned ${response.statusCode}');
    }
    return AgentRun.fromJson(jsonDecode(response.body));
  }

  Future<AgentRun> approve(String approvalId, bool approved) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/agent/approve'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'approval_id': approvalId, 'approved': approved}),
    );
    if (response.statusCode >= 400) {
      throw Exception('Approval request returned ${response.statusCode}');
    }
    return AgentRun.fromJson(jsonDecode(response.body));
  }
}

class ChatItem {
  final bool fromUser;
  final String text;
  const ChatItem({required this.fromUser, required this.text});
}

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  final _input = TextEditingController();
  final _api = AgentApi();
  final List<ChatItem> _messages = const [
    ChatItem(
      fromUser: false,
      text: 'Welcome to MDK Agent. Give me a goal and I will plan the work, show progress, and ask before risky actions.',
    ),
  ].toList();
  List<AgentEvent> _events = const [
    AgentEvent(
      kind: 'ready',
      title: 'Agent ready',
      detail: 'Secure backend connection is waiting for a task.',
      status: 'ready',
    ),
  ];
  bool _running = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _running) return;
    setState(() {
      _messages.add(ChatItem(fromUser: true, text: text));
      _input.clear();
      _running = true;
      _events = [
        const AgentEvent(
          kind: 'plan',
          title: 'Planning task',
          detail: 'The agent is deciding the safest next steps.',
          status: 'running',
        ),
      ];
    });
    try {
      final run = await _api.run(text);
      if (!mounted) return;
      final needsApproval = run.status == 'awaiting_approval' && run.approvalId != null;
      setState(() {
        _messages.add(ChatItem(fromUser: false, text: run.answer));
        _events = run.events;
        _running = needsApproval;
      });
      if (needsApproval) {
        await _handleApproval(run);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _events = [
          AgentEvent(
            kind: 'error',
            title: 'Backend unavailable',
            detail: 'Start the FastAPI service, then try again. $error',
            status: 'error',
          ),
        ];
        _messages.add(const ChatItem(
          fromUser: false,
          text: 'I could not reach the local agent backend. Please start the FastAPI service and try again.',
        ));
        _running = false;
      });
    }
  }

  Future<void> _handleApproval(AgentRun run) async {
    final action = run.pendingAction;
    final tool = action?['tool'] ?? 'requested action';
    final arguments = action?['arguments']?.toString() ?? '';
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.shield_outlined, color: Color(0xFFFFC56B)),
          SizedBox(width: 10),
          Text('Approval required'),
        ]),
        content: SizedBox(
          width: 520,
          child: Text(
            'The agent wants to run $tool.\n\n$arguments\n\nApprove only if you understand this action. Secrets are not shown in this card.',
            style: const TextStyle(height: 1.45),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Deny')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (!mounted || run.approvalId == null) return;
    setState(() => _running = true);
    try {
      final result = await _api.approve(run.approvalId!, approved == true);
      if (!mounted) return;
      setState(() {
        _messages.add(ChatItem(fromUser: false, text: result.answer));
        _events = result.events;
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _events = [AgentEvent(kind: 'error', title: 'Approval failed', detail: '$error', status: 'error')];
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSidebar = constraints.maxWidth >= 900;
            final showActivity = constraints.maxWidth >= 1180;
            return Row(
              children: [
                if (showSidebar)
                  _Sidebar(onNewTask: () => setState(() => _messages
                    ..clear()
                    ..add(const ChatItem(
                      fromUser: false,
                      text: 'New task ready. What should I work on?',
                    )))),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(running: _running),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: _ChatPanel(
                              messages: _messages,
                              controller: _input,
                              running: _running,
                              onSend: _send,
                            )),
                            if (showActivity) _ActivityPanel(events: _events),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final VoidCallback onNewTask;
  const _Sidebar({required this.onNewTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: Color(0xFF0E121B),
        border: Border(right: BorderSide(color: _border)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [_accent, Color(0xFF59C2FF)]),
              ),
              child: const Icon(Icons.auto_awesome, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('MDK Agent', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 25),
          FilledButton.icon(
            onPressed: onNewTask,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New task'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 28),
          const Text('WORKSPACE', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _SideItem(icon: Icons.chat_bubble_outline, label: 'Agent chat', selected: true),
          _SideItem(icon: Icons.folder_outlined, label: 'Artifacts'),
          _SideItem(icon: Icons.account_tree_outlined, label: 'Git projects'),
          const Spacer(),
          const Divider(color: _border),
          _SideItem(icon: Icons.settings_outlined, label: 'Settings'),
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF50D890), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Local agent backend',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _SideItem({required this.icon, required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: selected ? _panelSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(icon, size: 18, color: selected ? Colors.white : _muted),
          title: Text(label, style: TextStyle(color: selected ? Colors.white : _muted, fontSize: 13)),
          onTap: () {},
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool running;
  const _TopBar({required this.running});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
      child: Row(children: [
        const Text('Agent Mode', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(color: _panelSoft, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
          child: const Row(children: [Icon(Icons.memory, size: 14, color: _accent), SizedBox(width: 6), Text('Kilo-ready backend', style: TextStyle(fontSize: 11, color: _muted))]),
        ),
        const Spacer(),
        if (running) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        if (running) const SizedBox(width: 10),
        IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline, color: _muted)),
        IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz, color: _muted)),
      ]),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final List<ChatItem> messages;
  final TextEditingController controller;
  final bool running;
  final VoidCallback onSend;
  const _ChatPanel({required this.messages, required this.controller, required this.running, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(38, 28, 38, 20),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final item = messages[index];
            return Align(
              alignment: item.fromUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 720),
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: item.fromUser ? const Color(0xFF28234B) : _panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.fromUser ? const Color(0xFF51488C) : _border),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(item.fromUser ? Icons.person_outline : Icons.auto_awesome, size: 18, color: item.fromUser ? const Color(0xFFC8C0FF) : _accent),
                  const SizedBox(width: 11),
                  Expanded(child: Text(item.text, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFFE8EBF4)))),
                ]),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(30, 0, 30, 24),
        child: Container(
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Column(children: [
            TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Tell the agent what you want to accomplish...', border: InputBorder.none, hintStyle: TextStyle(color: _muted)),
            ),
            Row(children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.attach_file, size: 19, color: _muted)),
              const Text('Files and images supported', style: TextStyle(color: _muted, fontSize: 11)),
              const Spacer(),
              IconButton(onPressed: running ? null : onSend, icon: Icon(Icons.arrow_upward_rounded, color: running ? _muted : Colors.white), style: IconButton.styleFrom(backgroundColor: running ? _panelSoft : _accent)),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

class _ActivityPanel extends StatelessWidget {
  final List<AgentEvent> events;
  const _ActivityPanel({required this.events});

  IconData _icon(String kind) {
    switch (kind) {
      case 'plan': return Icons.route_outlined;
      case 'tool': return Icons.build_outlined;
      case 'verify': return Icons.verified_outlined;
      case 'error': return Icons.error_outline;
      case 'complete': return Icons.check_circle_outline;
      default: return Icons.circle_outlined;
    }
  }

  Color _color(String status) {
    if (status == 'error') return const Color(0xFFFF7272);
    if (status == 'running') return const Color(0xFFFFC56B);
    if (status == 'done' || status == 'ready') return const Color(0xFF65D99A);
    return _accent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      decoration: const BoxDecoration(color: Color(0xFF0E121B), border: Border(left: BorderSide(color: _border))),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Live workflow', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 5),
        const Text('What the agent is doing', style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 24),
        Expanded(
          child: ListView.separated(
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 17),
            itemBuilder: (context, index) {
              final event = events[index];
              final color = _color(event.status);
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_icon(event.kind), size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(event.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(event.detail, style: const TextStyle(fontSize: 11, color: _muted, height: 1.35)),
                ])),
              ]);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.shield_outlined, size: 17, color: Color(0xFF65D99A)),
            SizedBox(width: 8),
            Expanded(child: Text('Secrets stay in the backend environment. The model receives references, not raw keys.', style: TextStyle(fontSize: 11, color: _muted, height: 1.35))),
          ]),
        ),
      ]),
    );
  }
}
