import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

class _ReplyTarget {
  final String commentId;
  final String authorName;
  const _ReplyTarget(this.commentId, this.authorName);
}

class _CommentData {
  final String id;
  final String authorName;
  final String text;
  final String? avatarUrl;
  int replyCount; // количество ответов — учитывается в общем счётчике

  _CommentData({
    required this.id,
    required this.authorName,
    required this.text,
    this.avatarUrl,
    this.replyCount = 0,
  });

  factory _CommentData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _CommentData(
      id: doc.id,
      authorName: (data['authorName'] as String?) ?? 'Пользователь',
      text: (data['text'] as String?) ?? '',
      avatarUrl: data['authorAvatarUrl'] as String?,
    );
  }
}

/// Комментарии к объявлению + ответы на них.
/// Загружаются ОДИН РАЗ при открытии шторки (через .get(), а не .snapshots()),
/// дальше список обновляется локально — без постоянного "мигания" лоадера.
class CommentsSheet extends StatefulWidget {
  final String carId;
  const CommentsSheet({super.key, required this.carId});

  static Future<void> show(BuildContext context, String carId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(carId: carId),
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
      // Подтягиваем количество ответов у каждого комментария параллельно.
      // count() — агрегатный запрос: сами документы ответов НЕ читаются,
      // Firestore возвращает только число.
      await Future.wait(loaded.map((c) async {
        try {
          final agg =
              await _commentsRef.doc(c.id).collection('replies').count().get();
          c.replyCount = agg.count ?? 0;
        } catch (_) {
          // не критично — просто посчитаем этот комментарий без ответов
        }
      }));
      _comments
        ..clear()
        ..addAll(loaded);
    } catch (e) {
      _loadError = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startReply(String commentId, String authorName) {
    setState(() => _replyingTo = _ReplyTarget(commentId, authorName));
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || _sending) return;

    setState(() => _sending = true);
    final replyTo = _replyingTo;
    _controller.clear();
    try {
      final data = {
        'text': text,
        'uid': user.uid,
        'authorName': (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName
            : 'Пользователь',
        'authorAvatarUrl': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (replyTo != null) {
        // carId нужен, чтобы страница видео могла посчитать все ответы
        // одного объявления через collectionGroup('replies').
        await _commentsRef
            .doc(replyTo.commentId)
            .collection('replies')
            .add({...data, 'carId': widget.carId});
        setState(() {
          // Тик — чтобы открытая ветка перезагрузила свой список ответов.
          _replyReloadTicks[replyTo.commentId] =
              (_replyReloadTicks[replyTo.commentId] ?? 0) + 1;
          // +1 к счётчику ответов этого комментария — общий счётчик
          // в шапке ("Комментарии (N)") обновится сразу же.
          final i = _comments.indexWhere((c) => c.id == replyTo.commentId);
          if (i != -1) _comments[i].replyCount++;
        });
      } else {
        final docRef = await _commentsRef.add(data);
        // Комментарий верхнего уровня — добавляем в начало локального списка
        // без повторного похода в Firestore.
        setState(() {
          _comments.insert(
            0,
            _CommentData(
              id: docRef.id,
              authorName: data['authorName'] as String,
              text: text,
              avatarUrl: data['authorAvatarUrl'] as String?,
            ),
          );
        });
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

  // Счётчик "перезагрузи ответы" на комментарий — растёт при каждом новом
  // ответе, чтобы конкретный _CommentTile точечно обновил свой список.
  final Map<String, int> _replyReloadTicks = {};

  /// Всего = комментарии верхнего уровня + все их ответы.
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
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            SizedBox(height: 1.2.h),
            Container(
              width: 10.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 1.5.h),
            Text(
              'Комментарии ($_totalCount)',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 1.h),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
            const Divider(height: 1),
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
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _replyingTo != null
                              ? 'Ответить ${_replyingTo!.authorName}...'
                              : 'Написать комментарий...',
                          filled: true,
                          fillColor: const Color(0xFFF2F2F7),
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
                        backgroundColor: const Color(0xFF4DA6FF),
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

  Widget _replyBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF2F2F7),
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ответ для ${_replyingTo!.authorName}',
              style: TextStyle(fontSize: 12.sp, color: Colors.black54),
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: const Icon(Icons.close_rounded, size: 18, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Text(
            'Ошибка загрузки комментариев:\n$_loadError',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.red),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'Пока нет комментариев.\nБудьте первым!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.sp, color: Colors.black45),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      physics: const BouncingScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, i) {
        final c = _comments[i];
        return _CommentTile(
          key: ValueKey(c.id),
          carId: widget.carId,
          commentId: c.id,
          authorName: c.authorName,
          text: c.text,
          avatarUrl: c.avatarUrl,
          onReply: _startReply,
          reloadTick: _replyReloadTicks[c.id] ?? 0,
          replyCount: c.replyCount,
        );
      },
    );
  }
}

/// Один комментарий верхнего уровня + его ответы.
/// Ответы тоже грузятся ОДИН РАЗ по тапу "Посмотреть ответы" (через .get()),
/// а не постоянным стримом.
class _CommentTile extends StatefulWidget {
  final String carId;
  final String commentId;
  final String authorName;
  final String text;
  final String? avatarUrl;
  final void Function(String commentId, String authorName) onReply;
  final int reloadTick;
  final int replyCount;

  const _CommentTile({
    super.key,
    required this.carId,
    required this.commentId,
    required this.authorName,
    required this.text,
    required this.avatarUrl,
    required this.onReply,
    required this.reloadTick,
    required this.replyCount,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _repliesExpanded = false;
  bool _repliesLoading = false;
  List<_CommentData> _replies = [];

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
      _replies = snap.docs.map(_CommentData.fromDoc).toList();
    } catch (_) {
      // если не получилось — просто оставляем пустой список
    } finally {
      if (mounted) setState(() => _repliesLoading = false);
    }
  }

  @override
  void didUpdateWidget(covariant _CommentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Если только что отправили новый ответ на этот комментарий:
    if (widget.reloadTick != oldWidget.reloadTick) {
      if (_repliesExpanded) {
        // ветка открыта — тихо подгружаем свежий список
        _loadReplies();
      } else {
        // ветка закрыта — сбрасываем кэш, чтобы при следующем раскрытии
        // список подтянулся заново уже с новым ответом
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

  @override
  Widget build(BuildContext context) {
    final initials = widget.authorName.isNotEmpty ? widget.authorName[0].toUpperCase() : '?';
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 4.w,
                backgroundColor: Colors.black12,
                backgroundImage: hasAvatar ? NetworkImage(widget.avatarUrl!) : null,
                child: hasAvatar ? null : Text(initials),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.authorName,
                        style: TextStyle(fontSize: 12.5.sp, fontWeight: FontWeight.w700)),
                    SizedBox(height: 0.3.h),
                    Text(widget.text, style: TextStyle(fontSize: 13.sp, height: 1.35)),
                    SizedBox(height: 0.5.h),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onReply(widget.commentId, widget.authorName),
                          child: Text(
                            'Ответить',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 11.w, top: 0.5.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_repliesExpanded)
                  GestureDetector(
                    onTap: _toggleReplies,
                    child: Row(
                      children: [
                        Container(width: 6.w, height: 1, color: Colors.black26),
                        SizedBox(width: 2.w),
                        Text(
                          widget.replyCount > 0
                              ? 'Посмотреть ответы (${widget.replyCount})'
                              : 'Посмотреть ответы',
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4DA6FF),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  if (_repliesLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_replies.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 0.5.h),
                      child: Text('Пока нет ответов',
                          style: TextStyle(fontSize: 11.5.sp, color: Colors.black38)),
                    )
                  else
                    for (final reply in _replies) _replyItem(reply),
                  GestureDetector(
                    onTap: () => setState(() => _repliesExpanded = false),
                    child: Text(
                      'Скрыть ответы',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black45,
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

  Widget _replyItem(_CommentData reply) {
    final hasAvatar = reply.avatarUrl != null && reply.avatarUrl!.isNotEmpty;
    final initials = reply.authorName.isNotEmpty ? reply.authorName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 3.2.w,
            backgroundColor: Colors.black12,
            backgroundImage: hasAvatar ? NetworkImage(reply.avatarUrl!) : null,
            child: hasAvatar ? null : Text(initials, style: TextStyle(fontSize: 10.sp)),
          ),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reply.authorName,
                    style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700)),
                SizedBox(height: 0.2.h),
                Text(reply.text, style: TextStyle(fontSize: 12.sp, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}