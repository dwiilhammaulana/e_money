import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';

class DeeplinkPaymentData {
  final String merchantId;
  final String merchantName;
  final double amount;
  final String description;
  final String? reference;
  final String? callbackUrl;

  const DeeplinkPaymentData({
    required this.merchantId,
    required this.merchantName,
    required this.amount,
    required this.description,
    this.reference,
    this.callbackUrl,
  });

  factory DeeplinkPaymentData.fromUri(Uri uri) {
    final merchantId = uri.queryParameters['merchant_id']?.trim() ?? '';
    if (merchantId.isEmpty) {
      throw const FormatException('Merchant ID wajib diisi.');
    }

    final merchantName = uri.queryParameters['merchant_name']?.trim() ?? '';
    if (merchantName.isEmpty) {
      throw const FormatException('Nama merchant wajib diisi.');
    }

    final amountText = uri.queryParameters['amount']?.trim();
    final amount = amountText == null ? null : double.tryParse(amountText);
    if (amount == null || !amount.isFinite || amount <= 0) {
      throw const FormatException('Nominal pembayaran tidak valid.');
    }

    final description = uri.queryParameters['description']?.trim();

    return DeeplinkPaymentData(
      merchantId: merchantId,
      merchantName: merchantName,
      amount: amount,
      description: description == null || description.isEmpty
          ? 'Pembayaran ke $merchantName'
          : description,
      reference: _optionalParameter(uri, 'reference'),
      callbackUrl: _optionalParameter(uri, 'callback'),
    );
  }

  static String? _optionalParameter(Uri uri, String name) {
    final value = uri.queryParameters[name]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class DeeplinkService {
  final GoRouter _router;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;

  DeeplinkService(this._router) : _appLinks = AppLinks();

  Future<void> init() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  void _handleUri(Uri uri) {
    if (!_isPaymentLink(uri)) return;

    try {
      final data = DeeplinkPaymentData.fromUri(uri);
      _router.go('/pay', extra: data);
    } on FormatException catch (error) {
      _router.go('/pay', extra: error.message.toString());
    }
  }

  bool _isPaymentLink(Uri uri) {
    return (uri.scheme == 'dompetkampus' && uri.host == 'pay') ||
        (uri.scheme == 'https' &&
            uri.host == 'dompetkampus.app' &&
            uri.path.startsWith('/pay'));
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
  }
}
