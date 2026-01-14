import 'dart:ui';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _workOrderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _nameController.dispose();
    _workOrderController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {});
  }

  void _showPrintDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.print,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Print Parts List',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDialogTextField(
                controller: _nameController,
                label: 'Name',
                hint: 'Enter your name',
                icon: Icons.person,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                controller: _workOrderController,
                label: 'Work Order',
                hint: 'Enter work order number',
                icon: Icons.assignment,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _printReceipt();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.print, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Print',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF00D9FF)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00D9FF)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  void _printReceipt() {
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy');
    final timeFormat = DateFormat('h:mm a');

    final name = _nameController.text.isNotEmpty ? _nameController.text : '—';
    final workOrder = _workOrderController.text.isNotEmpty
        ? _workOrderController.text
        : '—';

    final htmlContent =
        '''
<!DOCTYPE html>
<html>
<head>
  <title>Parts List - $workOrder</title>
  <style>
    @page { size: A4; margin: 0.4in; }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
      color: #000;
      font-size: 11px;
      line-height: 1.3;
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #000;
      padding-bottom: 8px;
      margin-bottom: 10px;
    }
    .logo { font-size: 16px; font-weight: bold; color: #000; }
    .info { text-align: right; font-size: 10px; color: #333; }
    .info-row {
      display: flex;
      justify-content: space-between;
      background: #f5f5f5;
      padding: 6px 10px;
      margin-bottom: 8px;
      border-radius: 4px;
    }
    .info-item { display: flex; gap: 6px; }
    .info-label { color: #666; font-size: 10px; }
    .info-value { font-weight: 600; font-size: 10px; color: #000; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
    thead { background: #333; }
    th {
      color: white;
      padding: 6px 8px;
      text-align: left;
      font-size: 9px;
      text-transform: uppercase;
      font-weight: 600;
    }
    td { padding: 5px 8px; border-bottom: 1px solid #ddd; font-size: 10px; }
    tr:nth-child(even) { background: #f9f9f9; }
    .location { 
      background: #eee;
      color: #333;
      padding: 2px 6px;
      border-radius: 3px;
      font-size: 9px;
      font-weight: 500;
    }
    .qty {
      background: #333;
      color: white;
      padding: 2px 8px;
      border-radius: 3px;
      font-weight: 600;
      text-align: center;
      display: inline-block;
    }
    .footer { margin-top: 20px; padding-top: 10px; border-top: 1px solid #ddd; }
    .sig-box { width: 50%; border-top: 1px solid #333; padding-top: 4px; margin-top: 30px; }
    .sig-label { font-size: 9px; color: #666; }
    .total-box {
      background: #f5f5f5;
      padding: 6px 10px;
      border-radius: 4px;
      text-align: right;
      font-size: 10px;
    }
    .total-box strong { color: #000; }
    @media print { body { padding: 0; } }
  </style>
</head>
<body>
  <div class="header">
    <div class="logo">MRO Parts List</div>
    <div class="info">${dateFormat.format(now)} ${timeFormat.format(now)}</div>
  </div>

  <div class="info-row">
    <div class="info-item">
      <span class="info-label">Name:</span>
      <span class="info-value">$name</span>
    </div>
    <div class="info-item">
      <span class="info-label">Work Order:</span>
      <span class="info-value">$workOrder</span>
    </div>
    <div class="info-item">
      <span class="info-label">Items:</span>
      <span class="info-value">${_cartService.uniqueItemCount} (${_cartService.itemCount} pcs)</span>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width: 5%">#</th>
        <th style="width: 25%">Part Number</th>
        <th style="width: 25%">Legacy</th>
        <th style="width: 35%">Location</th>
        <th style="width: 10%">Qty</th>
      </tr>
    </thead>
    <tbody>
      ${_buildTableRows()}
    </tbody>
  </table>

  <div class="total-box">
    <strong>Total: ${_cartService.itemCount} pcs</strong> (${_cartService.uniqueItemCount} unique items)
  </div>

  <div class="footer">
    <div class="sig-box">
      <div class="sig-label">Fulfilled By / Date</div>
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

  String _buildTableRows() {
    final buffer = StringBuffer();
    var index = 1;

    for (final item in _cartService.items) {
      final part = item.part;
      final partNumber = part.itemName.isNotEmpty
          ? part.itemName
          : (part.description.isNotEmpty ? part.description : '—');
      final legacy = part.legacyCode.isNotEmpty ? part.legacyCode : '—';
      final location = part.location.isNotEmpty
          ? '<span class="location">${_escapeHtml(part.location)}</span>'
          : '—';

      buffer.writeln('''
        <tr>
          <td>$index</td>
          <td>${_escapeHtml(partNumber)}</td>
          <td><strong>${_escapeHtml(legacy)}</strong></td>
          <td>$location</td>
          <td><span class="qty">${item.quantity}</span></td>
        </tr>
      ''');
      index++;
    }

    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Widget _buildGlassContainer({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
    double borderRadius = 20,
    double blur = 10,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                  Color(0xFF0F0F23),
                ],
              ),
            ),
          ),
          // Floating orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    const Color(0xFF6C63FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D9FF).withValues(alpha: 0.2),
                    const Color(0xFF00D9FF).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _cartService.isEmpty
                      ? _buildEmptyCart()
                      : _buildCartList(),
                ),
                if (!_cartService.isEmpty) _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.shopping_cart,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Parts Cart',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_cartService.uniqueItemCount} items • ${_cartService.itemCount} total qty',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!_cartService.isEmpty)
            IconButton(
              onPressed: _showClearCartDialog,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
              ),
              tooltip: 'Clear cart',
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: _buildGlassContainer(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withValues(alpha: 0.3),
                    const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 64,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add parts from search results to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Browse Parts',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _cartService.items.length,
      itemBuilder: (context, index) {
        final item = _cartService.items[index];
        return _buildCartItem(item, index);
      },
    );
  }

  Widget _buildCartItem(CartItem item, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + (index * 50).clamp(0, 300)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(20 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Item Name badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.part.itemName.isNotEmpty
                            ? item.part.itemName
                            : 'No Item Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Delete button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _cartService.removeFromCart(item.part);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Part details
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.part.legacyCode.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.tag,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Legacy: ${item.part.legacyCode}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (item.part.manufacturerPartNumber.isNotEmpty) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.qr_code,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'MPN: ${item.part.manufacturerPartNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (item.part.location.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.orange.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.part.location,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _cartService.decrementQuantity(item.part);
                          },
                          icon: const Icon(Icons.remove, size: 18),
                          color: Colors.white70,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _cartService.incrementQuantity(item.part);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          color: const Color(0xFF00D9FF),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Unit cost if available
              if (item.part.unitCost > 0) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.part.unitCost.toStringAsFixed(2)} × ${item.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    Text(
                      item.lineTotal.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00D9FF),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return _buildGlassContainer(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      borderRadius: 20,
      child: Column(
        children: [
          // Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Items:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
              Text(
                '${_cartService.itemCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_cartService.total > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Estimated Total:',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                Text(
                  '\$${_cartService.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF00D9FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Checkout button
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _showPrintDialog();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.print, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'Generate Parts List',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Clear Cart?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will remove all ${_cartService.itemCount} items from your cart.',
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
                        onTap: () {
                          _cartService.clearCart();
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.redAccent,
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
}
