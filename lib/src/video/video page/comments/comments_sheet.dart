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
  final String uid; // uid автора — нужен для бейджа "Автор" и прав
  final String authorName;
  String text; // не final — редактируется владельцем комментария
  // Не final: изначально берём то, что сохранено на самом комментарии,
  // а затем подтягиваем актуальное фото профиля из users/{uid} —
  // см. _hydrateAvatars. Так комментарий всегда показывает ТЕКУЩЕЕ
  // фото профиля автора, а не то, что было на момент отправки.
  String? avatarUrl;
  int replyCount; // количество ответов — учитывается в общем счётчике
  bool pinned; // владелец объявления может закрепить комментарий сверху

  _CommentData({
    required this.id,
    required this.uid,
    required this.authorName,
    required this.text,
    this.avatarUrl,
    this.replyCount = 0,
    this.pinned = false,
  });

  factory _CommentData.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return _CommentData(
      id: doc.id,
      uid: (data['uid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Пользователь',
      text: (data['text'] as String?) ?? '',
      avatarUrl: data['authorAvatarUrl'] as String?,
      pinned: (data['pinned'] as bool?) ?? false,
    );
  }
}

// Кэш "uid -> avatarUrl" из коллекции users, общий для списка комментариев
// и всех открытых веток ответов внутри одной шторки — чтобы одного и того
// же автора не запрашивать повторно.
final Map<String, String> _profileAvatarCache = {};

/// Подтягивает АКТУАЛЬНОЕ фото профиля (users/{uid}.avatarUrl) для каждого
/// автора в списке — так же, как страница видео берёт avatarUrl владельца
/// объявления в _loadOwner, а не то, что было сохранено на комментарии
/// в момент отправки.
Future<void> _hydrateAvatars(List<_CommentData> items) async {
  final uids = items.map((c) => c.uid).where((u) => u.isNotEmpty).toSet();
  final uncached = uids.where((u) => !_profileAvatarCache.containsKey(u)).toList();
  if (uncached.isNotEmpty) {
    try {
      // whereIn поддерживает максимум 30 id за запрос — бьём на чанки.
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
        // Юзеров без документа/поля тоже помечаем — чтобы не повторять запрос.
        for (final u in chunk) {
          _profileAvatarCache.putIfAbsent(u, () => '');
        }
      }
    } catch (_) {
      // офлайн и т.п. — оставляем то, что уже было сохранено на комментарии
    }
  }
  for (final c in items) {
    final url = _profileAvatarCache[c.uid];
    if (url != null && url.isNotEmpty) c.avatarUrl = url;
  }
}

/// uid текущего юзера -> актуальный avatarUrl из users/{uid}, с кэшем.
/// Используется при оптимистичной вставке своего нового комментария/ответа,
/// чтобы сразу показать правильное фото, не дожидаясь общей гидратации.
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

/// Комментарии к объявлению + ответы на них.
/// Загружаются ОДИН РАЗ при открытии шторки (через .get(), а не .snapshots()),
/// дальше список обновляется локально — без постоянного "мигания" лоадера.
class CommentsSheet extends StatefulWidget {
  final String carId;
  // ownerId владельца объявления — нужен, чтобы отметить его комментарии
  // бейджем "Автор" и дать ему право закреплять/удалять любые комментарии.
  final String ownerId;

  const CommentsSheet({super.key, required this.carId, required this.ownerId});

  static Future<void> show(BuildContext context, String carId, String ownerId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(carId: carId, ownerId: ownerId),
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

  // Комментарий, для которого открыт "тред"-режим (видны только он и его
  // ответы). null — обычный список всех комментариев.
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
      // Подтягиваем актуальные фото профиля авторов (users/{uid}.avatarUrl),
      // а не то, что было сохранено на комментарии в момент отправки.
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

  /// Закреплённые комментарии — наверх списка (сохраняя относительный
  /// порядок внутри каждой группы), остальные — под ними.
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

  void _startReply(String commentId, String authorName) {
    setState(() => _replyingTo = _ReplyTarget(commentId, authorName));
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  // Открыть тред-режим для комментария: список сворачивается до него одного
  // + его ответов.
  void _openThread(String commentId) {
    final c = _comments.where((x) => x.id == commentId).toList();
    if (c.isEmpty) return;
    setState(() => _threadComment = c.first);
  }

  // Вернуться из тред-режима к полному списку комментариев.
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
      // Реальное фото профиля из users/{uid}.avatarUrl — то же самое,
      // что показывается на странице видео у владельца объявления.
      // FirebaseAuth.photoURL может не совпадать с ним (фото профиля
      // загружается отдельно, не синхронизируется с Auth).
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
        final docRef = await _commentsRef.add({...data, 'pinned': false});
        // Комментарий верхнего уровня — добавляем в начало локального списка
        // без повторного похода в Firestore.
        setState(() {
          _comments.insert(
            0,
            _CommentData(
              id: docRef.id,
              uid: user.uid,
              authorName: data['authorName'] as String,
              text: text,
              avatarUrl: myAvatarUrl,
            ),
          );
          // Новый комментарий не закреплён — держим закреплённые сверху.
          _reorderPinned();
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

  /// Владелец объявления закрепляет/открепляет ЛЮБОЙ комментарий.
  Future<void> _togglePin(String commentId) async {
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i == -1) return;
    final newValue = !_comments[i].pinned;
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

  /// Удаление комментария: свой — любой пользователь, любой — владелец
  /// объявления. Право проверяется дополнительно на уровне Firestore rules.
  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: const Text('Это действие нельзя отменить.'),
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
        // Если удалили комментарий, который был открыт в тред-режиме —
        // возвращаемся к общему списку.
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

  /// Переписать СВОЙ комментарий (для не-владельца — доступно только на
  /// собственном комментарии; проверяется и на уровне Firestore rules).
  Future<void> _editComment(String commentId) async {
    final i = _comments.indexWhere((c) => c.id == commentId);
    if (i == -1) return;
    final editController = TextEditingController(text: _comments[i].text);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать комментарий'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
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
    // Тред-режим: только выбранный комментарий и его ответы.
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
          isOwnerComment: c.uid == widget.ownerId,
          isMine: isMine,
          isCarOwner: _isCarOwner,
          onReply: _startReply,
          onPin: _isCarOwner ? _togglePin : null,
          onDelete: (isMine || _isCarOwner) ? _deleteComment : null,
          onEdit: isMine ? _editComment : null,
          reloadTick: _replyReloadTicks[c.id] ?? 0,
          replyCount: c.replyCount,
          // Тап по "Посмотреть ответы" открывает тред-режим вместо
          // локального разворачивания списка внутри общей ленты.
          onOpenThread: _openThread,
        );
      },
    );
  }

  /// Тред-режим: заголовок с кнопкой "назад" + один комментарий с
  /// принудительно развёрнутыми ответами. Остальные комментарии не видны.
  Widget _buildThreadView(_CommentData c) {
    final isMine = _myUid != null && _myUid == c.uid;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.8.h),
          child: Row(
            children: [
              GestureDetector(
                onTap: _closeThread,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded,
                          size: 1.8.h, color: Colors.black87),
                      SizedBox(width: 1.5.w),
                      Text(
                        'Назад',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
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
              isOwnerComment: c.uid == widget.ownerId,
              isMine: isMine,
              isCarOwner: _isCarOwner,
              onReply: _startReply,
              onPin: _isCarOwner ? _togglePin : null,
              onDelete: (isMine || _isCarOwner) ? _deleteComment : null,
              onEdit: isMine ? _editComment : null,
              reloadTick: _replyReloadTicks[c.id] ?? 0,
              replyCount: c.replyCount,
              // В тред-режиме ответы сразу развёрнуты, кнопка-переключатель
              // не нужна — назад возвращает к списку.
              forceExpanded: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Один комментарий верхнего уровня + его ответы.
/// Ответы тоже грузятся ОДИН РАЗ по тапу "Посмотреть ответы" (через .get()),
/// а не постоянным стримом.
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
  final bool isOwnerComment; // автор этого комментария — владелец объявления
  final bool isMine; // это МОЙ комментарий
  final bool isCarOwner; // Я — владелец объявления (могу пинить/удалять любой)
  final void Function(String commentId, String authorName) onReply;
  final Future<void> Function(String commentId)? onPin;
  final Future<void> Function(String commentId)? onDelete;
  final Future<void> Function(String commentId)? onEdit;
  final int reloadTick;
  final int replyCount;
  // Если задан — тап по "Посмотреть ответы" открывает тред-режим у родителя
  // вместо локального разворачивания списка ответов.
  final void Function(String commentId)? onOpenThread;
  // Тред-режим: ответы всегда развёрнуты, переключатель не показывается.
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

  static const _accentBlue = Color(0xFF4DA6FF);

  @override
  void initState() {
    super.initState();
    _replyCountLocal = widget.replyCount;
    if (widget.forceExpanded) {
      // Тред-режим: сразу разворачиваем и грузим ответы.
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
      // Актуальные фото профиля авторов ответов — та же логика, что и
      // для комментариев верхнего уровня.
      await _hydrateAvatars(loaded);
      _replies = loaded;
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
      _replyCountLocal = widget.replyCount;
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

  void _handleViewRepliesTap() {
    if (widget.onOpenThread != null) {
      // Открываем тред-режим у родителя (остальные комментарии скрываются).
      widget.onOpenThread!(widget.commentId);
    } else {
      _toggleReplies();
    }
  }

  /// Переписать СВОЙ ответ.
  Future<void> _editReply(_CommentData reply) async {
    final editController = TextEditingController(text: reply.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать ответ'),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 4,
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

  /// Удалить СВОЙ ответ.
  Future<void> _deleteReply(_CommentData reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить ответ?'),
        content: const Text('Это действие нельзя отменить.'),
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
        color: _accentBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(3.w),
        border: Border.all(color: _accentBlue.withOpacity(0.4)),
      ),
      child: Text(
        'Автор',
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w800,
          color: _accentBlue,
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
          Icon(Icons.push_pin_rounded, size: 1.5.h, color: Colors.black45),
          SizedBox(width: 1.w),
          Text(
            'Закреплено',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  /// Меню действий над комментарием: пин/удалить для владельца объявления,
  /// изменить/удалить для автора собственного комментария.
  Widget? _actionsMenu() {
    final canPin = widget.onPin != null;
    final canDelete = widget.onDelete != null;
    final canEdit = widget.onEdit != null;
    if (!canPin && !canDelete && !canEdit) return null;

    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 2.h, color: Colors.black45),
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
          const PopupMenuItem(value: 'edit', child: Text('Изменить')),
        if (canPin)
          PopupMenuItem(
            value: 'pin',
            child: Text(widget.pinned ? 'Открепить' : 'Закрепить'),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  /// Аватар в стиле страницы видео (_creatorRow): круг с рамкой и
  /// картинкой на всю площадь, либо инициалы по центру, если аватара нет.
  Widget _styledAvatar(String name, String? avatarUrl, double size) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDF2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1.2),
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
                  color: Colors.black54,
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

    // Показываем блок с ответами (ссылку "Посмотреть ответы" или сам
    // развёрнутый список), только если есть хотя бы один ответ, либо он
    // уже развёрнут, либо мы принудительно в тред-режиме.
    final showRepliesBlock =
        _replyCountLocal > 0 || _repliesExpanded || widget.forceExpanded;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.pinned) _pinnedTag(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _styledAvatar(widget.authorName, widget.avatarUrl, 10.5.w),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(widget.authorName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5.sp, fontWeight: FontWeight.w700)),
                        ),
                        if (widget.isOwnerComment) _authorBadge(),
                      ],
                    ),
                    SizedBox(height: 0.4.h),
                    Text(widget.text, style: TextStyle(fontSize: 14.sp, height: 1.35)),
                    SizedBox(height: 0.6.h),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onReply(widget.commentId, widget.authorName),
                          child: Text(
                            'Ответить',
                            style: TextStyle(
                              fontSize: 12.sp,
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
              if (menu != null) menu,
            ],
          ),
          if (showRepliesBlock)
            Padding(
              padding: EdgeInsets.only(left: 13.5.w, top: 0.5.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_repliesExpanded)
                    GestureDetector(
                      onTap: _handleViewRepliesTap,
                      child: Row(
                        children: [
                          Container(width: 6.w, height: 1, color: Colors.black26),
                          SizedBox(width: 2.w),
                          Text(
                            'Посмотреть ответы ($_replyCountLocal)',
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
                    // В тред-режиме скрываем "Скрыть ответы" — возврат к
                    // списку выполняется кнопкой "Назад" наверху.
                    if (!widget.forceExpanded)
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
    final isOwnerReply = reply.uid == widget.ownerId;
    final isMineReply = widget.myUid != null && widget.myUid == reply.uid;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _styledAvatar(reply.authorName, reply.avatarUrl, 8.5.w),
          SizedBox(width: 2.5.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(reply.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5.sp, fontWeight: FontWeight.w700)),
                    ),
                    if (isOwnerReply) _authorBadge(),
                  ],
                ),
                SizedBox(height: 0.25.h),
                Text(reply.text, style: TextStyle(fontSize: 13.sp, height: 1.3)),
                // Свой ответ — можно переписать или удалить (владелец
                // объявления права на чужие ответы здесь не получает —
                // это не запрашивалось, поведение как раньше).
                if (isMineReply)
                  Padding(
                    padding: EdgeInsets.only(top: 0.3.h),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _editReply(reply),
                          child: Text(
                            'Изменить',
                            style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54),
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
                                color: Colors.red.shade400),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}