import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/mro_part.dart';
import 'auth_service.dart';

/// Represents an item in a parts list with quantity
class ListItem {
  String partId;
  final String itemName;
  final String legacyCode;
  final String description;
  final String manufacturer;
  final String manufacturerPartNumber;
  final String supplierPartNumber;
  final String location;
  final double unitCost;
  int quantity;

  ListItem({
    required this.partId,
    required this.itemName,
    this.legacyCode = '',
    this.description = '',
    this.manufacturer = '',
    this.manufacturerPartNumber = '',
    this.supplierPartNumber = '',
    this.location = '',
    this.unitCost = 0.0,
    this.quantity = 1,
  });

  double get lineTotal => unitCost * quantity;

  Map<String, dynamic> toMap() => {
        'partId': partId,
        'itemName': itemName,
        'legacyCode': legacyCode,
        'description': description,
        'manufacturer': manufacturer,
        'manufacturerPartNumber': manufacturerPartNumber,
        'supplierPartNumber': supplierPartNumber,
        'location': location,
        'unitCost': unitCost,
        'quantity': quantity,
      };

  factory ListItem.fromMap(Map<String, dynamic> m) => ListItem(
        partId: m['partId'] ?? '',
        itemName: m['itemName'] ?? '',
        legacyCode: m['legacyCode'] ?? '',
        description: m['description'] ?? '',
        manufacturer: m['manufacturer'] ?? '',
        manufacturerPartNumber: m['manufacturerPartNumber'] ?? '',
        supplierPartNumber: m['supplierPartNumber'] ?? '',
        location: m['location'] ?? '',
        unitCost: (m['unitCost'] as num?)?.toDouble() ?? 0.0,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      );

  factory ListItem.fromPart(MroPart part, {int quantity = 1}) {
    return ListItem(
      partId: part.stableId,
      itemName: part.itemName,
      legacyCode: part.legacyCode,
      description: part.description,
      manufacturer: part.manufacturer,
      manufacturerPartNumber: part.manufacturerPartNumber,
      supplierPartNumber: part.supplierPartNumber,
      location: part.location,
      unitCost: part.unitCost,
      quantity: quantity,
    );
  }

  String get displayName => itemName.isNotEmpty ? itemName : legacyCode;

  /// Matches current stable IDs and the pre-migration item/MPN composite.
  /// Stored descriptive fields provide a safe fallback for records that were
  /// once persisted under a non-unique legacy number.
  bool matchesPart(MroPart part) {
    if (part.persistenceAliases.contains(partId)) return true;

    final savedItemName = itemName.trim();
    final savedMpn = manufacturerPartNumber.trim();
    if (savedItemName.isEmpty && savedMpn.isEmpty) return false;

    return savedItemName == part.itemName.trim() &&
        savedMpn == part.manufacturerPartNumber.trim();
  }
}

/// Represents a user-created parts list
class PartsList {
  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ListItem> items;

  PartsList({
    required this.id,
    required this.name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ListItem>? items,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        items = items ?? [];

  int get totalQuantity =>
      items.fold(0, (total, item) => total + item.quantity);
  int get uniqueItemCount => items.length;
  double get totalCost =>
      items.fold(0.0, (total, item) => total + item.lineTotal);

  bool containsPart(MroPart part) {
    return items.any((item) => item.matchesPart(part));
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'items': items.map((i) => i.toMap()).toList(),
      };

  factory PartsList.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PartsList(
      id: doc.id,
      name: d['name'] ?? 'Untitled',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: (d['items'] as List<dynamic>?)
              ?.map((e) => ListItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Service for managing user-created parts lists in Firestore.
/// Replaces the old CartService.
class ListService extends ChangeNotifier {
  static final ListService _instance = ListService._internal();
  factory ListService() => _instance;
  ListService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  List<PartsList> _lists = [];
  String? _activeListId;

  /// All user lists
  List<PartsList> get lists => List.unmodifiable(_lists);

  /// Currently active list (for quick-add from search)
  PartsList? get activeList {
    if (_activeListId == null) return _lists.isNotEmpty ? _lists.first : null;
    return _lists.where((l) => l.id == _activeListId).firstOrNull;
  }

  String? get activeListId => _activeListId;

  set activeListId(String? id) {
    _activeListId = id;
    notifyListeners();
  }

  /// Firestore collection ref for this user
  CollectionReference get _listsRef =>
      _firestore.collection('users').doc(_auth.uid).collection('lists');

  /// Load all lists from Firestore
  Future<void> loadLists() async {
    if (!_auth.isLoggedIn) {
      _lists = [];
      notifyListeners();
      return;
    }
    try {
      final snap = await _listsRef.orderBy('updatedAt', descending: true).get();
      _lists = snap.docs.map((d) => PartsList.fromDoc(d)).toList();

      // Set active list if none set
      if (_activeListId == null && _lists.isNotEmpty) {
        _activeListId = _lists.first.id;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading lists: $e');
    }
  }

  /// Create a new list
  Future<PartsList?> createList(String name) async {
    if (!_auth.isLoggedIn) return null;
    try {
      final newList = PartsList(
        id: '', // will be set after doc creation
        name: name.trim().isEmpty ? 'Untitled List' : name.trim(),
      );
      final docRef = await _listsRef.add(newList.toMap());
      final created = PartsList(
        id: docRef.id,
        name: newList.name,
        createdAt: newList.createdAt,
        updatedAt: newList.updatedAt,
        items: [],
      );
      _lists.insert(0, created);
      _activeListId = created.id;
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('Error creating list: $e');
      return null;
    }
  }

  /// Rename a list
  Future<void> renameList(String listId, String newName) async {
    try {
      await _listsRef.doc(listId).update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final idx = _lists.indexWhere((l) => l.id == listId);
      if (idx >= 0) {
        _lists[idx].name = newName.trim();
        _lists[idx].updatedAt = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error renaming list: $e');
    }
  }

  /// Delete a list
  Future<void> deleteList(String listId) async {
    try {
      await _listsRef.doc(listId).delete();
      _lists.removeWhere((l) => l.id == listId);
      if (_activeListId == listId) {
        _activeListId = _lists.isNotEmpty ? _lists.first.id : null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting list: $e');
    }
  }

  /// Add a part to a specific list
  Future<void> addToList(String listId, MroPart part,
      {int quantity = 1}) async {
    if (!_auth.isLoggedIn) {
      debugPrint('[ListService] addToList: user not logged in');
      return;
    }

    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) {
      debugPrint(
          '[ListService] addToList: list $listId not found in local state');
      return;
    }

    final list = _lists[idx];
    final partId = part.stableId;

    final existingIdx = list.items.indexWhere(
      (item) => item.matchesPart(part),
    );
    if (existingIdx >= 0) {
      list.items[existingIdx].quantity += quantity;
      // Migrate an old persisted alias the next time this list is saved.
      list.items[existingIdx].partId = partId;
    } else {
      list.items.add(ListItem.fromPart(part, quantity: quantity));
    }
    list.updatedAt = DateTime.now();

    // Save FIRST, notify after — prevents race with listeners
    await _saveList(listId);
    notifyListeners();
  }

  /// Add part to active list (convenience)
  Future<void> addToActiveList(MroPart part, {int quantity = 1}) async {
    final list = activeList;
    if (list == null) {
      // Auto-create a list
      final created = await createList('My Parts');
      if (created != null) {
        await addToList(created.id, part, quantity: quantity);
      }
      return;
    }
    await addToList(list.id, part, quantity: quantity);
  }

  /// Remove a part from a list
  Future<void> removeFromList(String listId, String partId) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;

    _lists[idx].items.removeWhere((i) => i.partId == partId);
    _lists[idx].updatedAt = DateTime.now();
    await _saveList(listId);
    notifyListeners();
  }

  /// Update quantity
  Future<void> updateQuantity(
      String listId, String partId, int quantity) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;

    final itemIdx = _lists[idx].items.indexWhere((i) => i.partId == partId);
    if (itemIdx < 0) return;

    if (quantity <= 0) {
      _lists[idx].items.removeAt(itemIdx);
    } else {
      _lists[idx].items[itemIdx].quantity = quantity;
    }
    _lists[idx].updatedAt = DateTime.now();
    await _saveList(listId);
    notifyListeners();
  }

  /// Check if a part is in the active list
  bool isInActiveList(MroPart part) {
    final list = activeList;
    if (list == null) return false;
    return list.containsPart(part);
  }

  /// Get quantity for a part in active list
  int getQuantityInActiveList(MroPart part) {
    final list = activeList;
    if (list == null) return 0;
    final item =
        list.items.where((listItem) => listItem.matchesPart(part)).firstOrNull;
    return item?.quantity ?? 0;
  }

  /// Get quantity for a part in a specific list
  int getQuantityInList(String listId, MroPart part) {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return 0;
    final item = _lists[idx]
        .items
        .where((listItem) => listItem.matchesPart(part))
        .firstOrNull;
    return item?.quantity ?? 0;
  }

  /// Clear all items from a list
  Future<void> clearList(String listId) async {
    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) return;
    _lists[idx].items.clear();
    _lists[idx].updatedAt = DateTime.now();
    await _saveList(listId);
    notifyListeners();
  }

  /// Persist list to Firestore
  Future<void> _saveList(String listId) async {
    if (!_auth.isLoggedIn) {
      debugPrint('[ListService] _saveList: user not logged in, skipping');
      return;
    }

    final idx = _lists.indexWhere((l) => l.id == listId);
    if (idx < 0) {
      debugPrint('[ListService] _saveList: list $listId not found');
      return;
    }

    final list = _lists[idx];
    final itemMaps = list.items.map((i) => i.toMap()).toList();

    debugPrint(
        '[ListService] _saveList: saving ${itemMaps.length} items to list "${list.name}" ($listId)');

    try {
      final docRef = _firestore
          .collection('users')
          .doc(_auth.uid)
          .collection('lists')
          .doc(listId);

      await docRef.set({
        'name': list.name,
        'items': itemMaps,
        'createdAt': Timestamp.fromDate(list.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false));

      debugPrint(
          '[ListService] _saveList: SUCCESS — ${itemMaps.length} items written');
    } catch (e, stack) {
      debugPrint('[ListService] _saveList ERROR: $e');
      debugPrint('[ListService] Stack: $stack');
    }
  }
}
