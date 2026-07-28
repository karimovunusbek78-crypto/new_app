import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_app/src/pages/home/notification/notification_sender.dart';
import 'package:provider/provider.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

import 'package:new_app/src/pages/home/providers/subscribtion_provider.dart';
import 'package:new_app/src/video/video%20page/profile/user_stats_page.dart';

class _ReplyTarget {
  final String commentId;
  final String authorUid; // кому отправить уведомление об ответе
  final String authorName;
  const _ReplyTarget(this.commentId, this.authorUid, this.authorName);
}

class _CommentData {
  final String id;
  final String uid; // uid автора — нужен для бейджа "Автор" и прав
  final String authorName;
  String text; // не final — редактируется владельцем комментария
  String? avatarUrl;
  int replyCount; // количество ответов — учитывается в общем счётчике
  bool pinned; // владелец объявления может закрепить комментарий сверху
  final DateTime? createdAt;

  _CommentData({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.text,
    this.avatarUrl,
    this.replyCount = 0,
    this.pinned = false,
    this.createdAt,
  });

  factory _CommentData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['createdAt'];
    return _CommentData(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Пользователь',
      text: (data['text'] as String?) ?? '',
      avatarUrl: data['authorAvatarUrl'] as String?,
      pinned: (data['pinned'] as bool?) ?? false,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

final Map<String, String> _profileAvatarCache = {};

Future<void> _hydrateAvatars(List<_CommentData> items) async {
  final uids = items.map((c) => c.uid).where((u) => u.isNotEmpty).toSet();
  final uncached = uids.where((u) => !_profileAvatarCache.containsKey(u)).toList();
  if (uncached.isNotEmpty) {
    try {
      for (var i = 0; i < uncached.length; i += 30) {
        final chunk = uncached.sublist(
            i, i + 30 > uncached.length ? uncached.length : i + 30);
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          _profileAvatarCache[doc.id] = (doc.data()['avatarUrl'] as String?) ?? '';
        }
        for (final u in chunk) {
          _profileAvatarCache.putIfAbsent(u, () => '');
        }
      }
    } catch (_) {}
  }
  for (final c in items) {
    final url = _profileAvatarCache[c.uid];
    if (url != null && url.isNotEmpty) c.avatarUrl = url;
  }
}

Future<String?> _fetchMyAvatarUrl(String uid) async {
  if (_profileAvatarCache.containsKey(uid)) {
    final cached = _profileAvatarCache[uid];
    return (cached != null && cached.isNotEmpty) ? cached : null;
  }
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final url = (doc.data()?['avatarUrl'] as String?) ?? '';
    _profileAvatarCache[uid] = url;
    return url.isNotEmpty ? url : null;
  } catch (_) {
    return null;
  }
}

String _timeAgo(DateTime? dt) {
  if (dt == null) return 'только что';
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'только что';
  if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
  if (diff.inHours < 24) return '${diff.inHours} ч. назад';
  if (diff.inDays < 30) return '${diff.inDays} дн. назад';
  if (diff.inDays < 365) {
    final months = (diff.inDays / 30).floor().clamp(1, 11);
    return '$months мес. назад';
  }
  final years = (diff.inDays / 365).floor();
  return '$years г. назад';
}

class _CommentColors {
  static const bg = Color(0xFF0F0F0F);
  static const inputBg = Color(0xFF272727);
  static const divider = Color(0xFF272727);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFAAAAAA);
  static const textTertiary = Color(0xFF717171);
  static const accent = Color(0xFF4DA6FF);
  static const avatarFallback = Color(0xFF3A3A3A);
  static const menuBg = Color(0xFF282828);
}

/// Открывает маленькую центрированную карточку профиля поверх шторки
/// комментариев — по тапу на аватар/имя автора комментария или ответа.
/// В отличие от полного UserStatsPage, здесь только: аватар, имя,
/// количество подписчиков (без "канал создан N лет назад") и две кнопки:
/// «Подписаться» и «Перейти в профиль» (второе — переход в UserStatsPage,
/// а не в какой-то отдельный "канал").
void _showProfileCard(
  BuildContext context, {
  required String uid,
  required String authorName,
  String? avatarUrl,
}) {
  if (uid.isEmpty) return;
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 8.w),
        child: _ProfilePreviewCard(
          uid: uid,
          fallbackName: authorName,
          fallbackAvatarUrl: avatarUrl,
        ),
      );
    },
  );
}

/// Карточка профиля, показываемая по центру экрана поверх комментариев.
/// Слушает users/{uid} вживую, чтобы имя/аватар/подписчики были
/// актуальными, даже если в комментарии сохранены устаревшие значения.
class _ProfilePreviewCard extends StatelessWidget {
  final String uid;
  final String fallbackName;
  final String? fallbackAvatarUrl;

  const _ProfilePreviewCard({
    required this.uid,
    required this.fallbackName,
    this.fallbackAvatarUrl,
  });

  static const _cardBg = Color(0xFF1C1C1E);

  void _goToProfile(BuildContext context) {
    Navigator.of(context).pop(); // закрываем карточку
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserStatsPage(uid: uid)),
    );
  }

  static String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final isMe = myUid != null && myUid == uid;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5.w),
      child: Container(
        width: double.infinity,
        color: _cardBg,
        padding: EdgeInsets.all(5.w),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data();
            final liveName = ((data?['name'] as String?) ?? '').trim();
            final liveAvatar = ((data?['avatarUrl'] as String?) ?? '').trim();
            final subscribers = ((data?['subscribersCount'] ?? 0) as num).toInt();

            final displayName = liveName.isNotEmpty
                ? liveName
                : (fallbackName.isNotEmpty ? fallbackName : 'Пользователь');
            final displayAvatar =
                liveAvatar.isNotEmpty ? liveAvatar : (fallbackAvatarUrl ?? '');
            final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _goToProfile(context),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Container(
                        width: 15.w,
                        height: 15.w,
                        decoration: BoxDecoration(
                          color: _CommentColors.avatarFallback,
                          shape: BoxShape.circle,
                          image: displayAvatar.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(displayAvatar),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: displayAvatar.isEmpty
                            ? Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18.sp,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 3.5.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              '${_formatCount(subscribers)} подписчиков',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                                color: _CommentColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.6.h),
                if (isMe)
                  SizedBox(
                    width: double.infinity,
                    child: _GoToProfileButton(onTap: () => _goToProfile(context)),
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _SubscribeMiniButton(uid: uid)),
                      SizedBox(width: 3.w),
                      Expanded(
                        child: _GoToProfileButton(onTap: () => _goToProfile(context)),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Компактная кнопка подписки для карточки профиля (белая пилюля /
/// серая «Вы подписаны») — та же логика, что и в UserStatsPage.
class _SubscribeMiniButton extends StatelessWidget {
  final String uid;
  const _SubscribeMiniButton({required this.uid});

  @override
  Widget build(BuildContext context) {
    final subs = context.watch<SubscriptionsProvider>();
    final subscribed = subs.isSubscribed(uid);
    final pending = subs.isPending(uid);

    return GestureDetector(
      onTap: pending
          ? null
          : () => context.read<SubscriptionsProvider>().toggleSubscribe(uid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 5.6.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: subscribed ? const Color(0xFF3A3A3C) : Colors.white,
          borderRadius: BorderRadius.circular(8.w),
        ),
        child: pending
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: subscribed ? Colors.white70 : Colors.black,
                ),
              )
            : Text(
                subscribed ? 'Вы подписаны' : 'Подписаться',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: subscribed ? Colors.white : Colors.black,
                ),
              ),
      ),
    );
  }
}

/// Кнопка «Перейти в профиль» — открывает UserStatsPage автора.
class _GoToProfileButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GoToProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 5.6.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(8.w),
        ),
        child: Text(
          'Перейти в профиль',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class CommentsSheet extends StatefulWidget {
  final String carId;
  final String ownerId;
  // Название объявления — опционально, используется только чтобы
  // уведомление владельца выглядело как «Имя оставил(а) комментарий
  // к "BMW X5"» вместо безличного текста. Если не передать, просто
  // не будет упомянуто название.
  final String? carName;

  const CommentsSheet({
    super.key,
    required this.carId,
    required this.ownerId,
    this.carName,
  });

  static Future<void> show(
    BuildContext context,
    String carId,
    String ownerId, {
    String? carName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(carId: carId, ownerId: ownerId, carName: carName),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _sending = false;
  bool _loading = true;
  String? _loadError;
  _ReplyTarget? _replyingTo;
  final List<_CommentData> _comments = [];

  _CommentData? _threadComment;

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isCarOwner => _myUid != null && _myUid == widget.ownerId;

  CollectionReference<Map<String, dynamic>> get _commentsRef => FirebaseFirestore.instance
      .collection('cars')
      .doc(widget.carId)
      .collection('comments');

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _commentsRef.orderBy('createdAt', descending: true).get();
      final loaded = snap.docs.map(_CommentData.fromDoc).toList();
      await Future.wait(loaded.map((c) async {
        try {
          final agg =
              await _commentsRef.doc(c.id).collection('replies').count().get();
          c.replyCount = agg.count ?? 0;
        } catch (_) {}
      }));
      await _hydrateAvatars(loaded);
      _comments
        ..clear()
        ..addAll(loaded);
      _reorderPinned();
    } catch (e) {
      _loadError = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reorderPinned() {
    final pinned = _comments.where((c) => c.pinned).toList();
    final rest = _comments.where((c) => !c.pinned).toList();
    _comments
      ..clear()
      ..addAll(pinned)
      ..addAll(rest);
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Ответ комментарию/ответу: сразу подставляет "@Имя " в поле ввода —
  /// как в YouTube, где ответ на конкретного человека в ветке начинается
  /// с упоминания его имени. Пользователь может стереть/изменить его,
  /// это просто стартовая подстановка, а не защищённый префикс.
  void _startReply(String commentId, String authorUid, String authorName) {
    setState(() => _replyingTo = _ReplyTarget(commentId, authorUid, authorName));
    final mention = '@$authorName ';
    _controller.text = mention;
    _controller.selection = TextSelection.collapsed(offset: mention.length);
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
      _controller.clear();
    });
  }

  void _openThread(String commentId) {
    final c = _comments.where((x) => x.id == commentId).toList();
    if (c.isEmpty) return;
    setState(() => _threadComment = c.first);
  }

  void _closeThread() {
    setState(() => _threadComment = null);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;

    setState(() => _sending = true);
    final replyTo = _replyingTo;
    _controller.clear();
    try {
      final myAvatarUrl = await _fetchMyAvatarUrl(user.uid);
      final data = {
        'text': text,
        'uid': user.uid,
        'authorName': (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName
            : 'Пользователь',
        'authorAvatarUrl': myAvatarUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (replyTo != null) {
        final replyDoc = await _commentsRef
            .doc(replyTo.commentId)
            .collection('replies')
            .add({...data, 'carId': widget.carId});
        setState(() {
          _replyReloadTicks[replyTo.commentId] =
              (_replyReloadTicks[replyTo.commentId] ?? 0) + 1;
          final i = _comments.indexWhere((c) => c.id == replyTo.commentId);
          if (i != -1) _comments[i].replyCount++;
        });
        // Уведомляем автора комментария/ответа, на который отвечаем.
        // NotificationSender сам пропускает случай, когда отвечаешь
        // сам себе.
        NotificationSender.sendReply(
          toUid: replyTo.authorUid,
          carId: widget.carId,
          carName: widget.carName,
          commentId: replyDoc.id,
          text: text,
        );
      } else {
        final docRef = await _commentsRef.add({...data, 'pinned': false});
        setState(() {
          _comments.insert(
            0,
            _CommentData(
              id: docRef.id,
              uid: user.uid,
              authorName: data['authorName'] as String,
              text: text,
              avatarUrl: myAvatarUrl,
              createdAt: DateTime.now(),
            ),
          );
          _reorderPinned();
        });
        // Новый комментарий верхнего уровня — уведомляем владельца
        // объявления (если комментирует не он сам).
        NotificationSender.sendComment(
          toUid: widget.ownerId,
          carId: widget.carId,
          carName: widget.carName,
          commentId: docRef.id,
          text: text,
        );
      }
      if (mounted) setState(() => _replyingTo = null);
    } catch (e) {
      debugPrint('Comment send failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _togglePin(String commentId) async {
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i == -1) return;
    final newValue = !_comments[i].pinned;

    if (!newValue) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _CommentColors.menuBg,
          title: const Text('Открепить комментарий?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Комментарий уйдёт из верха списка.',
            style: TextStyle(color: _CommentColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Открепить'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await _commentsRef.doc(commentId).update({'pinned': newValue});
      if (!mounted) return;
      setState(() {
        _comments[i].pinned = newValue;
        _reorderPinned();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось закрепить: $e')),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _CommentColors.menuBg,
        title: const Text('Удалить комментарий?', style: TextStyle(color: Colors.white)),
        content: const Text('Это действие нельзя отменить.',
            style: TextStyle(color: _CommentColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _commentsRef.doc(commentId).delete();
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
        if (_threadComment?.id == commentId) _threadComment = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
    }
  }

  Future<void> _editComment(String commentId) async {
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i == -1) return;
    final editController = TextEditingController(text: _comments[i].text);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _CommentColors.menuBg,
        title: const Text('Редактировать комментарий', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final t = editController.text.trim();
              Navigator.pop(context, t.isEmpty ? null : t);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newText == null || newText == _comments[i].text) return;
    try {
      await _commentsRef.doc(commentId).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      setState(() => _comments[i].text = newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    }
  }

  final Map<String, int> _replyReloadTicks = {};

  int get _totalCount => _comments.fold(0, (sum, c) => sum + 1 + c.replyCount);

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        height: 75.h,
        decoration: const BoxDecoration(
          color: _CommentColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            SizedBox(height: 1.2.h),
            Container(
              width: 10.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 1.5.h),
            // Заголовок: обычный список — "Комментарии (N)"; тред-режим —
            // "Ответы" со стрелкой назад слева (см. _buildThreadHeader).
            if (_threadComment == null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  children: [
                    Text(
                      'Комментарии',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      _fmtTotal(_totalCount),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: _CommentColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(Icons.close_rounded,
                          color: _CommentColors.textSecondary, size: 22),
                    ),
                  ],
                ),
              )
            else
              _buildThreadHeader(),
            SizedBox(height: 1.h),
            const Divider(height: 1, color: _CommentColors.divider),
            Expanded(child: _buildBody()),
            const Divider(height: 1, color: _CommentColors.divider),
            if (_replyingTo != null) _replyBanner(),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: _CommentColors.accent,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Ваш ответ...'
                              : 'Введите текст комментария',
                          hintStyle: const TextStyle(color: _CommentColors.textTertiary),
                          filled: true,
                          fillColor: _CommentColors.inputBg,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.w),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    SizedBox(width: 2.w),
                    GestureDetector(
                      onTap: _sending ? null : _send,
                      child: CircleAvatar(
                        radius: 5.w,
                        backgroundColor: _CommentColors.accent,
                        child: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.arrow_upward_rounded,
                                color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Заголовок тред-режима: "← Ответы ×" — стрелка назад слева возвращает
  /// к общему списку комментариев, крестик справа закрывает всю шторку.
  Widget _buildThreadHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: _closeThread,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
            ),
          ),
          SizedBox(width: 1.w),
          Text(
            'Ответы',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTotal(int n) {
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} тыс.';
    }
    return '$n';
  }

  Widget _replyBanner() {
    return Container(
      width: double.infinity,
      color: _CommentColors.inputBg,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ответ для ${_replyingTo!.authorName}',
              style: TextStyle(fontSize: 12.sp, color: _CommentColors.textSecondary),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close_rounded, size: 18, color: _CommentColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _CommentColors.accent),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Text(
            'Ошибка загрузки комментариев:\n$_loadError',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.red.shade300),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'Пока нет комментариев.\nБудьте первым!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp, color: _CommentColors.textTertiary),
        ),
      );
    }
    if (_threadComment != null) {
      return _buildThreadView(_threadComment!);
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      physics: const BouncingScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        final isMine = _myUid != null && _myUid == c.uid;
        return _CommentTile(
          key: ValueKey(c.id),
          carId: widget.carId,
          ownerId: widget.ownerId,
          myUid: _myUid,
          commentId: c.id,
          authorUid: c.uid,
          authorName: c.authorName,
          text: c.text,
          avatarUrl: c.avatarUrl,
          pinned: c.pinned,
          createdAt: c.createdAt,
          isOwnerComment: c.uid == widget.ownerId,
          isMine: isMine,
          isCarOwner: _isCarOwner,
          onReply: _startReply,
          onPin: _isCarOwner ? _togglePin : null,
          onDelete: (isMine || _isCarOwner) ? _deleteComment : null,
          onEdit: isMine ? _editComment : null,
          reloadTick: _replyReloadTicks[c.id] ?? 0,
          replyCount: c.replyCount,
          onOpenThread: _openThread,
        );
      },
    );
  }

  /// Тред-режим: содержимое без отдельного "Назад" внутри тела — теперь
  /// вся навигация в шапке (_buildThreadHeader), тело сразу показывает
  /// комментарий + ответы.
  Widget _buildThreadView(_CommentData c) {
    final isMine = _myUid != null && _myUid == c.uid;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      physics: const BouncingScrollPhysics(),
      child: _CommentTile(
        key: ValueKey('thread_${c.id}'),
        carId: widget.carId,
        ownerId: widget.ownerId,
        myUid: _myUid,
        commentId: c.id,
        authorUid: c.uid,
        authorName: c.authorName,
        text: c.text,
        avatarUrl: c.avatarUrl,
        pinned: c.pinned,
        createdAt: c.createdAt,
        isOwnerComment: c.uid == widget.ownerId,
        isMine: isMine,
        isCarOwner: _isCarOwner,
        onReply: _startReply,
        onPin: _isCarOwner ? _togglePin : null,
        onDelete: (isMine || _isCarOwner) ? _deleteComment : null,
        onEdit: isMine ? _editComment : null,
        reloadTick: _replyReloadTicks[c.id] ?? 0,
        replyCount: c.replyCount,
        forceExpanded: true,
      ),
    );
  }
}

/// Один комментарий верхнего уровня + его ответы — YouTube-style строка:
/// аватар слева, "имя · время" сверху, текст, затем "Ответить" и, если
/// есть ответы, "N ответов ⌄" (без лайков/дизлайков/фото).
class _CommentTile extends StatefulWidget {
  final String carId;
  final String ownerId;
  final String? myUid;
  final String commentId;
  final String authorUid;
  final String authorName;
  final String text;
  final String? avatarUrl;
  final bool pinned;
  final DateTime? createdAt;
  final bool isOwnerComment;
  final bool isMine;
  final bool isCarOwner;
  final void Function(String commentId, String authorUid, String authorName) onReply;
  final Future<void> Function(String commentId)? onPin;
  final Future<void> Function(String commentId)? onDelete;
  final Future<void> Function(String commentId)? onEdit;
  final int reloadTick;
  final int replyCount;
  final void Function(String commentId)? onOpenThread;
  final bool forceExpanded;

  const _CommentTile({
    super.key,
    required this.carId,
    required this.ownerId,
    required this.myUid,
    required this.commentId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.avatarUrl,
    required this.pinned,
    required this.createdAt,
    required this.isOwnerComment,
    required this.isMine,
    required this.isCarOwner,
    required this.onReply,
    required this.onPin,
    required this.onDelete,
    required this.onEdit,
    required this.reloadTick,
    required this.replyCount,
    this.onOpenThread,
    this.forceExpanded = false,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _repliesExpanded = false;
  bool _repliesLoading = false;
  List<_CommentData> _replies = [];
  int _replyCountLocal = 0;

  @override
  void initState() {
    super.initState();
    _replyCountLocal = widget.replyCount;
    if (widget.forceExpanded) {
      _repliesExpanded = true;
      _loadReplies();
    }
  }

  CollectionReference<Map<String, dynamic>> get _repliesRef => FirebaseFirestore.instance
      .collection('cars')
      .doc(widget.carId)
      .collection('comments')
      .doc(widget.commentId)
      .collection('replies');

  Future<void> _loadReplies() async {
    setState(() => _repliesLoading = true);
    try {
      final snap = await _repliesRef.orderBy('createdAt').get();
      final loaded = snap.docs.map(_CommentData.fromDoc).toList();
      await _hydrateAvatars(loaded);
      _replies = loaded;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _repliesLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadTick != oldWidget.reloadTick) {
      _replyCountLocal = widget.replyCount;
      if (_repliesExpanded) {
        _loadReplies();
      } else {
        _replies = [];
      }
    }
  }

  void _toggleReplies() {
    if (!_repliesExpanded && _replies.isEmpty) {
      _loadReplies();
    }
    setState(() => _repliesExpanded = !_repliesExpanded);
  }

  void _handleViewRepliesTap() {
    if (widget.onOpenThread != null) {
      widget.onOpenThread!(widget.commentId);
    } else {
      _toggleReplies();
    }
  }

  /// Тап по аватару/имени автора комментария — открывает маленькую
  /// карточку профиля по центру экрана (аватар, имя, подписчики,
  /// кнопки "Подписаться" / "Перейти в профиль").
  void _openAuthorCard() {
    _showProfileCard(
      context,
      uid: widget.authorUid,
      authorName: widget.authorName,
      avatarUrl: widget.avatarUrl,
    );
  }

  Future<void> _editReply(_CommentData reply) async {
    final editController = TextEditingController(text: reply.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _CommentColors.menuBg,
        title: const Text('Редактировать ответ', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final t = editController.text.trim();
              Navigator.pop(context, t.isEmpty ? null : t);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newText == null || newText == reply.text) return;
    try {
      await _repliesRef.doc(reply.id).update({
        'text': newText,
        'editedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => reply.text = newText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    }
  }

  Future<void> _deleteReply(_CommentData reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _CommentColors.menuBg,
        title: const Text('Удалить ответ?', style: TextStyle(color: Colors.white)),
        content: const Text('Это действие нельзя отменить.',
            style: TextStyle(color: _CommentColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repliesRef.doc(reply.id).delete();
      if (mounted) {
        setState(() {
          _replies.removeWhere((r) => r.id == reply.id);
          if (_replyCountLocal > 0) _replyCountLocal--;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
    }
  }

  Widget _authorBadge() {
    return Container(
      margin: EdgeInsets.only(left: 1.5.w),
      padding: EdgeInsets.symmetric(horizontal: 1.6.w, vertical: 0.15.h),
      decoration: BoxDecoration(
        color: _CommentColors.accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: _CommentColors.accent.withOpacity(0.5)),
      ),
      child: Text(
        'Автор',
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w800,
          color: _CommentColors.accent,
        ),
      ),
    );
  }

  Widget _pinnedTag() {
    return Padding(
      padding: EdgeInsets.only(bottom: 0.4.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_rounded, size: 14, color: _CommentColors.textTertiary),
          SizedBox(width: 1.w),
          Text(
            'Закреплено',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: _CommentColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _actionsMenu() {
    final canPin = widget.onPin != null;
    final canDelete = widget.onDelete != null;
    final canEdit = widget.onEdit != null;
    if (!canPin && !canDelete && !canEdit) return null;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      color: _CommentColors.menuBg,
      icon: const Icon(Icons.more_vert_rounded, size: 18, color: _CommentColors.textSecondary),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            widget.onEdit?.call(widget.commentId);
            break;
          case 'pin':
            widget.onPin?.call(widget.commentId);
            break;
          case 'delete':
            widget.onDelete?.call(widget.commentId);
            break;
        }
      },
      itemBuilder: (context) => [
        if (canEdit)
          const PopupMenuItem(
            value: 'edit',
            child: Text('Изменить', style: TextStyle(color: Colors.white)),
          ),
        if (canPin)
          PopupMenuItem(
            value: 'pin',
            child: Text(widget.pinned ? 'Открепить' : 'Закрепить',
                style: const TextStyle(color: Colors.white)),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _styledAvatar(String name, String? avatarUrl, double size) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CommentColors.avatarFallback,
        shape: BoxShape.circle,
        image: hasAvatar
            ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
            : null,
      ),
      child: hasAvatar
          ? null
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: size * 0.4,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = _actionsMenu();
    final showRepliesBlock =
        _replyCountLocal > 0 || _repliesExpanded || widget.forceExpanded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.2.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.pinned) _pinnedTag(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Тап по аватару — открывает карточку профиля автора.
              GestureDetector(
                onTap: _openAuthorCard,
                behavior: HitTestBehavior.opaque,
                child: _styledAvatar(widget.authorName, widget.avatarUrl, 9.5.w),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Тап по имени — тоже открывает карточку профиля.
                        Flexible(
                          child: GestureDetector(
                            onTap: _openAuthorCard,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              widget.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        if (widget.isOwnerComment) _authorBadge(),
                        SizedBox(width: 1.5.w),
                        Text(
                          '· ${_timeAgo(widget.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _CommentColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      widget.text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 0.8.h),
                    GestureDetector(
                      onTap: () => widget.onReply(
                          widget.commentId, widget.authorUid, widget.authorName),
                      child: Text(
                        'Ответить',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: _CommentColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (menu != null) menu,
            ],
          ),
          if (showRepliesBlock)
            Padding(
              padding: EdgeInsets.only(left: 12.5.w, top: 0.5.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_repliesExpanded)
                    GestureDetector(
                      onTap: _handleViewRepliesTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 0.6.h),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 5.w, height: 1, color: Colors.white24),
                            SizedBox(width: 2.w),
                            Text(
                              '$_replyCountLocal ${_repliesWord(_replyCountLocal)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: _CommentColors.accent,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: _CommentColors.accent),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (_repliesLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _CommentColors.accent),
                        ),
                      )
                    else if (_replies.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 0.5.h),
                        child: Text('Пока нет ответов',
                            style: TextStyle(fontSize: 11.5.sp, color: _CommentColors.textTertiary)),
                      )
                    else
                      for (final reply in _replies) _replyItem(reply),
                    if (!widget.forceExpanded)
                      GestureDetector(
                        onTap: () => setState(() => _repliesExpanded = false),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 0.6.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 18, color: _CommentColors.textSecondary),
                              SizedBox(width: 1.w),
                              Text(
                                'Скрыть ответы',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _CommentColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _repliesWord(int n) {
    final mod100 = n % 100;
    final mod10 = n % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'ответов';
    if (mod10 == 1) return 'ответ';
    if (mod10 >= 2 && mod10 <= 4) return 'ответа';
    return 'ответов';
  }

  Widget _replyItem(_CommentData reply) {
    final isOwnerReply = reply.uid == widget.ownerId;
    final isMineReply = widget.myUid != null && widget.myUid == reply.uid;

    void openReplyAuthorCard() {
      _showProfileCard(
        context,
        uid: reply.uid,
        authorName: reply.authorName,
        avatarUrl: reply.avatarUrl,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Тап по аватару ответа — открывает карточку профиля.
          GestureDetector(
            onTap: openReplyAuthorCard,
            behavior: HitTestBehavior.opaque,
            child: _styledAvatar(reply.authorName, reply.avatarUrl, 7.5.w),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Тап по имени — тоже открывает карточку профиля.
                    Flexible(
                      child: GestureDetector(
                        onTap: openReplyAuthorCard,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          reply.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (isOwnerReply) _authorBadge(),
                    SizedBox(width: 1.5.w),
                    Text(
                      '· ${_timeAgo(reply.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _CommentColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 0.3.h),
                Text(
                  reply.text,
                  style: const TextStyle(fontSize: 13, height: 1.3, color: Colors.white),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    // Ответить конкретно на этот ответ — подставит его имя
                    // в поле ввода как "@Имя " (см. _startReply в шторке).
                    GestureDetector(
                      onTap: () =>
                          widget.onReply(widget.commentId, reply.uid, reply.authorName),
                      child: Text(
                        'Ответить',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: _CommentColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isMineReply) ...[
                      SizedBox(width: 3.w),
                      GestureDetector(
                        onTap: () => _editReply(reply),
                        child: Text(
                          'Изменить',
                          style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: _CommentColors.textSecondary),
                        ),
                      ),
                      SizedBox(width: 3.w),
                      GestureDetector(
                        onTap: () => _deleteReply(reply),
                        child: Text(
                          'Удалить',
                          style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade300),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}