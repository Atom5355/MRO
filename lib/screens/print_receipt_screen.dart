import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/cart_service.dart';

class PrintReceiptScreen extends StatefulWidget {
  const PrintReceiptScreen({super.key});

  @override
  State<PrintReceiptScreen> createState() => _PrintReceiptScreenState();
}

class _PrintReceiptScreenState extends State<PrintReceiptScreen> {
  final CartService _cartService = CartService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _workOrderController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _workOrderController.dispose();
    super.dispose();
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

    // Build compact HTML for printing
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
    .logo {
      font-size: 16px;
      font-weight: bold;
      color: #000;
    }
    .info {
      text-align: right;
      font-size: 10px;
      color: #333;
    }
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
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 8px;
    }
    thead { background: #333; }
    th {
      color: white;
      padding: 6px 8px;
      text-align: left;
      font-size: 9px;
      text-transform: uppercase;
      font-weight: 600;
    }
    td {
      padding: 5px 8px;
      border-bottom: 1px solid #ddd;
      font-size: 10px;
    }
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
    .footer {
      margin-top: 20px;
      padding-top: 10px;
      border-top: 1px solid #ddd;
    }
    .sig-box {
      width: 50%;
      border-top: 1px solid #333;
      padding-top: 4px;
      margin-top: 30px;
    }
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

    // Open in new window for printing
    final blob = html.Blob([htmlContent], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  String _buildTableRows() {
    final buffer = StringBuffer();
    var index = 1;

    for (final item in _cartService.items) {
      final part = item.part;
      // Part number uses the item name (W number)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0D0D0D),
                  Color(0xFF1A1A2E),
                  Color(0xFF16213E),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildPreview()),
                _buildPrintButton(),
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
              Icons.receipt_long,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parts List',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_cartService.uniqueItemCount} items • ${_cartService.itemCount} total pcs',
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Preview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_cartService.uniqueItemCount} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C63FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compact table preview
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D9FF)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '#',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Part #',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Legacy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Location',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            'Qty',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Data rows
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cartService.items.length,
                      itemBuilder: (context, index) {
                        final item = _cartService.items[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: index.isEven
                                ? Colors.grey.shade50
                                : Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item.part.itemName.isNotEmpty
                                      ? item.part.itemName
                                      : (item.part.description.isNotEmpty
                                            ? item.part.description
                                            : '—'),
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item.part.legacyCode.isNotEmpty
                                      ? item.part.legacyCode
                                      : '—',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: item.part.location.isNotEmpty
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          item.part.location,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.orange.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : const Text(
                                        '—',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF6C63FF),
                                          Color(0xFF00D9FF),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Summary
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_cartService.uniqueItemCount} unique items',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  'Total: ${_cartService.itemCount} pcs',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showPrintDialog,
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
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.print, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Print Parts List',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
