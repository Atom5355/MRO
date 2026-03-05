import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/list_service.dart';
import '../services/auth_service.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen>
    with TickerProviderStateMixin {
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF141414);
  static const Color _surfaceRaised = Color(0xFF1C1C1C);
  static const Color _border = Color(0xFF222222);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _text = Color(0xFFEAEAEA);
  static const Color _textDim = Color(0xFF777777);

  final ListService _listService = ListService();
  final AuthService _authService = AuthService();
  final _newListController = TextEditingController();
  final _nameController = TextEditingController();
  final _workOrderController = TextEditingController();

  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  String? _selectedListId;

  @override
  void initState() {
    super.initState();
    _listService.addListener(_onListChanged);

    _entranceController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _entranceFade = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic);
    _entranceSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();

    // Default to active list
    _selectedListId = _listService.activeListId;
  }

  @override
  void dispose() {
    _listService.removeListener(_onListChanged);
    _entranceController.dispose();
    _newListController.dispose();
    _nameController.dispose();
    _workOrderController.dispose();
    super.dispose();
  }

  void _onListChanged() {
    if (mounted) setState(() {});
  }

  PartsList? get _selectedList {
    if (_selectedListId == null && _listService.lists.isNotEmpty) {
      _selectedListId = _listService.lists.first.id;
    }
    return _listService.lists
        .where((l) => l.id == _selectedListId)
        .firstOrNull;
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _entranceFade,
        child: SlideTransition(
          position: _entranceSlide,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Row(
                    children: [
                      // Left sidebar: list of lists
                      _buildListsSidebar(),
                      // Divider
                      Container(width: 1, color: _border),
                      // Right: selected list detail
                      Expanded(child: _buildListDetail()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _bg,
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back, color: _text, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _accent.withValues(alpha: 0.1),
              border: Border.all(color: _accent.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.list_alt, color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('My Lists',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _text)),
              Text(
                '${_listService.lists.length} list${_listService.lists.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 11, color: _textDim),
              ),
            ],
          ),
          const Spacer(),
          // User info & sign out
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _bg,
              border: Border.all(color: _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_outline, size: 14, color: _textDim),
              const SizedBox(width: 6),
              Text(
                _authService.displayName.isNotEmpty
                    ? _authService.displayName
                    : _authService.email,
                style:
                    const TextStyle(fontSize: 11, color: _text),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  await _authService.signOut();
                  if (mounted) Navigator.pop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.red.withValues(alpha: 0.08),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: const Text('Sign Out',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Lists sidebar ──────────────────────────────────────────

  Widget _buildListsSidebar() {
    return Container(
      width: 260,
      color: _surface,
      child: Column(
        children: [
          // Create new list
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: _showCreateListDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.3),
                      style: BorderStyle.solid),
                  color: _accent.withValues(alpha: 0.05),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: _accent),
                    SizedBox(width: 6),
                    Text('New List',
                        style: TextStyle(
                            fontSize: 12,
                            color: _accent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          // List items
          Expanded(
            child: _listService.lists.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.playlist_add,
                            size: 40,
                            color: _textDim.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        const Text('No lists yet',
                            style: TextStyle(
                                fontSize: 13, color: _textDim)),
                        const SizedBox(height: 4),
                        const Text('Create one to get started',
                            style: TextStyle(
                                fontSize: 11, color: _textDim)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _listService.lists.length,
                    itemBuilder: (ctx, idx) {
                      final list = _listService.lists[idx];
                      final isSelected = list.id == _selectedListId;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                            milliseconds: 250 + idx * 60),
                        curve: Curves.easeOutCubic,
                        builder: (ctx, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(-12 * (1 - v), 0),
                            child: child,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _selectedListId = list.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: isSelected
                                  ? _accent.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? _accent.withValues(alpha: 0.25)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(7),
                                    color: isSelected
                                        ? _accent
                                            .withValues(alpha: 0.15)
                                        : _bg,
                                    border: Border.all(
                                      color: isSelected
                                          ? _accent
                                              .withValues(alpha: 0.3)
                                          : _border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${list.uniqueItemCount}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected
                                            ? _accent
                                            : _textDim,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(list.name,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: isSelected
                                                  ? _text
                                                  : _textDim)),
                                      Text(
                                        '${list.uniqueItemCount} items',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _textDim
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      size: 16,
                                      color: isSelected
                                          ? _text
                                          : _textDim),
                                  padding: EdgeInsets.zero,
                                  constraints:
                                      const BoxConstraints(),
                                  color: _surfaceRaised,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    side: const BorderSide(
                                        color: _border),
                                  ),
                                  onSelected: (v) {
                                    if (v == 'rename') {
                                      _showRenameDialog(list);
                                    } else if (v == 'delete') {
                                      _showDeleteDialog(list);
                                    } else if (v == 'set_active') {
                                      _listService.activeListId =
                                          list.id;
                                      _showSnack(
                                          '"${list.name}" set as active list');
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    _popupItem(Icons.push_pin_outlined,
                                        'Set as active', 'set_active'),
                                    _popupItem(Icons.edit_outlined,
                                        'Rename', 'rename'),
                                    _popupItem(Icons.delete_outline,
                                        'Delete', 'delete',
                                        isDestructive: true),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  PopupMenuEntry<String> _popupItem(
      IconData icon, String label, String value,
      {bool isDestructive = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      child: Row(children: [
        Icon(icon,
            size: 14,
            color: isDestructive ? Colors.redAccent : _textDim),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: isDestructive ? Colors.redAccent : _text)),
      ]),
    );
  }

  // ── List detail (right panel) ────────────────────────────────

  Widget _buildListDetail() {
    final list = _selectedList;

    if (list == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back,
                size: 32, color: _textDim.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            const Text('Select or create a list',
                style: TextStyle(fontSize: 14, color: _textDim)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // List header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
          decoration: const BoxDecoration(
            color: _surface,
            border: Border(bottom: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(list.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _text)),
                        if (list.id == _listService.activeListId) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _accent.withValues(alpha: 0.1),
                            ),
                            child: const Text('Active',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _accent,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(
                        '${list.uniqueItemCount} items \u00b7 ${list.totalQuantity} total qty'
                        '${list.totalCost > 0 ? ' \u00b7 \$${list.totalCost.toStringAsFixed(2)}' : ''}',
                        style: const TextStyle(fontSize: 11, color: _textDim),
                      ),
                    ]),
              ),
              if (list.items.isNotEmpty) ...[
                _actionBtn(Icons.print, 'Print', () => _showPrintDialog(list)),
                const SizedBox(width: 6),
                _actionBtn(Icons.delete_sweep_outlined, 'Clear',
                    () => _showClearDialog(list),
                    isDestructive: true),
              ],
            ],
          ),
        ),

        // Items
        Expanded(
          child: list.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 48,
                          color: _textDim.withValues(alpha: 0.25)),
                      const SizedBox(height: 12),
                      const Text('No parts in this list',
                          style: TextStyle(
                              fontSize: 14, color: _textDim)),
                      const SizedBox(height: 4),
                      const Text(
                          'Add parts from search results',
                          style: TextStyle(
                              fontSize: 12, color: _textDim)),
                    ],
                  ),
                )
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    itemCount: list.items.length,
                    itemBuilder: (ctx, idx) {
                      final item = list.items[idx];
                      return _buildItemRow(list.id, item, idx);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isDestructive
              ? Colors.red.withValues(alpha: 0.06)
              : _bg,
          border: Border.all(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.2)
                : _border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: isDestructive ? Colors.redAccent : _textDim),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: isDestructive ? Colors.redAccent : _textDim,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Item row ───────────────────────────────────────────────────

  Widget _buildItemRow(String listId, ListItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(16 * (1 - v), 0),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            // Part info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _text),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (item.legacyCode.isNotEmpty)
                      _chipTag(item.legacyCode),
                    if (item.manufacturer.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _chipTag(item.manufacturer),
                    ],
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      _chipTag(item.location,
                          color: Colors.orange.withValues(alpha: 0.15),
                          textColor: Colors.orange),
                    ],
                  ]),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: _textDim)),
                  ],
                ],
              ),
            ),

            // Price
            if (item.unitCost > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${item.lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF22C55E)),
                    ),
                    if (item.quantity > 1)
                      Text(
                        '\$${item.unitCost.toStringAsFixed(2)} ea',
                        style: TextStyle(
                          fontSize: 9,
                          color: _textDim.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),

            // Quantity controls
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _bg,
                border: Border.all(color: _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyBtn(Icons.remove, () {
                    _listService.updateQuantity(
                        listId, item.partId, item.quantity - 1);
                  }),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('${item.quantity}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _text)),
                  ),
                  _qtyBtn(Icons.add, () {
                    _listService.updateQuantity(
                        listId, item.partId, item.quantity + 1);
                  }),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Remove
            InkWell(
              onTap: () =>
                  _listService.removeFromList(listId, item.partId),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.red.withValues(alpha: 0.06),
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: const Icon(Icons.close,
                    size: 14, color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipTag(String text,
      {Color? color, Color? textColor}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color ?? _bg,
        border: Border.all(color: _border),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 9,
              color: textColor ?? _textDim,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 14, color: _textDim),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────

  void _showCreateListDialog() {
    _newListController.clear();
    showDialog(
      context: context,
      builder: (ctx) => _dialogFrame(
        title: 'Create New List',
        icon: Icons.add,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(
            controller: _newListController,
            hint: 'List name (e.g. Work Order #123)',
            autofocus: true,
            onSubmit: () async {
              final name = _newListController.text.trim();
              Navigator.pop(ctx);
              final created = await _listService
                  .createList(name.isEmpty ? 'Untitled List' : name);
              if (created != null) {
                setState(() => _selectedListId = created.id);
                _showSnack('List "${created.name}" created');
              }
            },
          ),
          const SizedBox(height: 16),
          _dialogActions(ctx, confirmLabel: 'Create', onConfirm: () async {
            final name = _newListController.text.trim();
            Navigator.pop(ctx);
            final created = await _listService
                .createList(name.isEmpty ? 'Untitled List' : name);
            if (created != null) {
              setState(() => _selectedListId = created.id);
              _showSnack('List "${created.name}" created');
            }
          }),
        ]),
      ),
    );
  }

  void _showRenameDialog(PartsList list) {
    _newListController.text = list.name;
    showDialog(
      context: context,
      builder: (ctx) => _dialogFrame(
        title: 'Rename List',
        icon: Icons.edit_outlined,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(
            controller: _newListController,
            hint: 'New name',
            autofocus: true,
          ),
          const SizedBox(height: 16),
          _dialogActions(ctx, confirmLabel: 'Rename', onConfirm: () async {
            final name = _newListController.text.trim();
            if (name.isNotEmpty) {
              await _listService.renameList(list.id, name);
              _showSnack('List renamed to "$name"');
            }
            Navigator.pop(ctx);
          }),
        ]),
      ),
    );
  }

  void _showDeleteDialog(PartsList list) {
    showDialog(
      context: context,
      builder: (ctx) => _dialogFrame(
        title: 'Delete "${list.name}"?',
        icon: Icons.delete_outline,
        iconColor: Colors.redAccent,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'This will permanently delete this list and its ${list.uniqueItemCount} items.',
            style: const TextStyle(fontSize: 13, color: _textDim),
          ),
          const SizedBox(height: 18),
          _dialogActions(ctx,
              confirmLabel: 'Delete',
              isDestructive: true, onConfirm: () async {
            Navigator.pop(ctx);
            await _listService.deleteList(list.id);
            setState(() {
              if (_selectedListId == list.id) {
                _selectedListId = _listService.lists.isNotEmpty
                    ? _listService.lists.first.id
                    : null;
              }
            });
            _showSnack('List deleted');
          }),
        ]),
      ),
    );
  }

  void _showClearDialog(PartsList list) {
    showDialog(
      context: context,
      builder: (ctx) => _dialogFrame(
        title: 'Clear all items?',
        icon: Icons.delete_sweep_outlined,
        iconColor: Colors.redAccent,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Remove all ${list.uniqueItemCount} items from "${list.name}"?',
            style: const TextStyle(fontSize: 13, color: _textDim),
          ),
          const SizedBox(height: 18),
          _dialogActions(ctx,
              confirmLabel: 'Clear All',
              isDestructive: true, onConfirm: () async {
            Navigator.pop(ctx);
            await _listService.clearList(list.id);
            _showSnack('All items cleared');
          }),
        ]),
      ),
    );
  }

  void _showPrintDialog(PartsList list) {
    _nameController.clear();
    _workOrderController.clear();
    showDialog(
      context: context,
      builder: (ctx) => _dialogFrame(
        title: 'Print "${list.name}"',
        icon: Icons.print,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(
              controller: _nameController,
              hint: 'Your name',
              label: 'Name'),
          const SizedBox(height: 10),
          _dialogField(
              controller: _workOrderController,
              hint: 'Work order number',
              label: 'Work Order'),
          const SizedBox(height: 18),
          _dialogActions(ctx, confirmLabel: 'Print', onConfirm: () {
            Navigator.pop(ctx);
            _printList(list);
          }),
        ]),
      ),
    );
  }

  // ── Dialog helpers ─────────────────────────────────────────

  Widget _dialogFrame({
    required String title,
    required IconData icon,
    required Widget child,
    Color iconColor = _accent,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: iconColor.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _text)),
            ),
          ]),
          const SizedBox(height: 18),
          child,
        ]),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController controller,
    required String hint,
    String? label,
    bool autofocus = false,
    VoidCallback? onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: _textDim,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
          ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          style: const TextStyle(color: _text, fontSize: 13),
          onSubmitted: onSubmit != null ? (_) => onSubmit() : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _textDim, fontSize: 12),
            filled: true,
            fillColor: _bg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dialogActions(BuildContext ctx,
      {required String confirmLabel,
      required VoidCallback onConfirm,
      bool isDestructive = false}) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => Navigator.pop(ctx),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: _bg,
                border: Border.all(color: _border),
              ),
              child: const Center(
                child: Text('Cancel',
                    style: TextStyle(fontSize: 12, color: _textDim)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: InkWell(
            onTap: onConfirm,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDestructive
                    ? Colors.red.withValues(alpha: 0.15)
                    : _accent,
                border: isDestructive
                    ? Border.all(
                        color: Colors.red.withValues(alpha: 0.3))
                    : null,
              ),
              child: Center(
                child: Text(confirmLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: isDestructive
                            ? Colors.redAccent
                            : Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontSize: 12)),
      backgroundColor: _surfaceRaised,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Print ──────────────────────────────────────────────────

  /// Returns a display-safe value: shows the given string if it's non-null
  /// and non-empty, otherwise returns a dash. Never shows "null" or blank.
  String _safe(String? value) {
    if (value == null || value.trim().isEmpty) return '\u2014';
    final v = value.trim();
    // Guard against literal "null" strings from bad data
    if (v.toLowerCase() == 'null') return '\u2014';
    return _escapeHtml(v);
  }

  /// Formats a unit cost; returns dash if zero or null.
  String _safeCost(double? cost) {
    if (cost == null || cost <= 0) return '\u2014';
    return '\$${cost.toStringAsFixed(2)}';
  }

  void _printList(PartsList list) {
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy');
    final timeFormat = DateFormat('h:mm a');

    final name = _safe(_nameController.text);
    final workOrder = _safe(_workOrderController.text);

    // Compute totals
    double grandTotal = 0;
    for (final item in list.items) {
      if (item.unitCost > 0) grandTotal += item.unitCost * item.quantity;
    }

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <title>${_escapeHtml(list.name)} - Parts List</title>
  <style>
    @page { size: A4 landscape; margin: 0.35in 0.4in; }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
      color: #1a1a1a; font-size: 10px; line-height: 1.4;
      padding: 4px;
    }

    /* ── Header ────────────────────────── */
    .header {
      display: flex; justify-content: space-between; align-items: flex-end;
      border-bottom: 2.5px solid #1a1a1a; padding-bottom: 8px; margin-bottom: 12px;
    }
    .header-left { display: flex; align-items: center; gap: 12px; }
    .logo-icon {
      width: 36px; height: 36px; border-radius: 8px;
      background: #1a1a1a; color: white;
      display: flex; align-items: center; justify-content: center;
      font-size: 18px; font-weight: 800;
    }
    .logo-text { font-size: 18px; font-weight: 800; letter-spacing: 1.5px; }
    .logo-sub { font-size: 9px; color: #666; margin-top: 1px; }
    .header-right { text-align: right; font-size: 10px; color: #444; line-height: 1.6; }

    /* ── Meta info bar ─────────────────── */
    .meta-bar {
      display: flex; gap: 0; margin-bottom: 14px;
      border: 1px solid #ddd; border-radius: 6px; overflow: hidden;
    }
    .meta-item {
      flex: 1; padding: 7px 12px;
      border-right: 1px solid #ddd;
    }
    .meta-item:last-child { border-right: none; }
    .meta-label { font-size: 8px; text-transform: uppercase; letter-spacing: 0.8px; color: #888; font-weight: 600; }
    .meta-value { font-size: 11px; font-weight: 700; margin-top: 2px; }

    /* ── Table ──────────────────────────── */
    table { width: 100%; border-collapse: collapse; margin-bottom: 14px; }
    thead th {
      background: #1a1a1a; color: #fff;
      padding: 7px 10px; text-align: left;
      font-size: 8px; text-transform: uppercase; letter-spacing: 0.8px; font-weight: 700;
    }
    thead th:first-child { border-radius: 4px 0 0 0; }
    thead th:last-child { border-radius: 0 4px 0 0; }
    tbody td {
      padding: 6px 10px; border-bottom: 1px solid #e8e8e8;
      font-size: 10px; vertical-align: top;
    }
    tbody tr:nth-child(even) td { background: #fafafa; }
    tbody tr:hover td { background: #f0f4ff; }

    /* Number column */
    .col-num { width: 30px; text-align: center; color: #999; font-size: 9px; }

    /* Part name */
    .part-name { font-weight: 700; font-size: 10.5px; color: #111; }
    .part-desc { font-size: 9px; color: #666; margin-top: 2px; line-height: 1.3; }

    /* Legacy code badge */
    .legacy-badge {
      display: inline-block; background: #f0f0f0; color: #333;
      padding: 1px 7px; border-radius: 3px; font-size: 9px;
      font-weight: 600; font-family: 'Consolas', 'Courier New', monospace;
    }

    /* Location badge */
    .loc-badge {
      display: inline-block; background: #e8f0fe; color: #1a56db;
      padding: 1px 7px; border-radius: 3px; font-size: 9px; font-weight: 600;
    }

    /* Quantity pill */
    .qty-pill {
      display: inline-block; background: #1a1a1a; color: #fff;
      padding: 2px 10px; border-radius: 10px; font-weight: 700;
      font-size: 10px; text-align: center; min-width: 28px;
    }

    /* Price */
    .price { font-weight: 600; font-family: 'Consolas', 'Courier New', monospace; font-size: 10px; }
    .line-total { font-weight: 700; font-size: 10px; }
    .empty-val { color: #bbb; font-style: italic; font-size: 9px; }

    /* ── Summary footer ────────────────── */
    .summary-bar {
      display: flex; justify-content: space-between; align-items: center;
      background: #f5f5f5; border: 1px solid #ddd; border-radius: 6px;
      padding: 10px 16px; margin-bottom: 20px;
    }
    .summary-left { display: flex; gap: 24px; }
    .summary-item { font-size: 10px; color: #555; }
    .summary-item strong { color: #111; font-size: 11px; }
    .summary-total { font-size: 14px; font-weight: 800; color: #111; }

    /* ── Signature section ─────────────── */
    .sig-section {
      display: flex; gap: 40px; margin-top: 24px;
      padding-top: 10px; border-top: 1px solid #ddd;
    }
    .sig-block { flex: 1; }
    .sig-line { border-bottom: 1.5px solid #333; height: 30px; margin-bottom: 4px; }
    .sig-label { font-size: 8px; color: #888; text-transform: uppercase; letter-spacing: 0.6px; }

    @media print {
      body { padding: 0; }
      tbody tr:hover td { background: inherit; }
    }
  </style>
</head>
<body>
  <!-- Header -->
  <div class="header">
    <div class="header-left">
      <div class="logo-icon">M</div>
      <div>
        <div class="logo-text">MRO ENGINE</div>
        <div class="logo-sub">${_escapeHtml(list.name)}</div>
      </div>
    </div>
    <div class="header-right">
      <div><strong>${dateFormat.format(now)}</strong> at ${timeFormat.format(now)}</div>
      <div>Parts List &middot; ${list.uniqueItemCount} unique items</div>
    </div>
  </div>

  <!-- Meta info bar -->
  <div class="meta-bar">
    <div class="meta-item">
      <div class="meta-label">Requested By</div>
      <div class="meta-value">$name</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">Work Order</div>
      <div class="meta-value">$workOrder</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">Total Items</div>
      <div class="meta-value">${list.totalQuantity} pcs</div>
    </div>
    <div class="meta-item">
      <div class="meta-label">List Name</div>
      <div class="meta-value">${_escapeHtml(list.name)}</div>
    </div>
  </div>

  <!-- Itemized Table -->
  <table>
    <thead>
      <tr>
        <th class="col-num">#</th>
        <th>Part Name</th>
        <th>Legacy Code</th>
        <th>Location</th>
        <th>Description</th>
        <th style="text-align:right">Unit Price</th>
        <th style="text-align:center">Qty</th>
        <th style="text-align:right">Line Total</th>
      </tr>
    </thead>
    <tbody>
${_buildPrintRows(list)}
    </tbody>
  </table>

  <!-- Summary -->
  <div class="summary-bar">
    <div class="summary-left">
      <div class="summary-item">Unique Items: <strong>${list.uniqueItemCount}</strong></div>
      <div class="summary-item">Total Pieces: <strong>${list.totalQuantity}</strong></div>
    </div>
    ${grandTotal > 0 ? '<div class="summary-total">Grand Total: \$${grandTotal.toStringAsFixed(2)}</div>' : ''}
  </div>

  <!-- Signature -->
  <div class="sig-section">
    <div class="sig-block">
      <div class="sig-line"></div>
      <div class="sig-label">Requested By / Date</div>
    </div>
    <div class="sig-block">
      <div class="sig-line"></div>
      <div class="sig-label">Fulfilled By / Date</div>
    </div>
    <div class="sig-block">
      <div class="sig-line"></div>
      <div class="sig-label">Approved By / Date</div>
    </div>
  </div>

  <script>window.onload = function() { window.print(); }</script>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  String _buildPrintRows(PartsList list) {
    final buf = StringBuffer();
    var i = 1;
    for (final item in list.items) {
      final partName = _safe(item.itemName);
      final legacy = item.legacyCode.trim().isNotEmpty
          ? '<span class="legacy-badge">${_safe(item.legacyCode)}</span>'
          : '<span class="empty-val">\u2014</span>';
      final location = item.location.trim().isNotEmpty
          ? '<span class="loc-badge">${_safe(item.location)}</span>'
          : '<span class="empty-val">\u2014</span>';
      final desc = item.description.trim().isNotEmpty
          ? _safe(item.description)
          : '<span class="empty-val">\u2014</span>';
      final unitPrice = item.unitCost > 0
          ? '<span class="price">${_safeCost(item.unitCost)}</span>'
          : '<span class="empty-val">\u2014</span>';
      final lineTotal = item.unitCost > 0
          ? '<span class="line-total">\$${(item.unitCost * item.quantity).toStringAsFixed(2)}</span>'
          : '<span class="empty-val">\u2014</span>';

      buf.writeln('''
      <tr>
        <td class="col-num">$i</td>
        <td><div class="part-name">$partName</div></td>
        <td>$legacy</td>
        <td>$location</td>
        <td style="max-width:200px">$desc</td>
        <td style="text-align:right">$unitPrice</td>
        <td style="text-align:center"><span class="qty-pill">${item.quantity}</span></td>
        <td style="text-align:right">$lineTotal</td>
      </tr>''');
      i++;
    }
    return buf.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
