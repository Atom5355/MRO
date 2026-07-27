import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mro_part.dart';
import '../services/mro_data_service.dart';
import '../services/advanced_search_service.dart';
import '../services/ai_search_service.dart'
    show AISearchResultKind, AISearchService, TokenUsage;
import '../services/part_filter_service.dart';
import '../services/list_service.dart';
import '../services/auth_service.dart';
import 'lists_screen.dart';
import 'auth_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  // ── Design tokens ─────────────────────────────────────────────────────
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _accentDim = Color(0xFF1D4ED8);
  static const Color _surface = Color(0xFF0A0A0A);
  static const Color _surfaceRaised = Color(0xFF141414);
  static const Color _border = Color(0xFF222222);
  static const Color _text = Color(0xFFEAEAEA);
  static const Color _textDim = Color(0xFF777777);
  static const double _filterUiScale = 1.5;

  double _filterScaled(double value) => value * _filterUiScale;

  double _filterDrawerWidth(BuildContext context) {
    final targetWidth = _filterScaled(300);
    final maxWidth = MediaQuery.sizeOf(context).width * 0.92;
    return targetWidth < maxWidth ? targetWidth : maxWidth;
  }

  // ── Services ──────────────────────────────────────────────────────────
  final MroDataService _dataService = MroDataService();
  final AdvancedSearchService _searchService = AdvancedSearchService();
  final TextEditingController _searchController = TextEditingController();
  final AISearchService _aiSearchService = AISearchService();
  final PartFilterService _filterService = const PartFilterService();
  final ListService _listService = ListService();
  final AuthService _authService = AuthService();

  // ── State ─────────────────────────────────────────────────────────────
  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  List<SearchResult> _allPartResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  bool _hasSearched = false;
  bool _useAI = true;
  String? _aiInterpretation;
  TokenUsage? _tokenUsage;
  AISearchResultKind? _lastSearchKind;
  String? _aiFallbackMessage;

  // Filter state
  bool _filterDrawerOpen = false;
  final Map<String, List<String>> _activeFilters = {
    'description': [],
    'manufacturerPartNumber': [],
    'location': [],
  };
  final Map<String, TextEditingController> _filterControllers = {};
  final Map<String, FocusNode> _filterFocusNodes = {};

  final TextEditingController _manufacturerSearchController =
      TextEditingController();
  final Set<String> _selectedManufacturers = {};
  String _manufacturerSearchQuery = '';

  final TextEditingController _legacyCodeSearchController =
      TextEditingController();
  final Set<String> _selectedLegacyCodes = {};
  String _legacyCodeSearchQuery = '';

  final TextEditingController _wPartNumberSearchController =
      TextEditingController();
  final Set<String> _selectedWPartNumbers = {};
  String _wPartNumberSearchQuery = '';

  // Notification
  String? _notificationMessage;
  IconData? _notificationIcon;
  late AnimationController _notificationController;
  late Animation<double> _notificationAnimation;

  // AI badge pulse
  late AnimationController _pulseController;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    for (final field in _activeFilters.keys) {
      _filterControllers[field] = TextEditingController();
      _filterFocusNodes[field] = FocusNode();
    }
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _notificationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _notificationAnimation = CurvedAnimation(
      parent: _notificationController,
      curve: Curves.easeOutCubic,
    );

    _listService.addListener(_onListChanged);
    _initializeFromLoadedData();
  }

  void _onListChanged() {
    if (mounted) setState(() {});
  }

  void _showNotification(String message, {IconData icon = Icons.check_circle}) {
    setState(() {
      _notificationMessage = message;
      _notificationIcon = icon;
    });
    _notificationController.forward(from: 0);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _notificationMessage == message) {
        _notificationController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _notificationMessage = null;
              _notificationIcon = null;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseController.dispose();
    _notificationController.dispose();
    _manufacturerSearchController.dispose();
    _legacyCodeSearchController.dispose();
    _wPartNumberSearchController.dispose();
    _listService.removeListener(_onListChanged);
    for (final c in _filterControllers.values) {
      c.dispose();
    }
    for (final f in _filterFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _initializeFromLoadedData() {
    if (!_dataService.isLoaded) {
      setState(() {
        _error = 'Data not loaded. Please restart the app.';
        _isLoading = false;
      });
      return;
    }
    _allPartResults = _dataService.parts
        .map(
          (part) => SearchResult(
            part: part,
            score: 0,
            matchReasons: const [],
          ),
        )
        .toList(growable: false);
    setState(() {
      _isLoading = false;
      _searchResults = _allPartResults;
    });
    _applyFilters();
  }

  void _playSound(String type) {
    switch (type) {
      case 'tap':
        HapticFeedback.lightImpact();
        break;
      case 'success':
        HapticFeedback.mediumImpact();
        break;
      case 'search':
        HapticFeedback.selectionClick();
        break;
    }
  }

  Future<void> _openListsAfterAuthentication() async {
    if (!mounted) {
      return;
    }

    Navigator.pop(context);
    await _listService.loadLists();

    if (!mounted) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ListsScreen()),
    );
  }

  // ── Filter logic ──────────────────────────────────────────────────────

  PartFilterState get _filterState => PartFilterState(
        selectedWPartNumbers: _selectedWPartNumbers,
        selectedManufacturers: _selectedManufacturers,
        selectedLegacyCodes: _selectedLegacyCodes,
        textFilters: {
          for (final entry in _activeFilters.entries)
            entry.key: entry.value.toSet(),
        },
      );

  void _applyFilters() {
    final results = _filterService.apply(_searchResults, _filterState);
    if (mounted) {
      setState(() => _filteredResults = results);
    }
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'description':
        return 'Description';
      case 'manufacturerPartNumber':
        return 'MPN';
      case 'location':
        return 'Location';
      default:
        return field;
    }
  }

  void _addFilter(String field, String tag) {
    if (tag.trim().isEmpty) return;
    _playSound('tap');
    final t = tag.trim().toLowerCase();
    if (!_activeFilters[field]!.contains(t)) {
      setState(() => _activeFilters[field]!.add(t));
      _filterControllers[field]?.clear();
      _applyFilters();
    }
    Future.microtask(() => _filterFocusNodes[field]?.requestFocus());
  }

  void _clearFieldFilters(String field) {
    if (_activeFilters[field]!.isEmpty) return;
    _playSound('tap');
    setState(() => _activeFilters[field]!.clear());
    _applyFilters();
  }

  void _removeFilter(String field, String tag) {
    _playSound('tap');
    setState(() => _activeFilters[field]!.remove(tag));
    _applyFilters();
  }

  void _clearAllFilters() {
    _playSound('tap');
    setState(() {
      for (final f in _activeFilters.keys) {
        _activeFilters[f]!.clear();
      }
      _selectedManufacturers.clear();
      _manufacturerSearchController.clear();
      _manufacturerSearchQuery = '';
      _selectedLegacyCodes.clear();
      _legacyCodeSearchController.clear();
      _legacyCodeSearchQuery = '';
      _selectedWPartNumbers.clear();
      _wPartNumberSearchController.clear();
      _wPartNumberSearchQuery = '';
    });
    _applyFilters();
  }

  int get _totalActiveFilters =>
      _activeFilters.values.fold(0, (s, t) => s + t.length) +
      _selectedManufacturers.length +
      _selectedLegacyCodes.length +
      _selectedWPartNumbers.length;

  // ── Search logic ──────────────────────────────────────────────────────

  Future<void> _confirmAndSearch(String query) => _performSearch(query);

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;
    final trimmedQuery = query.trim();
    _playSound('search');
    setState(() {
      _isSearching = true;
      _hasSearched = trimmedQuery.isNotEmpty;
      _aiInterpretation = null;
      _tokenUsage = null;
      _lastSearchKind = null;
      _aiFallbackMessage = null;
    });
    try {
      if (trimmedQuery.isEmpty) {
        setState(() {
          _searchResults = _allPartResults;
          _aiInterpretation = null;
          _lastSearchKind = null;
        });
      } else if (_useAI) {
        final aiCandidatePool = _totalActiveFilters == 0
            ? null
            : _filterService
                .apply(_allPartResults, _filterState)
                .map((result) => result.part);
        final result = await _aiSearchService.search(
          _dataService.parts,
          trimmedQuery,
          aiCandidatePool: aiCandidatePool,
          searchIndex: _dataService.searchIndex,
        );
        if (!mounted) return;
        setState(() {
          _searchResults = result.results;
          _aiInterpretation = result.aiInterpretation?.interpretation ??
              _searchService.describeQuery(
                trimmedQuery,
                resultCount: result.results.length,
                index: _dataService.searchIndex,
              );
          _tokenUsage = result.tokenUsage;
          _lastSearchKind = result.kind;
          _aiFallbackMessage = result.usedFallback
              ? 'AI unavailable—showing local results.'
              : null;
        });
      } else {
        final localResults = _searchService.search(
          _dataService.parts,
          trimmedQuery,
          index: _dataService.searchIndex,
        );
        setState(() {
          _searchResults = localResults;
          _aiInterpretation = _searchService.describeQuery(
            trimmedQuery,
            resultCount: localResults.length,
            index: _dataService.searchIndex,
          );
          _lastSearchKind = localResults.isNotEmpty &&
                  localResults.every(
                    (result) => result.kind == SearchResultKind.exact,
                  )
              ? AISearchResultKind.exact
              : AISearchResultKind.local;
        });
      }
      _applyFilters();
      _playSound('success');
    } on Object {
      final fallbackResults = _searchService.search(
        _dataService.parts,
        trimmedQuery,
        index: _dataService.searchIndex,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = fallbackResults;
        _aiInterpretation = trimmedQuery.isEmpty
            ? null
            : _searchService.describeQuery(
                trimmedQuery,
                resultCount: fallbackResults.length,
                index: _dataService.searchIndex,
              );
        _lastSearchKind = AISearchResultKind.fallback;
        _aiFallbackMessage =
            _useAI ? 'AI unavailable—showing local results.' : null;
      });
      _applyFilters();
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(),
              if (_aiInterpretation != null) _buildAIBanner(),
              if (_aiFallbackMessage != null) _buildAIFallbackBanner(),
              if (_tokenUsage != null && _useAI) _buildTokenRow(),
              Expanded(child: _buildBody()),
            ],
          ),
          if (_notificationMessage != null) _buildToast(),
          if (_filterDrawerOpen) _buildFilterOverlay(),
        ],
      ),
    );
  }

  // ── Top navigation bar ────────────────────────────────────────────────

  Widget _buildTopNavBar() {
    return Container(
      color: _surfaceRaised,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: brand + actions
            Row(
              children: [
                // Logo
                Container(
                  width: 28,
                  height: 28,
                  color: _accent,
                  child: const Icon(Icons.precision_manufacturing,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                const Text('MRO',
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: _text,
                        letterSpacing: 2)),
                const SizedBox(width: 3),
                Text('ENGINE',
                    style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w300,
                        color: _textDim,
                        letterSpacing: 2)),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: _border,
                  child: Text(
                    _isLoading ? '...' : '${_dataService.parts.length} parts',
                    style: const TextStyle(
                        fontSize: 9,
                        color: _textDim,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                // AI toggle
                _navButton(
                  onTap: () {
                    _playSound('tap');
                    setState(() => _useAI = !_useAI);
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _useAI
                              ? Color.lerp(_accent, Colors.white,
                                  _pulseController.value * 0.3)
                              : const Color(0xFF444444),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(_useAI ? 'AI' : 'OFF',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: _useAI ? _accent : _textDim)),
                  ]),
                ),
                const SizedBox(width: 4),
                // Filters
                _navButton(
                  onTap: () =>
                      setState(() => _filterDrawerOpen = !_filterDrawerOpen),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.tune, size: 13, color: _textDim),
                    if (_totalActiveFilters > 0) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        color: _accent,
                        child: Text('$_totalActiveFilters',
                            style: const TextStyle(
                                fontSize: 8,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(width: 4),
                // Lists
                _navButton(
                  onTap: () {
                    _playSound('tap');
                    if (!_authService.isLoggedIn) {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuthScreen(
                              onAuthenticated: _openListsAfterAuthentication,
                            ),
                          ));
                    } else {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ListsScreen()));
                    }
                  },
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.list_alt,
                        size: 13,
                        color: _listService.activeList == null ||
                                (_listService.activeList?.items.isEmpty ?? true)
                            ? _textDim
                            : _accent),
                    const SizedBox(width: 3),
                    Text('${_listService.activeList?.uniqueItemCount ?? 0}',
                        style: TextStyle(
                            fontSize: 9,
                            color: _listService.activeList == null ||
                                    (_listService.activeList?.items.isEmpty ??
                                        true)
                                ? _textDim
                                : _accent,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Row 2: search
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    color: _surface,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: _confirmAndSearch,
                      style: const TextStyle(color: _text, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: _useAI
                            ? 'Ask anything... "2hp motor for conveyor"'
                            : 'Search part name, MPN, manufacturer...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF444444), fontSize: 11),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(9),
                                child: SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5, color: _accent)),
                              )
                            : Icon(_useAI ? Icons.auto_awesome : Icons.search,
                                size: 14,
                                color:
                                    _useAI ? _accent : const Color(0xFF444444)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close,
                                    size: 12, color: _textDim),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    onPressed: _isSearching
                        ? null
                        : () => _confirmAndSearch(_searchController.text),
                    style: TextButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero),
                    ),
                    child: Text(_useAI ? 'ASK' : 'GO',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton({required VoidCallback onTap, required Widget child}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(border: Border.all(color: _border)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAIBanner() {
    return Container(
      color: _accentDim.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            _lastSearchKind == AISearchResultKind.ai
                ? Icons.psychology
                : Icons.tune,
            size: 12,
            color: _accent,
          ),
          const SizedBox(width: 6),
          Expanded(
              child: Text(_aiInterpretation!,
                  style: const TextStyle(fontSize: 10, color: _text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildAIFallbackBanner() {
    return Container(
      color: Colors.orange.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 12, color: Colors.orange),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _aiFallbackMessage!,
              style: const TextStyle(fontSize: 10, color: _text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow() {
    return Container(
      color: _surfaceRaised,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('IN ${_tokenUsage!.inputTokens.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, color: _textDim)),
          _divider(),
          Text('OUT ${_tokenUsage!.outputTokens.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, color: _textDim)),
          _divider(),
          Text('THINK ${_tokenUsage!.thoughtTokens.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, color: _textDim)),
          _divider(),
          Text('\$${_tokenUsage!.cost.toStringAsFixed(4)}',
              style: const TextStyle(
                  fontSize: 15, color: _accent, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1,
      height: 6,
      color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 6));

  // ── Body: grid of results ─────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
          const SizedBox(height: 10),
          const Text('Error Loading Data',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 4),
          Text(_error!,
              style: const TextStyle(fontSize: 11, color: _textDim),
              textAlign: TextAlign.center),
        ]),
      );
    }
    if (_filteredResults.isEmpty && (_hasSearched || _totalActiveFilters > 0)) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 36, color: _textDim),
          const SizedBox(height: 10),
          const Text('No Results',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
          const SizedBox(height: 4),
          Text(
              _totalActiveFilters > 0
                  ? 'Try removing some filters'
                  : 'Try a different search',
              style: const TextStyle(fontSize: 11, color: _textDim)),
          if (_totalActiveFilters > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Clear Filters',
                      style: TextStyle(color: _accent, fontSize: 11))),
            ),
        ]),
      );
    }

    return Column(
      children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: _surface,
          child: Row(children: [
            Text('${_filteredResults.length} results',
                style: const TextStyle(
                    fontSize: 10,
                    color: _textDim,
                    fontWeight: FontWeight.w600)),
            if (_hasSearched) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                color: _accentDim.withValues(alpha: 0.2),
                child: Text(
                    switch (_lastSearchKind) {
                      AISearchResultKind.ai => 'AI RANKED',
                      AISearchResultKind.exact => 'EXACT MATCH',
                      AISearchResultKind.fallback => 'LOCAL FALLBACK',
                      _ => 'LOCAL',
                    },
                    style: const TextStyle(
                        fontSize: 8,
                        color: _accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            ],
          ]),
        ),
        // Grid
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              int cols;
              if (constraints.maxWidth > 750) {
                cols = 3;
              } else if (constraints.maxWidth > 450) {
                cols = 2;
              } else {
                cols = 1;
              }
              return GridView.builder(
                padding: const EdgeInsets.all(6),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 2,
                  crossAxisSpacing: 2,
                  childAspectRatio: 1.45,
                ),
                itemCount: _filteredResults.length,
                itemBuilder: (context, index) {
                  final r = _filteredResults[index];
                  return _gridCard(r, _hasSearched, index);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Grid card ─────────────────────────────────────────────────────────

  Widget _gridCard(
    SearchResult result,
    bool showRelevance,
    int index,
  ) {
    final part = result.part;
    final resultColor = _resultColor(result);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 150 + (index * 20).clamp(0, 200)),
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.96 + 0.04 * v, child: child)),
      child: _HoverCard(
        onTap: () {
          _playSound('tap');
          _showPartDetails(part);
        },
        borderColor: _border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score bar
            if (showRelevance)
              Container(
                height: 2,
                color: resultColor,
              ),
            // Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      part.itemName.isNotEmpty
                          ? part.itemName
                          : part.legacyCode.isNotEmpty
                              ? part.legacyCode
                              : 'Unknown Part',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _text,
                          height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    if (part.legacyCode.isNotEmpty && part.itemName.isNotEmpty)
                      Text('# ${part.legacyCode}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: _textDim,
                              fontWeight: FontWeight.w500)),
                    // Description
                    if (part.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(part.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: _text.withValues(alpha: 0.6),
                              height: 1.35)),
                    ],
                    // Match reasons
                    if (showRelevance && result.matchReasons.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                              left: BorderSide(color: resultColor, width: 2)),
                          color: resultColor.withValues(alpha: 0.06),
                        ),
                        child: Text(
                          result.matchReasons.take(3).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              color: resultColor,
                              fontWeight: FontWeight.w500,
                              height: 1.3),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Meta
                    if (part.manufacturer.isNotEmpty) _chip(part.manufacturer),
                    if (part.manufacturerPartNumber.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: _chip(part.manufacturerPartNumber)),
                    if (part.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          Container(width: 4, height: 4, color: Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(part.location,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.orange,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    const SizedBox(height: 6),
                    // Price + score
                    Row(children: [
                      if (part.unitCost > 0)
                        Text('\$${part.unitCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                color: Color(0xFF22C55E),
                                fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (showRelevance)
                        Text(result.displayLabel,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: resultColor)),
                    ]),
                  ],
                ),
              ),
            ),
            // Add-to-list strip
            InkWell(
              onTap: () {
                _playSound('tap');
                if (!_authService.isLoggedIn) {
                  _showNotification('Sign in to add parts to lists',
                      icon: Icons.login);
                  return;
                }
                _showAddToListModal(part);
              },
              child: Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _border))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add, size: 14, color: _textDim),
                      SizedBox(width: 4),
                      Text('ADD TO LIST',
                          style: TextStyle(
                              fontSize: 12,
                              color: _textDim,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: _border,
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: _textDim),
              overflow: TextOverflow.ellipsis),
        ),
      ),
    ]);
  }

  Color _scoreColor(double score) {
    if (score >= 90) return const Color(0xFF22C55E);
    if (score >= 70) return _accent;
    if (score >= 50) return Colors.orange;
    return _textDim;
  }

  Color _resultColor(SearchResult result) {
    return switch (result.kind) {
      SearchResultKind.exact => const Color(0xFF22C55E),
      SearchResultKind.ai => _scoreColor(result.displayRelevance ?? 0),
      SearchResultKind.local => _textDim,
    };
  }

  // ── Filter drawer ─────────────────────────────────────────────────────

  Widget _buildFilterOverlay() {
    final drawerWidth = _filterDrawerWidth(context);

    return Stack(children: [
      GestureDetector(
        onTap: () => setState(() => _filterDrawerOpen = false),
        child: Container(color: Colors.black54),
      ),
      Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: SizedBox(
          width: drawerWidth,
          child: Material(
            color: _surfaceRaised,
            child: Column(children: [
              // Header
              Container(
                padding: EdgeInsets.fromLTRB(
                  _filterScaled(18),
                  _filterScaled(14),
                  _filterScaled(8),
                  _filterScaled(14),
                ),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: _border))),
                child: SafeArea(
                  bottom: false,
                  child: Row(children: [
                    Icon(Icons.tune, size: _filterScaled(16), color: _accent),
                    SizedBox(width: _filterScaled(8)),
                    Text('FILTERS',
                        style: TextStyle(
                            fontSize: _filterScaled(11),
                            fontWeight: FontWeight.w700,
                            color: _text,
                            letterSpacing: 2)),
                    const Spacer(),
                    if (_totalActiveFilters > 0)
                      TextButton(
                        onPressed: _clearAllFilters,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: _filterScaled(10),
                            vertical: _filterScaled(6),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('CLEAR',
                            style: TextStyle(
                                fontSize: _filterScaled(9),
                                color: _accent,
                                fontWeight: FontWeight.w700)),
                      ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _filterDrawerOpen = false),
                      padding: EdgeInsets.all(_filterScaled(4)),
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close,
                          size: _filterScaled(18), color: _textDim),
                    ),
                  ]),
                ),
              ),
              // Count
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _filterScaled(18),
                  vertical: _filterScaled(8),
                ),
                color: _surface,
                child: Row(children: [
                  Text('${_filteredResults.length}',
                      style: TextStyle(
                          fontSize: _filterScaled(13),
                          fontWeight: FontWeight.w800,
                          color: _accent)),
                  SizedBox(width: _filterScaled(5)),
                  Text('of ${_searchResults.length}',
                      style: TextStyle(
                          fontSize: _filterScaled(10), color: _textDim)),
                ]),
              ),
              // Sections
              Expanded(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView(
                    padding: EdgeInsets.all(_filterScaled(10)),
                    children: [
                      _multiSelect(
                        label: 'W Part Numbers',
                        icon: Icons.tag,
                        controller: _wPartNumberSearchController,
                        selected: _selectedWPartNumbers,
                        searchQuery: _wPartNumberSearchQuery,
                        onSearchChanged: (v) =>
                            setState(() => _wPartNumberSearchQuery = v),
                        getAvailable: _availableWParts,
                        onToggle: (v) {
                          setState(() => _selectedWPartNumbers.contains(v)
                              ? _selectedWPartNumbers.remove(v)
                              : _selectedWPartNumbers.add(v));
                          _applyFilters();
                        },
                        onClear: () {
                          setState(() => _selectedWPartNumbers.clear());
                          _applyFilters();
                        },
                      ),
                      SizedBox(height: _filterScaled(7)),
                      _multiSelect(
                        label: 'Manufacturer',
                        icon: Icons.business,
                        controller: _manufacturerSearchController,
                        selected: _selectedManufacturers,
                        searchQuery: _manufacturerSearchQuery,
                        onSearchChanged: (v) =>
                            setState(() => _manufacturerSearchQuery = v),
                        getAvailable: _availableManufacturers,
                        onToggle: (v) {
                          setState(() => _selectedManufacturers.contains(v)
                              ? _selectedManufacturers.remove(v)
                              : _selectedManufacturers.add(v));
                          _applyFilters();
                        },
                        onClear: () {
                          setState(() => _selectedManufacturers.clear());
                          _applyFilters();
                        },
                      ),
                      SizedBox(height: _filterScaled(7)),
                      _multiSelect(
                        label: 'Legacy Part #',
                        icon: Icons.history,
                        controller: _legacyCodeSearchController,
                        selected: _selectedLegacyCodes,
                        searchQuery: _legacyCodeSearchQuery,
                        onSearchChanged: (v) =>
                            setState(() => _legacyCodeSearchQuery = v),
                        getAvailable: _availableLegacyCodes,
                        onToggle: (v) {
                          setState(() => _selectedLegacyCodes.contains(v)
                              ? _selectedLegacyCodes.remove(v)
                              : _selectedLegacyCodes.add(v));
                          _applyFilters();
                        },
                        onClear: () {
                          setState(() => _selectedLegacyCodes.clear());
                          _applyFilters();
                        },
                      ),
                      SizedBox(height: _filterScaled(7)),
                      for (final field in _activeFilters.keys) ...[
                        _textFilter(field),
                        SizedBox(height: _filterScaled(7)),
                      ],
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ── Available options helpers ─────────────────────────────────────────

  List<String> _availableWParts() {
    final all = _filterService.options(
      _searchResults,
      _filterState,
      PartFilterFacet.wPartNumber,
    );
    if (_wPartNumberSearchQuery.isEmpty) return all;
    return all
        .where((w) =>
            w.toLowerCase().contains(_wPartNumberSearchQuery.toLowerCase()))
        .toList();
  }

  List<String> _availableManufacturers() {
    final all = _filterService.options(
      _searchResults,
      _filterState,
      PartFilterFacet.manufacturer,
    );
    if (_manufacturerSearchQuery.isEmpty) return all;
    return all
        .where((m) =>
            m.toLowerCase().contains(_manufacturerSearchQuery.toLowerCase()))
        .toList();
  }

  List<String> _availableLegacyCodes() {
    final all = _filterService.options(
      _searchResults,
      _filterState,
      PartFilterFacet.legacyCode,
    );
    if (_legacyCodeSearchQuery.isEmpty) return all;
    return all
        .where((m) =>
            m.toLowerCase().contains(_legacyCodeSearchQuery.toLowerCase()))
        .toList();
  }

  // ── Reusable multi-select widget ──────────────────────────────────────

  Widget _multiSelect({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required Set<String> selected,
    required String searchQuery,
    required ValueChanged<String> onSearchChanged,
    required List<String> Function() getAvailable,
    required ValueChanged<String> onToggle,
    required VoidCallback onClear,
  }) {
    final available = getAvailable();
    final active = selected.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(
            color: active ? _accent.withValues(alpha: 0.3) : _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: EdgeInsets.fromLTRB(
            _filterScaled(10),
            _filterScaled(8),
            _filterScaled(6),
            _filterScaled(8),
          ),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border))),
          child: Row(children: [
            Icon(icon,
                size: _filterScaled(12), color: active ? _accent : _textDim),
            SizedBox(width: _filterScaled(6)),
            Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: _filterScaled(9),
                    fontWeight: FontWeight.w700,
                    color: active ? _accent : _textDim,
                    letterSpacing: 1)),
            const Spacer(),
            if (active) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _filterScaled(5),
                  vertical: _filterScaled(2),
                ),
                color: _accent,
                child: Text('${selected.length}',
                    style: TextStyle(
                        fontSize: _filterScaled(8),
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: _filterScaled(4)),
              InkWell(
                onTap: () {
                  _playSound('tap');
                  onClear();
                },
                child: Padding(
                    padding: EdgeInsets.all(_filterScaled(3)),
                    child: Icon(Icons.close,
                        size: _filterScaled(10), color: _textDim)),
              ),
            ],
          ]),
        ),
        // Search
        Container(
          height: _filterScaled(30),
          margin: EdgeInsets.all(_filterScaled(6)),
          color: _surfaceRaised,
          child: TextField(
            controller: controller,
            style: TextStyle(color: _text, fontSize: _filterScaled(10)),
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(
                  fontSize: _filterScaled(9), color: const Color(0xFF444444)),
              prefixIcon: Icon(Icons.search,
                  size: _filterScaled(12), color: const Color(0xFF444444)),
              isDense: true,
              prefixIconConstraints: BoxConstraints(
                minWidth: _filterScaled(24),
                minHeight: _filterScaled(24),
              ),
              contentPadding: EdgeInsets.symmetric(
                  horizontal: _filterScaled(8), vertical: _filterScaled(8)),
              border: InputBorder.none,
            ),
            onChanged: onSearchChanged,
          ),
        ),
        // Tags
        if (active)
          Padding(
            padding: EdgeInsets.fromLTRB(
              _filterScaled(6),
              0,
              _filterScaled(6),
              _filterScaled(6),
            ),
            child: Wrap(
              spacing: _filterScaled(4),
              runSpacing: _filterScaled(4),
              children: selected
                  .map((v) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _filterScaled(6),
                            vertical: _filterScaled(2)),
                        color: _accent,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(v,
                              style: TextStyle(
                                  fontSize: _filterScaled(8),
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(width: _filterScaled(3)),
                          InkWell(
                              onTap: () {
                                _playSound('tap');
                                onToggle(v);
                              },
                              child: Icon(Icons.close,
                                  size: _filterScaled(8),
                                  color: Colors.white70)),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        // List
        if (available.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: _filterScaled(140)),
            margin: EdgeInsets.fromLTRB(
              _filterScaled(6),
              0,
              _filterScaled(6),
              _filterScaled(6),
            ),
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final val = available[i];
                  final sel = selected.contains(val);
                  return InkWell(
                    onTap: () {
                      _playSound('tap');
                      onToggle(val);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: _filterScaled(8),
                          vertical: _filterScaled(6)),
                      decoration: BoxDecoration(
                        color: sel
                            ? _accent.withValues(alpha: 0.08)
                            : Colors.transparent,
                        border: Border(
                            bottom: BorderSide(
                                color: _border.withValues(alpha: 0.5))),
                      ),
                      child: Row(children: [
                        Container(
                          width: _filterScaled(14),
                          height: _filterScaled(14),
                          decoration: BoxDecoration(
                            color: sel ? _accent : Colors.transparent,
                            border: Border.all(
                                color: sel ? _accent : const Color(0xFF444444)),
                          ),
                          child: sel
                              ? Icon(Icons.check,
                                  size: _filterScaled(8), color: Colors.white)
                              : null,
                        ),
                        SizedBox(width: _filterScaled(6)),
                        Expanded(
                            child: Text(val,
                                style: TextStyle(
                                    fontSize: _filterScaled(10),
                                    color: sel ? _text : _textDim),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        if (available.isEmpty && searchQuery.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(
              _filterScaled(8),
              0,
              _filterScaled(8),
              _filterScaled(8),
            ),
            child: Text('No matches',
                style: TextStyle(
                    fontSize: _filterScaled(8),
                    color: _textDim.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }

  // ── Text tag filter ───────────────────────────────────────────────────

  Widget _textFilter(String field) {
    final tags = _activeFilters[field]!;
    final controller = _filterControllers[field]!;
    final active = tags.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(
            color: active ? _accent.withValues(alpha: 0.3) : _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            _filterScaled(10),
            _filterScaled(8),
            _filterScaled(6),
            _filterScaled(8),
          ),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border))),
          child: Row(children: [
            Text(_getFieldDisplayName(field).toUpperCase(),
                style: TextStyle(
                    fontSize: _filterScaled(9),
                    fontWeight: FontWeight.w700,
                    color: active ? _accent : _textDim,
                    letterSpacing: 1)),
            const Spacer(),
            if (active) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _filterScaled(5),
                  vertical: _filterScaled(2),
                ),
                color: _accent,
                child: Text('${tags.length}',
                    style: TextStyle(
                        fontSize: _filterScaled(8),
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: _filterScaled(4)),
              InkWell(
                onTap: () => _clearFieldFilters(field),
                child: Padding(
                    padding: EdgeInsets.all(_filterScaled(3)),
                    child: Icon(Icons.close,
                        size: _filterScaled(10), color: _textDim)),
              ),
            ],
          ]),
        ),
        Padding(
          padding: EdgeInsets.all(_filterScaled(6)),
          child: Row(children: [
            Expanded(
              child: SizedBox(
                height: _filterScaled(30),
                child: TextField(
                  controller: controller,
                  focusNode: _filterFocusNodes[field],
                  style: TextStyle(color: _text, fontSize: _filterScaled(10)),
                  decoration: InputDecoration(
                    hintText: 'Add filter...',
                    hintStyle: TextStyle(
                        fontSize: _filterScaled(9),
                        color: const Color(0xFF444444)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: _filterScaled(8),
                        vertical: _filterScaled(8)),
                    filled: true,
                    fillColor: _surfaceRaised,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) => _addFilter(field, v),
                ),
              ),
            ),
            SizedBox(width: _filterScaled(4)),
            InkWell(
              onTap: () => _addFilter(field, controller.text),
              child: Container(
                padding: EdgeInsets.all(_filterScaled(6)),
                color: _accent,
                child: Icon(Icons.add,
                    color: Colors.white, size: _filterScaled(12)),
              ),
            ),
          ]),
        ),
        if (active)
          Padding(
            padding: EdgeInsets.fromLTRB(
              _filterScaled(6),
              0,
              _filterScaled(6),
              _filterScaled(6),
            ),
            child: Wrap(
              spacing: _filterScaled(4),
              runSpacing: _filterScaled(4),
              children: tags
                  .map((tag) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _filterScaled(6),
                            vertical: _filterScaled(2)),
                        color: _accent.withValues(alpha: 0.25),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(tag,
                              style: TextStyle(
                                  fontSize: _filterScaled(8),
                                  color: _text,
                                  fontWeight: FontWeight.w500)),
                          SizedBox(width: _filterScaled(3)),
                          InkWell(
                              onTap: () => _removeFilter(field, tag),
                              child: Icon(Icons.close,
                                  size: _filterScaled(8),
                                  color: Colors.white70)),
                        ]),
                      ))
                  .toList(),
            ),
          ),
      ]),
    );
  }

  // ── Clear filters dialog ──────────────────────────────────────────────

  // ── Toast notification ────────────────────────────────────────────────

  Widget _buildToast() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _notificationAnimation,
        builder: (_, __) {
          if (_notificationMessage == null &&
              _notificationAnimation.value == 0) {
            return const SizedBox.shrink();
          }
          return Opacity(
            opacity: _notificationAnimation.value,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - _notificationAnimation.value)),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: _accent,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_notificationIcon ?? Icons.check_circle,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                        child: Text(_notificationMessage ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500))),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        if (_authService.isLoggedIn) {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ListsScreen()));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        color: Colors.white.withValues(alpha: 0.2),
                        child: const Text('VIEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Add-to-list modal ─────────────────────────────────────────────────

  void _showAddToListModal(MroPart part) {
    showDialog(
      context: context,
      builder: (ctx) => _AddToListModal(
        part: part,
        listService: _listService,
        onAdded: (listName) {
          _showNotification(
            'Added "${part.displayName}" to $listName',
            icon: Icons.playlist_add_check,
          );
        },
      ),
    );
  }

  // ── Part detail dialog ────────────────────────────────────────────────

  void _showPartDetails(MroPart part) {
    _playSound('tap');

    // Build all rows (every single field, always shown)
    final rows = <MapEntry<String, String>>[
      MapEntry('Item Name', part.itemName.isNotEmpty ? part.itemName : '—'),
      MapEntry(
          'Legacy Code', part.legacyCode.isNotEmpty ? part.legacyCode : '—'),
      MapEntry(
          'Description', part.description.isNotEmpty ? part.description : '—'),
      MapEntry('Manufacturer',
          part.manufacturer.isNotEmpty ? part.manufacturer : '—'),
      MapEntry(
          'Mfr Part #',
          part.manufacturerPartNumber.isNotEmpty
              ? part.manufacturerPartNumber
              : '—'),
      MapEntry('Supplier Part #',
          part.supplierPartNumber.isNotEmpty ? part.supplierPartNumber : '—'),
      MapEntry('Location', part.location.isNotEmpty ? part.location : '—'),
      MapEntry('Unit Cost',
          part.unitCost > 0 ? '\$${part.unitCost.toStringAsFixed(2)}' : '—'),
      MapEntry('Min', '${part.min}'),
      MapEntry('Max', '${part.max}'),
    ];

    // Add any additional/dynamic fields from the part
    for (final entry in part.additionalFields.entries) {
      rows.add(MapEntry(entry.key, entry.value.toString()));
    }

    // Build full copy string
    String fullCopyText() {
      final buf = StringBuffer();
      for (final r in rows) {
        buf.writeln('${r.key}: ${r.value}');
      }
      return buf.toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: _surfaceRaised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                      bottom:
                          BorderSide(color: _accent.withValues(alpha: 0.15))),
                ),
                child: Row(children: [
                  // Small accent dot
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _accent.withValues(alpha: 0.1),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.25)),
                    ),
                    child: Icon(Icons.precision_manufacturing,
                        color: _accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.displayName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          part.legacyCode.isNotEmpty
                              ? part.legacyCode
                              : 'No legacy code',
                          style: TextStyle(fontSize: 11, color: _textDim),
                        ),
                      ],
                    ),
                  ),
                  // Copy All button
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: fullCopyText()));
                      _showNotification('All fields copied to clipboard');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: _surface,
                        border: Border.all(color: _border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.copy_all, size: 13, color: _textDim),
                        const SizedBox(width: 4),
                        Text('COPY ALL',
                            style: TextStyle(
                                fontSize: 9,
                                color: _textDim,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: _textDim, size: 18),
                    splashRadius: 16,
                  ),
                ]),
              ),

              // ── Field rows (scrollable) ──
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                ),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    child: Column(
                      children: rows.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final row = entry.value;
                        final isEven = idx % 2 == 0;
                        return _detailRow(row.key, row.value, isEven);
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── Footer actions ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: const Border(top: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    if (part.unitCost > 0)
                      Text(
                        '\$${part.unitCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF22C55E)),
                      ),
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        _playSound('tap');
                        if (!_authService.isLoggedIn) {
                          _showNotification('Sign in to add parts',
                              icon: Icons.login);
                          return;
                        }
                        Navigator.pop(ctx);
                        _showAddToListModal(part);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _accent,
                        ),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.playlist_add,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'ADD TO LIST',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1),
                              ),
                            ]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, bool isEven) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isEven ? _surface : _surfaceRaised,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  color: _textDim,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13, color: _text, height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              _showNotification('Copied $label');
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.copy, size: 12, color: _textDim),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// Hover card with subtle border glow
// ═════════════════════════════════════════════════════════════════════════

class _HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color borderColor;

  const _HoverCard({
    required this.child,
    required this.onTap,
    required this.borderColor,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovered ? const Color(0xFF1E1E1E) : const Color(0xFF141414),
            border: Border.all(
              color: _hovered
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.6)
                  : widget.borderColor,
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Add-to-list modal widget ────────────────────────────────────────────

class _AddToListModal extends StatefulWidget {
  final MroPart part;
  final ListService listService;
  final void Function(String listName) onAdded;

  const _AddToListModal({
    required this.part,
    required this.listService,
    required this.onAdded,
  });

  @override
  State<_AddToListModal> createState() => _AddToListModalState();
}

class _AddToListModalState extends State<_AddToListModal> {
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _surface = Color(0xFF141414);
  static const Color _border = Color(0xFF222222);
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _text = Color(0xFFEAEAEA);
  static const Color _textDim = Color(0xFF777777);

  final _searchController = TextEditingController();
  final _newListController = TextEditingController();
  String _query = '';
  bool _showNewListField = false;

  @override
  void dispose() {
    _searchController.dispose();
    _newListController.dispose();
    super.dispose();
  }

  List<PartsList> get _filteredLists {
    final lists = widget.listService.lists;
    if (_query.isEmpty) return lists;
    final q = _query.toLowerCase();
    return lists.where((l) => l.name.toLowerCase().contains(q)).toList();
  }

  int _qtyInList(PartsList list) {
    return widget.listService.getQuantityInList(list.id, widget.part);
  }

  Future<void> _addToList(PartsList list) async {
    await widget.listService.addToList(list.id, widget.part);
    if (mounted) setState(() {});
    widget.onAdded(list.name);
  }

  Future<void> _createAndAdd() async {
    final name = _newListController.text.trim();
    if (name.isEmpty) return;
    final created = await widget.listService.createList(name);
    if (created != null) {
      await widget.listService.addToList(created.id, widget.part);
      widget.onAdded(created.name);
    }
    if (mounted) {
      _newListController.clear();
      setState(() => _showNewListField = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lists = _filteredLists;
    final partName = widget.part.displayName.isNotEmpty
        ? widget.part.displayName
        : 'Unknown Part';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _accent.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.playlist_add,
                        size: 16, color: _accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add to List',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _text)),
                        const SizedBox(height: 2),
                        Text(partName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 11, color: _textDim)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16, color: _textDim),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: _text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search lists...',
                  hintStyle: const TextStyle(color: _textDim, fontSize: 12),
                  prefixIcon:
                      const Icon(Icons.search, size: 16, color: _textDim),
                  filled: true,
                  fillColor: _bg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _accent, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Lists ──
            Flexible(
              child: lists.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _query.isNotEmpty
                            ? 'No lists matching "$_query"'
                            : 'No lists yet \u2014 create one below',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: _textDim),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      itemCount: lists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (ctx, i) {
                        final list = lists[i];
                        final qty = _qtyInList(list);
                        final isInList = qty > 0;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _addToList(list),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isInList
                                    ? _accent.withValues(alpha: 0.06)
                                    : _bg,
                                border: Border.all(
                                  color: isInList
                                      ? _accent.withValues(alpha: 0.25)
                                      : _border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // List icon
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: isInList
                                          ? _accent.withValues(alpha: 0.15)
                                          : _border,
                                    ),
                                    child: Icon(
                                      isInList
                                          ? Icons.checklist
                                          : Icons.list_alt,
                                      size: 14,
                                      color: isInList ? _accent : _textDim,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Name + item count
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(list.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isInList
                                                    ? _accent
                                                    : _text)),
                                        Text('${list.uniqueItemCount} items',
                                            style: const TextStyle(
                                                fontSize: 10, color: _textDim)),
                                      ],
                                    ),
                                  ),
                                  // Quantity badge or add icon
                                  if (isInList)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: _accent,
                                      ),
                                      child: Text('$qty',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700)),
                                    )
                                  else
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: _accent.withValues(alpha: 0.1),
                                      ),
                                      child: const Icon(Icons.add,
                                          size: 14, color: _accent),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Create new list / footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: _showNewListField
                  ? Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _newListController,
                          autofocus: true,
                          style: const TextStyle(color: _text, fontSize: 13),
                          onSubmitted: (_) => _createAndAdd(),
                          decoration: InputDecoration(
                            hintText: 'New list name...',
                            hintStyle:
                                const TextStyle(color: _textDim, fontSize: 12),
                            filled: true,
                            fillColor: _bg,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: _border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  const BorderSide(color: _accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _createAndAdd,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _accent,
                          ),
                          child: const Text('Create & Add',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _showNewListField = false),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close, size: 14, color: _textDim),
                        ),
                      ),
                    ])
                  : InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _showNewListField = true),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: _accent.withValues(alpha: 0.3)),
                          color: _accent.withValues(alpha: 0.05),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 14, color: _accent),
                            SizedBox(width: 6),
                            Text('Create New List',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _accent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
