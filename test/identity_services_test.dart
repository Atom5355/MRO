import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/cart_service.dart';
import 'package:mro_engine/services/list_service.dart';

void main() {
  final first = MroPart(
    itemName: 'W100001',
    legacyCode: 'LEGACY-DUP',
    manufacturerPartNumber: 'MPN-A',
  );
  final second = MroPart(
    itemName: 'W100002',
    legacyCode: 'LEGACY-DUP',
    manufacturerPartNumber: 'MPN-B',
  );

  test('duplicate legacy numbers remain distinct cart entries', () {
    final cart = CartService()..clearCart();

    cart.addToCart(first);
    cart.addToCart(second);

    expect(cart.uniqueItemCount, 2);
    expect(
        cart.items.map((item) => item.id), containsAll(['W100001', 'W100002']));
    cart.clearCart();
  });

  test('new list items persist the stable ID and requested quantity', () {
    final item = ListItem.fromPart(first, quantity: 4);

    expect(item.partId, first.stableId);
    expect(item.quantity, 4);
  });

  test('saved item/MPN composite remains a persistence alias', () {
    final saved = ListItem(
      partId: 'W100001_MPN-A',
      itemName: 'W100001',
      manufacturerPartNumber: 'MPN-A',
    );

    expect(saved.matchesPart(first), isTrue);
    expect(saved.matchesPart(second), isFalse);
  });

  test('descriptive fields disambiguate an old legacy-keyed item', () {
    final saved = ListItem(
      partId: 'LEGACY-DUP',
      itemName: 'W100001',
      manufacturerPartNumber: 'MPN-A',
    );

    expect(saved.matchesPart(first), isTrue);
    expect(saved.matchesPart(second), isFalse);
  });
}
