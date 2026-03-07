import 'package:flutter/foundation.dart';
import '../models/mro_part.dart';

/// Represents an item in the cart with quantity
class CartItem {
  final MroPart part;
  int quantity;

  CartItem({required this.part, this.quantity = 1});

  /// Get a unique identifier for the cart item
  String get id => part.partId;

  /// Calculate line total
  double get lineTotal => part.unitCost * quantity;
}

/// Cart service to manage shopping cart state
class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final Map<String, CartItem> _items = {};

  /// Get all cart items
  List<CartItem> get items => _items.values.toList();

  /// Get total item count
  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  /// Get unique item count
  int get uniqueItemCount => _items.length;

  /// Check if cart is empty
  bool get isEmpty => _items.isEmpty;

  /// Get cart total
  double get total =>
      _items.values.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// Add a part to cart
  void addToCart(MroPart part, {int quantity = 1}) {
    final id = _getPartId(part);
    if (_items.containsKey(id)) {
      _items[id]!.quantity += quantity;
    } else {
      _items[id] = CartItem(part: part, quantity: quantity);
    }
    notifyListeners();
  }

  /// Remove a part from cart
  void removeFromCart(MroPart part) {
    final id = _getPartId(part);
    _items.remove(id);
    notifyListeners();
  }

  /// Update quantity for a part
  void updateQuantity(MroPart part, int quantity) {
    final id = _getPartId(part);
    if (_items.containsKey(id)) {
      if (quantity <= 0) {
        _items.remove(id);
      } else {
        _items[id]!.quantity = quantity;
      }
      notifyListeners();
    }
  }

  /// Increment quantity
  void incrementQuantity(MroPart part) {
    final id = _getPartId(part);
    if (_items.containsKey(id)) {
      _items[id]!.quantity++;
      notifyListeners();
    }
  }

  /// Decrement quantity
  void decrementQuantity(MroPart part) {
    final id = _getPartId(part);
    if (_items.containsKey(id)) {
      if (_items[id]!.quantity <= 1) {
        _items.remove(id);
      } else {
        _items[id]!.quantity--;
      }
      notifyListeners();
    }
  }

  /// Check if part is in cart
  bool isInCart(MroPart part) {
    return _items.containsKey(_getPartId(part));
  }

  /// Get quantity in cart for a part
  int getQuantity(MroPart part) {
    final id = _getPartId(part);
    return _items.containsKey(id) ? _items[id]!.quantity : 0;
  }

  /// Clear the cart
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  /// Get unique ID for a part
  String _getPartId(MroPart part) {
    return part.partId;
  }
}
