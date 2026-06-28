import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/deeplink_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_logo.dart';

class PaymentDeeplinkPage extends StatelessWidget {
  final Object? data;

  const PaymentDeeplinkPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data is String) {
      return _ErrorView(message: data! as String);
    }

    if (data is! DeeplinkPaymentData) {
      return const _ErrorView(
        message: 'Data pembayaran tidak ditemukan atau tidak valid.',
      );
    }

    final payload = data! as DeeplinkPaymentData;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _Header(merchantName: payload.merchantName),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AmountSection(amount: payload.amount),
                  const SizedBox(height: 14),
                  _DetailSection(payload: payload),
                  const SizedBox(height: 14),
                  const _PaymentMethodSection(),
                  const SizedBox(height: 14),
                  const _SecurityNotice(),
                ],
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.paddingOf(context).bottom + 16,
            ),
            child: AppButton(
              label: 'Bayar ${CurrencyFormatter.format(payload.amount)}',
              icon: const Icon(
                Icons.lock_outline_rounded,
                size: 19,
                color: Colors.white,
              ),
              onPressed: () => context.go('/pin', extra: {
                'kind': 'deeplink',
                'amount': payload.amount,
                'description': payload.description,
                'merchantName': payload.merchantName,
                'merchantId': payload.merchantId,
                'reference': payload.reference,
                'callbackUrl': payload.callbackUrl,
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String merchantName;

  const _Header({required this.merchantName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.paddingOf(context).top + 6,
        16,
        14,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Kembali',
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const Expanded(
            child: Text(
              'Konfirmasi Pembayaran',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                merchantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountSection extends StatelessWidget {
  final double amount;

  const _AmountSection({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        children: [
          const Text(
            'Total pembayaran',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(amount),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final DeeplinkPaymentData payload;

  const _DetailSection({required this.payload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.shadowSoft,
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Merchant', value: payload.merchantName),
          const Divider(height: 1, color: AppColors.line2),
          _DetailRow(label: 'ID Merchant', value: payload.merchantId),
          const Divider(height: 1, color: AppColors.line2),
          _DetailRow(label: 'Keterangan', value: payload.description),
          if (payload.reference != null) ...[
            const Divider(height: 1, color: AppColors.line2),
            _DetailRow(label: 'Referensi', value: payload.reference!),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                color: AppColors.slate500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSection extends StatelessWidget {
  const _PaymentMethodSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: const Row(
        children: [
          AppLogo(size: 42),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dompet Jajan',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Saldo - pembayaran instan',
                  style: TextStyle(fontSize: 12.5, color: AppColors.slate500),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 21),
        ],
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined,
              color: AppColors.primary, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pembayaran akan diverifikasi menggunakan PIN dan metode 2FA akun Anda.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.redSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.link_off_rounded,
                  color: AppColors.red,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Link Pembayaran Tidak Valid',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.slate500,
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: 'Kembali ke Beranda',
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
