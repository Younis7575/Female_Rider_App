import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_envelope.dart';
import '../../../core/network/json.dart';
import '../../../core/realtime/live_sync.dart';
import '../../../core/realtime/realtime_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../../trips/data/trip_repository.dart';
import '../../trips/domain/trip_models.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';

/// Private chat between the trip's customer and driver.
///
/// Available from the moment an offer is accepted (trip assigned) until the trip
/// ends; afterwards the conversation stays readable but closed.
class TripChatScreen extends ConsumerStatefulWidget {
  const TripChatScreen({super.key, required this.tripId});
  final String tripId;

  static const customerQuickReplies = ['I\'m at the pickup point', 'I\'ll be there in 2 minutes', 'Where are you?', 'Okay, thank you'];
  static const driverQuickReplies = ['I\'m on my way', 'I\'ve arrived', 'Stuck in traffic, 5 more minutes', 'Where exactly are you?', 'Okay'];

  @override
  ConsumerState<TripChatScreen> createState() => _TripChatScreenState();
}

class _TripChatScreenState extends ConsumerState<TripChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _rand = Random();
  LiveSync? _sync;
  Trip? _trip;
  String? _viewerRole;
  bool _canSend = false;
  int _maxLength = 500;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  Object? _error;
  Timer? _readDebounce;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    OpenChat.tripId = widget.tripId;
    _sync = LiveSync(
      service: ref.read(realtimeServiceProvider),
      channels: [RealtimeService.tripChannel(widget.tripId)],
      onEvent: _onEvent,
      refresh: _load,
      pollInterval: const Duration(seconds: 6),
    )..start();
    _input.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    if (OpenChat.tripId == widget.tripId) OpenChat.tripId = null;
    _readDebounce?.cancel();
    _sync?.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repo.thread(widget.tripId),
        if (_trip == null) ref.read(tripRepositoryProvider).trip(widget.tripId),
      ]);
      if (!mounted) return;
      final thread = results[0] as ChatThread;
      setState(() {
        if (results.length > 1) _trip = results[1] as Trip;
        _viewerRole = thread.viewerRole;
        _canSend = thread.canSend;
        _maxLength = thread.maxLength;
        _messages = _merge(thread.messages);
        _loading = false;
        _error = null;
      });
      _markReadSoon();
      _scrollToEnd();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_messages.isEmpty) _error = e;
        });
      }
    }
  }

  /// Server list plus local messages that are still sending / failed.
  List<ChatMessage> _merge(List<ChatMessage> server) {
    final serverClientIds = server.map((m) => m.clientId).whereType<String>().toSet();
    final locals = _messages.where((m) => (m.pending || m.failed) && !serverClientIds.contains(m.clientId));
    return [...server, ...locals];
  }

  void _onEvent(RealtimeEvent e) {
    switch (e.event) {
      case 'trip.message':
        final msg = ChatMessage.fromJson(asMap(e.data['message']));
        if (msg.id.isEmpty) return;
        setState(() {
          final i = _messages.indexWhere((m) => m.id == msg.id || (msg.clientId != null && m.clientId == msg.clientId && m.senderRole == msg.senderRole));
          if (i >= 0) {
            _messages[i] = msg;
          } else {
            _messages = [..._messages, msg];
          }
        });
        if (!msg.isMine(_viewerRole)) _markReadSoon();
        _scrollToEnd();
      case 'trip.messages_read':
        if (asString(e.data['reader_role']) == _viewerRole) return;
        final at = asDate(e.data['read_at']) ?? DateTime.now();
        setState(() => _messages = [for (final m in _messages) m.isMine(_viewerRole) && m.readAt == null && !m.pending ? m.copyWith(readAt: at) : m]);
      case RtEvents.tripUpdated:
        _load();
    }
  }

  void _markReadSoon() {
    final hasUnread = _messages.any((m) => !m.isMine(_viewerRole) && m.readAt == null);
    if (!hasUnread) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        await _repo.markRead(widget.tripId);
        if (!mounted) return;
        final now = DateTime.now();
        setState(() => _messages = [for (final m in _messages) !m.isMine(_viewerRole) && m.readAt == null ? m.copyWith(readAt: now) : m]);
      } catch (_) {}
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  String _newClientId() => '${DateTime.now().microsecondsSinceEpoch}-${_rand.nextInt(1 << 32)}';

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || !_canSend || _viewerRole == null) return;
    final local = ChatMessage(
      id: 'local-${_newClientId()}',
      seq: 0,
      senderRole: _viewerRole!,
      body: text,
      clientId: _newClientId(),
      createdAt: DateTime.now(),
      pending: true,
    );
    if (preset == null) _input.clear();
    setState(() => _messages = [..._messages, local]);
    _scrollToEnd();
    await _deliver(local);
  }

  Future<void> _deliver(ChatMessage local) async {
    try {
      final sent = await _repo.send(widget.tripId, local.body, clientId: local.clientId!);
      if (!mounted) return;
      setState(() {
        // The realtime echo may already have inserted the server copy.
        final withoutDupes = _messages.where((m) => m.id != sent.id).toList();
        final i = withoutDupes.indexWhere((m) => m.clientId == local.clientId);
        if (i >= 0) {
          withoutDupes[i] = sent;
        } else {
          withoutDupes.add(sent);
        }
        _messages = withoutDupes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages = [for (final m in _messages) m.clientId == local.clientId ? m.copyWith(pending: false, failed: true) : m]);
      if (e is ApiException && e.code == 'chat_closed') {
        setState(() => _canSend = false);
      }
      showErrorSnack(context, e);
    }
  }

  void _retry(ChatMessage m) {
    setState(() => _messages = [for (final x in _messages) x.clientId == m.clientId ? x.copyWith(failed: false, pending: true) : x]);
    _deliver(m);
  }

  TripPerson? get _other => _trip == null ? null : (_viewerRole == 'driver' ? _trip!.customer : _trip!.driver);

  @override
  Widget build(BuildContext context) {
    final other = _other;
    final driverView = _viewerRole == 'driver';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          AppAvatar(url: other?.photoUrl, name: other?.firstName, size: 38, dark: !driverView && other != null),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(other?.firstName ?? 'Chat', style: AppText.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                _canSend ? (driverView ? 'Your rider' : 'Your driver${_trip?.vehicle?.plateNumber != null ? ' · ${_trip!.vehicle!.plateNumber}' : ''}') : 'Chat closed',
                style: AppText.caption,
              ),
            ]),
          ),
        ]),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: 'Chat unavailable', message: errorMessage(_error!), actionLabel: 'Try again', onAction: _load)
              : Column(children: [
                  Expanded(child: _messageList()),
                  if (_canSend) _composer(driverView) else _closedBar(),
                ]),
    );
  }

  Widget _messageList() {
    final tip = Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: InfoBanner(
        tone: StatusTone.neutral,
        icon: Icons.lock_outline_rounded,
        message: 'Only you and your ${_viewerRole == 'driver' ? 'rider' : 'driver'} can see this chat. For your safety, keep conversations in the app and avoid sharing personal numbers.',
      ),
    );
    if (_messages.isEmpty) {
      return ListView(padding: const EdgeInsets.all(AppSpace.md), children: [
        tip,
        const SizedBox(height: AppSpace.xl),
        Icon(Icons.forum_outlined, size: 48, color: AppColors.subtle),
        const SizedBox(height: AppSpace.sm),
        Text(_canSend ? 'Say hello or use a quick reply below.' : 'No messages in this trip.', style: AppText.bodySm, textAlign: TextAlign.center),
      ]);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.sm),
      itemCount: _messages.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) return tip;
        final m = _messages[i - 1];
        final prev = i > 1 ? _messages[i - 2] : null;
        final grouped = prev != null && prev.senderRole == m.senderRole;
        return _Bubble(
          message: m,
          mine: m.isMine(_viewerRole),
          showMeta: true,
          topGap: grouped ? 3 : 10,
          onRetry: m.failed ? () => _retry(m) : null,
        );
      },
    );
  }

  Widget _composer(bool driverView) {
    final replies = driverView ? TripChatScreen.driverQuickReplies : TripChatScreen.customerQuickReplies;
    final canSubmit = _input.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.sm, 0),
              itemCount: replies.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.xs),
              itemBuilder: (_, i) => ActionChip(
                label: Text(replies[i], style: AppText.label),
                backgroundColor: AppColors.field,
                side: const BorderSide(color: AppColors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
                onPressed: () => _send(replies[i]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.xs, AppSpace.xs, AppSpace.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: _maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  // Roman Urdu is common; system autocorrect mangles it ("pohanch" → "pohang").
                  autocorrect: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.field,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.rose)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.xs),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: canSubmit ? () => _send() : null,
                style: IconButton.styleFrom(backgroundColor: AppColors.crimson, disabledBackgroundColor: AppColors.line, minimumSize: const Size(46, 46)),
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _closedBar() => Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
        padding: const EdgeInsets.all(AppSpace.md),
        child: SafeArea(
          top: false,
          child: Row(children: [
            const Icon(Icons.lock_clock_outlined, color: AppColors.muted, size: 20),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text('Chat is closed because this trip has ended. Need help? Contact support from the trip details.', style: AppText.bodySm)),
          ]),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, required this.showMeta, required this.topGap, this.onRetry});
  final ChatMessage message;
  final bool mine;
  final bool showMeta;
  final double topGap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final status = m.failed
        ? 'Not sent · tap to retry'
        : m.pending
            ? 'Sending…'
            : mine && m.readAt != null
                ? 'Seen'
                : '';
    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: onRetry,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW > 520 ? 520 : maxW),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? (m.failed ? AppColors.dangerSoft : AppColors.crimson) : AppColors.surface,
                border: mine ? null : Border.all(color: AppColors.line),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 18),
                ),
              ),
              child: Text(m.body, style: AppText.body.copyWith(color: mine && !m.failed ? Colors.white : AppColors.ink)),
            ),
          ),
        ),
        if (showMeta)
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Text(
              [formatTime(m.createdAt), if (status.isNotEmpty) status].join(' · '),
              style: AppText.caption.copyWith(fontSize: 11, color: m.failed ? AppColors.danger : AppColors.subtle),
            ),
          ),
      ]),
    );
  }
}
