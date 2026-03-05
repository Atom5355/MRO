import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mro_part.dart';
import '../services/mro_data_service.dart';
import '../services/advanced_search_service.dart';
import '../services/ai_search_service.dart' show AISearchService, TokenUsage;
import '../services/cart_service.dart';
import 'cart_screen.dart';

/// Widget that adds white neon glow effect on hover
class HoverGlowWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;

  const HoverGlowWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = 16,
  });

  @override
  State<HoverGlowWrapper> createState() => _HoverGlowWrapperState();
}

class _HoverGlowWrapperState extends State<HoverGlowWrapper> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: _isHovering 
                  ? Colors.white.withValues(alpha: 0.6)
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  // Brand color - White Semi-Neon
  static const Color _maroonColor = Color(0xCCFFFFFF);
  
  final MroDataService _dataService = MroDataService();
  final AdvancedSearchService _searchService = AdvancedSearchService();
  final TextEditingController _searchController = TextEditingController();
  final AISearchService _aiSearchService = AISearchService();
  final CartService _cartService = CartService();

  List<SearchResult> _searchResults = [];
  List<SearchResult> _filteredResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  bool _hasSearched = false;
  bool _useAI = true;
  String? _aiInterpretation;
  TokenUsage? _tokenUsage;

  // Filter state
  bool _showFilters = true;
  final Map<String, List<String>> _activeFilters = {
    'description': [],
    'manufacturerPartNumber': [],
    'location': [],
  };
  final Map<String, TextEditingController> _filterControllers = {};
  final Map<String, FocusNode> _filterFocusNodes = {};

  // Manufacturer search filter state
  final TextEditingController _manufacturerSearchController =
      TextEditingController();
  final Set<String> _selectedManufacturers = {};
  String _manufacturerSearchQuery = '';

  // Legacy code search filter state
  final TextEditingController _legacyCodeSearchController =
      TextEditingController();
  final Set<String> _selectedLegacyCodes = {};
  String _legacyCodeSearchQuery = '';

    // W part number multi-select filter state
    final TextEditingController _wPartNumberSearchController =
      TextEditingController();
    final Set<String> _selectedWPartNumbers = {};
    String _wPartNumberSearchQuery = '';

  // Notification state
  String? _notificationMessage;
  IconData? _notificationIcon;
  late AnimationController _notificationController;
  late Animation<double> _notificationAnimation;

  // Animation controllers
  late AnimationController _backgroundController;
  late AnimationController _pulseController;
  late AnimationController _loadingController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize filter controllers and focus nodes
    for (final field in _activeFilters.keys) {
      _filterControllers[field] = TextEditingController();
      _filterFocusNodes[field] = FocusNode();
    }

    // Background animation
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Pulse animation for AI indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Loading animation
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();

    // Notification animation
    _notificationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _notificationAnimation = CurvedAnimation(
      parent: _notificationController,
      curve: Curves.easeOutCubic,
    );

    // Listen to cart changes
    _cartService.addListener(_onCartChanged);

    // Data should already be loaded by AppInitializer
    _initializeFromLoadedData();
  }

  void _onCartChanged() {
    setState(() {});
  }

  void _showNotification(String message, {IconData icon = Icons.check_circle}) {
    setState(() {
      _notificationMessage = message;
      _notificationIcon = icon;
    });
    _notificationController.forward(from: 0);

    // Auto-hide after 3 seconds
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
    _backgroundController.dispose();
    _pulseController.dispose();
    _loadingController.dispose();
    _notificationController.dispose();
    _manufacturerSearchController.dispose();
    _legacyCodeSearchController.dispose();
    _wPartNumberSearchController.dispose();
    _cartService.removeListener(_onCartChanged);
    for (final controller in _filterControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _filterFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _initializeFromLoadedData() {
    if (!_dataService.isLoaded) {
      // This shouldn't happen since AppInitializer should load data first
      setState(() {
        _error = 'Data not loaded. Please restart the app.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _searchResults = _dataService.parts
          .map((p) => SearchResult(part: p, score: 1.0, matchReasons: []))
          .toList();
      _applyFilters();
    });
  }

  void _playSound(String type) {
    // Haptic feedback for web/mobile
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

  void _applyFilters() {
    List<SearchResult> results = List.from(_searchResults);

    // Apply manufacturer filter (OR logic - matches ANY selected)
    if (_selectedManufacturers.isNotEmpty) {
      results = results.where((r) {
        return _selectedManufacturers.contains(r.part.manufacturer);
      }).toList();
    }

    // Apply legacy code filter (OR logic - matches ANY selected)
    if (_selectedLegacyCodes.isNotEmpty) {
      results = results.where((r) {
        return _selectedLegacyCodes.contains(r.part.legacyCode);
      }).toList();
    }

    if (_selectedWPartNumbers.isNotEmpty) {
      results = results.where((r) {
        final partWNumbers = _extractWPartNumbers(r.part);
        return partWNumbers.any(_selectedWPartNumbers.contains);
      }).toList();
    }

    // Apply other filters (AND logic within each field)
    for (final entry in _activeFilters.entries) {
      final field = entry.key;
      final tags = entry.value;

      if (tags.isEmpty) continue;

      results = results.where((r) {
        final fieldValue = _getFieldValue(r.part, field).toLowerCase();
        return tags.every((tag) => fieldValue.contains(tag.toLowerCase()));
      }).toList();
    }

    setState(() {
      _filteredResults = results;
    });
  }

  Set<String> _extractWPartNumbers(MroPart part) {
    final values = <String>{
      part.itemName.trim(),
      part.manufacturerPartNumber.trim(),
      part.supplierPartNumber.trim(),
    };

    return values
        .where((value) => value.isNotEmpty)
        .where((value) => value.toLowerCase().startsWith('w'))
        .toSet();
  }

  String _getFieldValue(MroPart part, String field) {
    switch (field) {
      case 'description':
        return part.description;
      case 'manufacturer':
        return part.manufacturer;
      case 'manufacturerPartNumber':
        return part.manufacturerPartNumber;
      case 'location':
        return part.location;
      default:
        return '';
    }
  }

  String _getFieldDisplayName(String field) {
    switch (field) {
      case 'description':
        return 'Description';
      case 'manufacturer':
        return 'Manufacturer';
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
    final normalizedTag = tag.trim().toLowerCase();

    if (!_activeFilters[field]!.contains(normalizedTag)) {
      setState(() {
        _activeFilters[field]!.add(normalizedTag);
      });
      _filterControllers[field]?.clear();
      _applyFilters();
    }
    // Keep focus in the input field for quick tag entry
    Future.microtask(() {
      _filterFocusNodes[field]?.requestFocus();
    });
  }

  void _clearFieldFilters(String field) {
    if (_activeFilters[field]!.isEmpty) return;
    _playSound('tap');
    setState(() {
      _activeFilters[field]!.clear();
    });
    _applyFilters();
  }

  void _removeFilter(String field, String tag) {
    _playSound('tap');
    setState(() {
      _activeFilters[field]!.remove(tag);
    });
    _applyFilters();
  }

  void _clearAllFilters() {
    _playSound('tap');
    setState(() {
      for (final field in _activeFilters.keys) {
        _activeFilters[field]!.clear();
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

  int get _totalActiveFilters {
    return _activeFilters.values.fold(0, (sum, tags) => sum + tags.length) +
        _selectedManufacturers.length +
      _selectedLegacyCodes.length +
      _selectedWPartNumbers.length;
  }

  Future<void> _confirmAndSearch(String query) async {
    if (_totalActiveFilters > 0) {
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => _buildClearFiltersDialog(),
      );
      if (shouldClear == true) {
        _clearAllFilters();
      } else if (shouldClear == null) {
        return; // Cancelled
      }
    }
    _performSearch(query);
  }

  Widget _buildClearFiltersDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(24),
        borderRadius: 20,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _maroonColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.filter_alt_off,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Clear Filters?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have $_totalActiveFilters active filter${_totalActiveFilters == 1 ? '' : 's'}. Would you like to clear them before searching?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _maroonColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Keep Filters',
                              style: TextStyle(
                                color: _maroonColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context, true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _maroonColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (_isSearching) return;
    _playSound('search');

    setState(() {
      _isSearching = true;
      _hasSearched = query.isNotEmpty;
      _aiInterpretation = null;
      _tokenUsage = null;
    });

    try {
      if (query.isEmpty) {
        setState(() {
          _searchResults = _dataService.parts
              .map((p) => SearchResult(part: p, score: 1.0, matchReasons: []))
              .toList();
        });
      } else if (_useAI && _aiSearchService.isAvailable) {
        final result = await _aiSearchService.search(_dataService.parts, query);
        setState(() {
          _searchResults = result.results;
          if (result.aiInterpretation != null) {
            _aiInterpretation = result.aiInterpretation!.interpretation;
          }
          _tokenUsage = result.tokenUsage;
        });
      } else {
        setState(() {
          _searchResults = _searchService.search(_dataService.parts, query);
        });
      }
      _applyFilters();
      _playSound('success');
    } catch (e) {
      setState(() {
        _searchResults = _searchService.search(_dataService.parts, query);
      });
      _applyFilters();
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Solid background with falling snow
          _buildAnimatedBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                Expanded(
                  child: Row(
                    children: [
                      if (_showFilters) _buildFilterPanel(),
                      Expanded(child: _buildContent()),
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

  Widget _buildAnimatedBackground() {
    return Stack(
      children: [
        // Solid charcoal background
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2A2A2A), // Dark gray/charcoal
          ),
        ),
        // Falling snow animation
        ...List.generate(30, (index) {
          final random = math.Random(index);
          final delay = random.nextDouble() * 5;
          final duration = 8 + random.nextDouble() * 4;
          final startX = random.nextDouble();
          final size = 2 + random.nextDouble() * 3;
          final opacity = 0.3 + random.nextDouble() * 0.4;
          
          return AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              final progress = (_backgroundController.value * duration + delay) % duration / duration;
              final y = progress;
              final drift = math.sin(progress * math.pi * 2 * (1 + index % 3)) * 30;
              
              return Positioned(
                left: MediaQuery.of(context).size.width * startX + drift,
                top: MediaQuery.of(context).size.height * y,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double borderRadius = 20,
  }) {
    return Container(
      margin: margin,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: const Color(0xFF171B21),
          border: Border.all(
            color: const Color(0xFF2A303A),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          // Logo and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _maroonColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF505050).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.precision_manufacturing,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MRO Engine',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '${_dataService.parts.length} parts',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // AI Toggle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _useAI ? _pulseAnimation.value : 1.0,
                child: _buildGlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  borderRadius: 30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: _useAI,
                        onChanged: (v) {
                          _playSound('tap');
                          setState(() => _useAI = v);
                        },
                        activeThumbColor: _maroonColor,
                        activeTrackColor: _maroonColor.withValues(alpha: 0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _useAI
                              ? _maroonColor
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: _useAI ? Colors.white : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _useAI ? Colors.white : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Cart button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _playSound('tap');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: _buildGlassContainer(
                padding: const EdgeInsets.all(12),
                borderRadius: 16,
                child: Stack(
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      color: _cartService.isEmpty
                          ? Colors.white54
                          : _maroonColor,
                      size: 24,
                    ),
                    if (_cartService.itemCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: _maroonColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '${_cartService.itemCount > 99 ? '99+' : _cartService.itemCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          _buildGlassContainer(
            borderRadius: 30,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _confirmAndSearch,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: _useAI
                          ? 'Ask anything: "2hp motor for conveyor"...'
                          : 'Search parts, manufacturers, MPN...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      prefixIcon: _isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    _maroonColor,
                                  ),
                                ),
                              ),
                            )
                          : Icon(
                              _useAI ? Icons.auto_awesome : Icons.search,
                              color: _useAI
                                  ? _maroonColor
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSearching
                          ? null
                          : () => _confirmAndSearch(_searchController.text),
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: _maroonColor,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF505050,
                              ).withValues(alpha: 0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_useAI) ...[
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // AI interpretation banner
          if (_aiInterpretation != null && _useAI)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 12),
              child: _buildGlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                borderRadius: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _maroonColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _aiInterpretation!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Token usage indicator
          if (_tokenUsage != null && _useAI)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 8),
              child: _buildGlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                borderRadius: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.token,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Input: ${_tokenUsage!.inputTokens.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Output: ${_tokenUsage!.outputTokens.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 12,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.attach_money,
                      color: _maroonColor,
                      size: 14,
                    ),
                    Text(
                      '\$${_tokenUsage!.cost.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _maroonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 252,
      margin: const EdgeInsets.only(left: 10, bottom: 10),
      child: Column(
        children: [
          Expanded(
            child: _buildGlassContainer(
              borderRadius: 20,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _maroonColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.filter_list,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (_totalActiveFilters > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _maroonColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_totalActiveFilters',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _clearAllFilters,
                            icon: Icon(
                              Icons.clear_all,
                              size: 20,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                            tooltip: 'Clear all',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => _showFilters = false),
                          icon: Icon(
                            Icons.chevron_left,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Results count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF505050).withValues(alpha: 0.1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2,
                          size: 16,
                          color: _maroonColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_filteredResults.length} results',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _maroonColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_filteredResults.length != _searchResults.length)
                          Text(
                            ' of ${_searchResults.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Filter fields
                  _buildWPartNumberQuickFilter(),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          _buildManufacturerFilter(),
                          _buildLegacyCodeFilter(),
                          for (final field in _activeFilters.keys)
                            _buildFilterField(field),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Notification box
          _buildNotificationBox(),
        ],
      ),
    );
  }

  Widget _buildWPartNumberQuickFilter() {
    final hasSelections = _selectedWPartNumbers.isNotEmpty;

    List<SearchResult> resultsForWList = List.from(_searchResults);

    if (_selectedManufacturers.isNotEmpty) {
      resultsForWList = resultsForWList.where((r) {
        return _selectedManufacturers.contains(r.part.manufacturer);
      }).toList();
    }

    if (_selectedLegacyCodes.isNotEmpty) {
      resultsForWList = resultsForWList.where((r) {
        return _selectedLegacyCodes.contains(r.part.legacyCode);
      }).toList();
    }

    for (final entry in _activeFilters.entries) {
      final field = entry.key;
      final tags = entry.value;

      if (tags.isEmpty) continue;

      resultsForWList = resultsForWList.where((r) {
        final fieldValue = _getFieldValue(r.part, field).toLowerCase();
        return tags.every((tag) => fieldValue.contains(tag.toLowerCase()));
      }).toList();
    }

    final availableWPartNumbers =
        resultsForWList
            .expand((r) => _extractWPartNumbers(r.part))
            .toSet()
            .toList()
          ..sort();

    final filteredWPartNumbers = _wPartNumberSearchQuery.isEmpty
        ? availableWPartNumbers
        : availableWPartNumbers
              .where(
                (w) =>
                    w.toLowerCase().contains(_wPartNumberSearchQuery.toLowerCase()),
              )
              .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasSelections
            ? const Color(0xFF505050).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelections
              ? const Color(0xFF505050).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 14, color: _maroonColor),
                const SizedBox(width: 6),
                Text(
                  'W Part Numbers',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasSelections
                        ? _maroonColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (hasSelections) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedWPartNumbers.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _maroonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _playSound('tap');
                      setState(() {
                        _selectedWPartNumbers.clear();
                      });
                      _applyFilters();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              controller: _wPartNumberSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search W part numbers...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _maroonColor,
                    width: 1,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _wPartNumberSearchQuery = value;
                });
              },
            ),
          ),
          if (hasSelections)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedWPartNumbers.map((wPartNumber) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          wPartNumber,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _playSound('tap');
                            setState(() {
                              _selectedWPartNumbers.remove(wPartNumber);
                            });
                            _applyFilters();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (filteredWPartNumbers.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 132),
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredWPartNumbers.length,
                  itemBuilder: (context, index) {
                    final wPartNumber = filteredWPartNumbers[index];
                    final isSelected = _selectedWPartNumbers.contains(
                      wPartNumber,
                    );
                    return InkWell(
                      onTap: () {
                        _playSound('tap');
                        setState(() {
                          if (isSelected) {
                            _selectedWPartNumbers.remove(wPartNumber);
                          } else {
                            _selectedWPartNumbers.add(wPartNumber);
                          }
                        });
                        _applyFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF505050).withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _maroonColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? _maroonColor
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                wPartNumber,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (filteredWPartNumbers.isEmpty && _wPartNumberSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'No W part numbers found',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationBox() {
    return AnimatedBuilder(
      animation: _notificationAnimation,
      builder: (context, child) {
        if (_notificationMessage == null && _notificationAnimation.value == 0) {
          return const SizedBox.shrink();
        }
        return Opacity(
          opacity: _notificationAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - _notificationAnimation.value)),
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _maroonColor.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF505050).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _notificationIcon ?? Icons.check_circle,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _notificationMessage ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildManufacturerFilter() {
    final hasSelections = _selectedManufacturers.isNotEmpty;

    // Get manufacturers from results filtered by OTHER filters (not manufacturer)
    // This allows users to see what manufacturers are available after applying
    // location, description, etc. filters, while still being able to add multiple manufacturers
    List<SearchResult> resultsForManufacturerList = List.from(_searchResults);

    // Apply only non-manufacturer filters
    for (final entry in _activeFilters.entries) {
      final field = entry.key;
      final tags = entry.value;

      if (tags.isEmpty) continue;

      resultsForManufacturerList = resultsForManufacturerList.where((r) {
        final fieldValue = _getFieldValue(r.part, field).toLowerCase();
        return tags.every((tag) => fieldValue.contains(tag.toLowerCase()));
      }).toList();
    }

    final availableManufacturers =
        resultsForManufacturerList
            .map((r) => r.part.manufacturer)
            .where((m) => m.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // Filter manufacturers based on search query
    final filteredManufacturers = _manufacturerSearchQuery.isEmpty
        ? availableManufacturers
        : availableManufacturers
              .where(
                (m) => m.toLowerCase().contains(
                  _manufacturerSearchQuery.toLowerCase(),
                ),
              )
              .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasSelections
            ? const Color(0xFF505050).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelections
              ? const Color(0xFF505050).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                const Icon(Icons.business, size: 14, color: _maroonColor),
                const SizedBox(width: 6),
                Text(
                  'Manufacturer',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasSelections
                        ? _maroonColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (hasSelections) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedManufacturers.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _maroonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _playSound('tap');
                      setState(() {
                        _selectedManufacturers.clear();
                      });
                      _applyFilters();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              controller: _manufacturerSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search manufacturers...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _maroonColor,
                    width: 1,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _manufacturerSearchQuery = value;
                });
              },
            ),
          ),
          // Selected manufacturers (chips)
          if (hasSelections)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedManufacturers.map((manufacturer) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          manufacturer,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _playSound('tap');
                            setState(() {
                              _selectedManufacturers.remove(manufacturer);
                            });
                            _applyFilters();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          // Manufacturer list with checkboxes
          if (filteredManufacturers.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 132),
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredManufacturers.length,
                  itemBuilder: (context, index) {
                    final manufacturer = filteredManufacturers[index];
                    final isSelected = _selectedManufacturers.contains(
                      manufacturer,
                    );
                    return InkWell(
                      onTap: () {
                        _playSound('tap');
                        setState(() {
                          if (isSelected) {
                            _selectedManufacturers.remove(manufacturer);
                          } else {
                            _selectedManufacturers.add(manufacturer);
                          }
                        });
                        _applyFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF505050).withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _maroonColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? _maroonColor
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                manufacturer,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (filteredManufacturers.isEmpty &&
              _manufacturerSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'No manufacturers found',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegacyCodeFilter() {
    final hasSelections = _selectedLegacyCodes.isNotEmpty;

    // Get legacy codes from results filtered by OTHER filters (not legacy code)
    List<SearchResult> resultsForLegacyCodeList = List.from(_searchResults);

    // Apply only non-legacy-code filters
    if (_selectedManufacturers.isNotEmpty) {
      resultsForLegacyCodeList = resultsForLegacyCodeList.where((r) {
        return _selectedManufacturers.contains(r.part.manufacturer);
      }).toList();
    }

    for (final entry in _activeFilters.entries) {
      final field = entry.key;
      final tags = entry.value;

      if (tags.isEmpty) continue;

      resultsForLegacyCodeList = resultsForLegacyCodeList.where((r) {
        final fieldValue = _getFieldValue(r.part, field).toLowerCase();
        return tags.every((tag) => fieldValue.contains(tag.toLowerCase()));
      }).toList();
    }

    final availableLegacyCodes =
        resultsForLegacyCodeList
            .map((r) => r.part.legacyCode)
            .where((m) => m.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    // Filter legacy codes based on search query
    final filteredLegacyCodes = _legacyCodeSearchQuery.isEmpty
        ? availableLegacyCodes
        : availableLegacyCodes
              .where(
                (m) => m.toLowerCase().contains(
                  _legacyCodeSearchQuery.toLowerCase(),
                ),
              )
              .toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: hasSelections
            ? const Color(0xFF505050).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSelections
              ? const Color(0xFF505050).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                const Icon(Icons.tag, size: 14, color: _maroonColor),
                const SizedBox(width: 6),
                Text(
                  'Legacy Part #',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hasSelections
                        ? _maroonColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (hasSelections) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedLegacyCodes.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _maroonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      _playSound('tap');
                      setState(() {
                        _selectedLegacyCodes.clear();
                      });
                      _applyFilters();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Search input
          Padding(
            padding: const EdgeInsets.all(6),
            child: TextField(
              controller: _legacyCodeSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search legacy part numbers...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: _maroonColor,
                    width: 1,
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _legacyCodeSearchQuery = value;
                });
              },
            ),
          ),
          // Selected legacy codes (chips)
          if (hasSelections)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedLegacyCodes.map((legacyCode) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          legacyCode,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            _playSound('tap');
                            setState(() {
                              _selectedLegacyCodes.remove(legacyCode);
                            });
                            _applyFilters();
                          },
                          child: const Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          // Legacy code list with checkboxes
          if (filteredLegacyCodes.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 132),
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredLegacyCodes.length,
                  itemBuilder: (context, index) {
                    final legacyCode = filteredLegacyCodes[index];
                    final isSelected = _selectedLegacyCodes.contains(legacyCode);
                    return InkWell(
                      onTap: () {
                        _playSound('tap');
                        setState(() {
                          if (isSelected) {
                            _selectedLegacyCodes.remove(legacyCode);
                          } else {
                            _selectedLegacyCodes.add(legacyCode);
                          }
                        });
                        _applyFilters();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF505050).withValues(alpha: 0.2)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _maroonColor
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? _maroonColor
                                      : Colors.white.withValues(alpha: 0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                legacyCode,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.7),
                                  fontWeight: isSelected
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (filteredLegacyCodes.isEmpty && _legacyCodeSearchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'No legacy codes found',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterField(String field) {
    final tags = _activeFilters[field]!;
    final controller = _filterControllers[field]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tags.isNotEmpty
            ? const Color(0xFF505050).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tags.isNotEmpty
              ? const Color(0xFF505050).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                Text(
                  _getFieldDisplayName(field),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: tags.isNotEmpty
                        ? _maroonColor
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                if (tags.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _maroonColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tags.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: _maroonColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _clearFieldFilters(field),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Input
          Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: _filterFocusNodes[field],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add filter...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: _maroonColor,
                          width: 1,
                        ),
                      ),
                    ),
                    onSubmitted: (value) => _addFilter(field, value),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _addFilter(field, controller.text),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _maroonColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tags
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map((tag) => _buildFilterTag(field, tag))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTag(String field, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _maroonColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _maroonColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _removeFilter(field, tag),
            child: const Icon(Icons.close, size: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _loadingController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _loadingController.value * 2 * math.pi,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _maroonColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.precision_manufacturing,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Loading MRO Database...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Error Loading Data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredResults.isEmpty && (_hasSearched || _totalActiveFilters > 0)) {
      return Center(
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _maroonColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Results Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _totalActiveFilters > 0
                    ? 'Try removing some filters'
                    : 'Try a different search',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              if (_totalActiveFilters > 0) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, color: _maroonColor),
                  label: const Text(
                    'Clear Filters',
                    style: TextStyle(color: _maroonColor),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Results header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              if (!_showFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _showFilters = true),
                      borderRadius: BorderRadius.circular(12),
                      child: _buildGlassContainer(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        borderRadius: 12,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.filter_list,
                              size: 16,
                              color: _totalActiveFilters > 0
                                  ? _maroonColor
                                  : Colors.white70,
                            ),
                            if (_totalActiveFilters > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                '$_totalActiveFilters',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _maroonColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                '${_filteredResults.length} results',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_hasSearched) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _maroonColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ranked by relevance',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Results list
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              itemCount: _filteredResults.length,
              itemBuilder: (context, index) {
                final result = _filteredResults[index];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 300 + (index * 50).clamp(0, 500),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _buildPartCard(
                    result.part,
                    result.score,
                    result.matchReasons,
                    _hasSearched,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartCard(
    MroPart part,
    double score,
    List<String> matchReasons,
    bool showRelevance,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: HoverGlowWrapper(
        onTap: () {
          _playSound('tap');
          _showPartDetails(part);
        },
        borderRadius: 16,
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Item Name badge
                  Flexible(
                    fit: FlexFit.loose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3D3D3D), Color(0xFF8B2020)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        part.itemName.isNotEmpty
                            ? part.itemName
                            : 'No Item Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 26,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Location
                  if (part.location.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 24,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            part.location,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Legacy code
              if (part.legacyCode.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.tag,
                      size: 28,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      part.legacyCode,
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              // Description
              if (part.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  part.description,
                  style: TextStyle(
                    fontSize: 26,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              // Info chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (part.manufacturer.isNotEmpty)
                    _buildInfoChip(Icons.business, part.manufacturer),
                  if (part.manufacturerPartNumber.isNotEmpty)
                    _buildInfoChip(
                      Icons.qr_code,
                      part.manufacturerPartNumber,
                    ),
                  if (part.unitCost > 0)
                    _buildInfoChip(
                      Icons.attach_money,
                      part.unitCost.toStringAsFixed(2),
                      chipColor: const Color(0xFF2E7D32),
                    ),
                ],
              ),
              // Match reasons
              if (showRelevance && matchReasons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF505050).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF505050).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 28,
                        color: _maroonColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          matchReasons.take(2).join(' • '),
                          style: const TextStyle(
                            fontSize: 22,
                            color: _maroonColor,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _getScoreGradient(score),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${score.toInt()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Add to Cart button
              const SizedBox(height: 12),
              _buildAddToCartButton(part),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getScoreGradient(double score) {
    if (score >= 90) return [const Color(0xFF00C853), const Color(0xFF00E676)];
    if (score >= 70) return [_maroonColor, _maroonColor];
    if (score >= 50) return [const Color(0xFFFF9800), const Color(0xFFFFB74D)];
    return [const Color(0xFF757575), const Color(0xFF9E9E9E)];
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? chipColor}) {
    final hasCustomColor = chipColor != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasCustomColor
            ? chipColor.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasCustomColor
              ? chipColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: hasCustomColor
                ? chipColor
                : Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 22,
              fontWeight: hasCustomColor ? FontWeight.w600 : FontWeight.normal,
              color: hasCustomColor
                  ? chipColor
                  : Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddToCartButton(MroPart part) {
    final isInCart = _cartService.isInCart(part);
    final quantity = _cartService.getQuantity(part);

    if (isInCart) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _maroonColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _maroonColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: _maroonColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'In Cart',
                    style: TextStyle(
                      color: _maroonColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _playSound('tap');
                            _cartService.decrementQuantity(part);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.remove,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _playSound('tap');
                            _cartService.incrementQuantity(part);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.add,
                              size: 14,
                              color: _maroonColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        _playSound('tap');
        _cartService.addToCart(part);
        final name = part.itemName.isNotEmpty
            ? part.itemName
            : part.legacyCode;
        _showNotification(
          'Added "$name" to cart',
          icon: Icons.add_shopping_cart,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _maroonColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF505050).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_shopping_cart,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text(
              'Add to Cart',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartDetails(MroPart part) {
    _playSound('tap');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _maroonColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.precision_manufacturing,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            part.itemName.isNotEmpty
                                ? part.itemName
                                : 'Part Details',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (part.legacyCode.isNotEmpty)
                            Text(
                              part.legacyCode,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_copy, size: 20),
                      color: _maroonColor,
                      tooltip: 'Copy All Info',
                      onPressed: () {
                        final buffer = StringBuffer();
                        buffer.writeln('Part Number: ${part.itemName}');
                        if (part.legacyCode.isNotEmpty) {
                          buffer.writeln('Legacy Code: ${part.legacyCode}');
                        }
                        if (part.description.isNotEmpty) {
                          buffer.writeln('Description: ${part.description}');
                        }
                        if (part.manufacturer.isNotEmpty) {
                          buffer.writeln('Manufacturer: ${part.manufacturer}');
                        }
                        if (part.manufacturerPartNumber.isNotEmpty) {
                          buffer.writeln('MPN: ${part.manufacturerPartNumber}');
                        }
                        if (part.location.isNotEmpty) {
                          buffer.writeln('Location: ${part.location}');
                        }
                        if (part.unitCost > 0) {
                          buffer.writeln(
                            'Unit Cost: ${part.unitCost.toStringAsFixed(2)}',
                          );
                        }
                        buffer.writeln('Min/Max: ${part.min} / ${part.max}');

                        Clipboard.setData(
                          ClipboardData(text: buffer.toString()),
                        );
                        _showNotification('Copied all part info to clipboard');
                      },
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (part.description.isNotEmpty) ...[
                  _buildDetailRow('Description', part.description),
                  const SizedBox(height: 12),
                ],
                if (part.manufacturer.isNotEmpty) ...[
                  _buildDetailRow('Manufacturer', part.manufacturer),
                  const SizedBox(height: 12),
                ],
                if (part.manufacturerPartNumber.isNotEmpty) ...[
                  _buildDetailRow('MPN', part.manufacturerPartNumber),
                  const SizedBox(height: 12),
                ],
                if (part.location.isNotEmpty) ...[
                  _buildDetailRow('Location', part.location),
                  const SizedBox(height: 12),
                ],
                if (part.unitCost > 0) ...[
                  _buildDetailRow(
                    'Unit Cost',
                    part.unitCost.toStringAsFixed(2),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow('Min/Max', '${part.min} / ${part.max}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            color: _maroonColor,
            tooltip: 'Copy $label',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _showNotification('Copied $label to clipboard');
            },
          ),
        ],
      ),
    );
  }
}
