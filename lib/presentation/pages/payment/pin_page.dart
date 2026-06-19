import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/datasources/local/secure_storage_datasource.dart';
import '../../../injection/injection_container.dart';
import '../../blocs/auth/otp_bloc.dart';
import '../../blocs/payment/payment_bloc.dart';
import '../../widgets/code_input.dart';
import '../../widgets/feature_icon.dart';
import '../../widgets/pin_pad.dart';

enum _Step { pin, otp }

class PinPage extends StatefulWidget {
  final Map<String, dynamic> flowData;

  const PinPage({super.key, required this.flowData});

  @override
  State<PinPage> createState() => _PinPageState();
}

class _PinPageState extends State<PinPage> {
  _Step _step = _Step.pin;
  String _pin = '';
  String _otpCode = '';
  String _twoFaMethod = AppConstants.twoFaTotp;
  bool _busy = false;
  bool _sendingOtp = false;
  bool _hasError = false;
  int _resendSeconds = 0;
  Timer? _countdown;

  String get _kind => widget.flowData['kind'] as String? ?? '';

  String get _otpType => switch (_twoFaMethod) {
        AppConstants.twoFaSmtp => AppConstants.otpTypeEmail,
        AppConstants.twoFaNotif => AppConstants.otpTypeFirebase,
        _ => AppConstants.otpTypeTotp,
      };

  bool get _canResend =>
      _twoFaMethod == AppConstants.twoFaSmtp ||
      _twoFaMethod == AppConstants.twoFaNotif;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  void _onPinComplete(String pin) {
    if (pin.length != AppConstants.pinLength || _busy) return;

    setState(() => _busy = true);
    if (_kind == AppConstants.txnTopup) {
      context.read<PaymentBloc>().add(
            PaymentTopupRequested(
              (widget.flowData['amount'] as num).toDouble(),
            ),
          );
      return;
    }

    _prepareOtpStep();
  }

  Future<void> _prepareOtpStep() async {
    String? savedMethod;
    try {
      savedMethod = await sl<SecureStorageDatasource>().get2faMethod();
    } catch (_) {
      savedMethod = null;
    }

    if (!mounted) return;

    final method = switch (savedMethod) {
      AppConstants.twoFaSmtp => AppConstants.twoFaSmtp,
      AppConstants.twoFaNotif => AppConstants.twoFaNotif,
      _ => AppConstants.twoFaTotp,
    };

    setState(() {
      _twoFaMethod = method;
      _step = _Step.otp;
      _otpCode = '';
      _hasError = false;
      _busy = false;
    });

    if (_canResend) {
      _sendOtp();
    }
  }

  void _sendOtp() {
    if (_sendingOtp) return;

    setState(() => _sendingOtp = true);
    if (_twoFaMethod == AppConstants.twoFaSmtp) {
      context.read<OtpBloc>().add(OtpSendEmail());
    } else if (_twoFaMethod == AppConstants.twoFaNotif) {
      context.read<OtpBloc>().add(OtpSendFirebase());
    }
    _startResendTimer();
  }

  void _startResendTimer() {
    _countdown?.cancel();
    setState(() => _resendSeconds = AppConstants.otpResendSeconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _onOtpChanged(String value) {
    setState(() {
      _otpCode = value;
      _hasError = false;
    });
    if (value.length == AppConstants.otpLength && !_sendingOtp) {
      _submitPayment(value);
    }
  }

  void _submitPayment(String code) {
    if (_busy || code.length != AppConstants.otpLength) return;

    final flow = widget.flowData;
    final amount = (flow['amount'] as num?)?.toDouble();
    if (amount == null || amount <= 0) {
      _showError('Nominal transaksi tidak valid.');
      return;
    }

    late final String description;
    late final String recipientId;
    late final String channel;

    if (_kind == AppConstants.txnTransfer) {
      final recipient = flow['recipient'] as Map<String, dynamic>? ?? {};
      description = flow['note'] as String? ?? 'Transfer';
      recipientId = recipient['id'] as String? ?? '';
      channel = flow['channel'] as String? ?? 'dkg';
    } else if (_kind == AppConstants.txnPayment ||
        _kind == AppConstants.txnDeeplink) {
      description = flow['description'] as String? ?? 'Pembayaran QRIS';
      recipientId = flow['merchantId'] as String? ??
          flow['merchant_id'] as String? ??
          'merchant_001';
      channel = 'qris';
    } else {
      _showError('Jenis transaksi tidak dikenali.');
      return;
    }

    setState(() => _busy = true);
    context.read<PaymentBloc>().add(
          PaymentTransferRequested(
            amount: amount,
            description: description,
            recipientId: recipientId,
            channel: channel,
            otpCode: code,
            otpType: _otpType,
          ),
        );
  }

  void _showError(String message) {
    if (mounted) setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  void _handleBack() {
    if (_step == _Step.otp) {
      _countdown?.cancel();
      context.read<OtpBloc>().add(OtpReset());
      setState(() {
        _step = _Step.pin;
        _pin = '';
        _otpCode = '';
        _busy = false;
        _sendingOtp = false;
        _hasError = false;
        _resendSeconds = 0;
      });
    } else {
      context.go('/home');
    }
  }

  void _handlePaymentState(PaymentState state) {
    if (state is PaymentTransferSuccess) {
      final result = state.result;
      final isPayment =
          _kind == AppConstants.txnPayment || _kind == AppConstants.txnDeeplink;
      final reference = widget.flowData['reference'] as String?;
      context.go('/success', extra: {
        'title': isPayment ? 'Pembayaran berhasil' : 'Transfer berhasil',
        'subtitle': result.description,
        'amount': result.amount,
        'lines': [
          ['Jumlah', CurrencyFormatter.format(result.amount)],
          ['Saldo setelah', CurrencyFormatter.format(result.balanceAfter)],
          if (reference != null && reference.isNotEmpty)
            ['Referensi', reference],
          ['Ref', 'DKG${result.transactionId}'],
        ],
      });
    } else if (state is PaymentTopupSuccess) {
      context.go('/success', extra: {
        'title': 'Top up berhasil',
        'subtitle': 'Saldo kamu bertambah',
        'amount': state.amount,
        'lines': [
          ['Jumlah', CurrencyFormatter.format(state.amount)],
          ['Saldo sekarang', CurrencyFormatter.format(state.balance)],
        ],
      });
    } else if (state is PaymentInvalidOtp) {
      setState(() {
        _busy = false;
        _hasError = true;
        _otpCode = '';
      });
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _hasError = false);
      });
    } else if (state is PaymentInsufficientBalance) {
      _showError(
        'Saldo tidak cukup. Saldo tersedia ${CurrencyFormatter.format(state.balance)}.',
      );
    } else if (state is PaymentError) {
      _showError(state.message);
    }
  }

  void _handleOtpState(OtpState state) {
    if (state is OtpSent) {
      setState(() => _sendingOtp = false);
      if (_otpCode.length == AppConstants.otpLength) {
        _submitPayment(_otpCode);
      }
    } else if (state is OtpError) {
      setState(() => _sendingOtp = false);
      _showError(state.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PaymentBloc, PaymentState>(
          listener: (_, state) => _handlePaymentState(state),
        ),
        BlocListener<OtpBloc, OtpState>(
          listener: (_, state) => _handleOtpState(state),
        ),
      ],
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: _step == _Step.otp ? 'Kembali' : 'Tutup',
                  icon: Icon(
                    _step == _Step.otp
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.close_rounded,
                    color: AppColors.ink,
                  ),
                  onPressed: _busy ? null : _handleBack,
                ),
              ),
              Expanded(
                child: _busy
                    ? const _ProcessingView()
                    : _step == _Step.pin
                        ? _buildPinStep()
                        : _buildOtpStep(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Column(
        children: [
          const FeatureIcon(
            icon: Icons.lock_outline_rounded,
            tone: 'violet',
            size: 58,
            iconSize: 28,
          ),
          const SizedBox(height: 16),
          const Text(
            'Masukkan PIN',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Masukkan 6 digit PIN keamanan kamu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.slate500),
          ),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: _hasError
                ? (Matrix4.identity()..translateByDouble(10, 0, 0, 1))
                : Matrix4.identity(),
            child: PinPad(
              value: _pin,
              onChanged: (value) => setState(() => _pin = value),
              onComplete: _onPinComplete,
            ),
          ),
          const SizedBox(height: 18),
          const Text.rich(
            TextSpan(
              text: 'Lupa PIN? ',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 12.5,
                color: AppColors.slate400,
              ),
              children: [
                TextSpan(
                  text: 'Reset',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    final isTotp = _twoFaMethod == AppConstants.twoFaTotp;
    final title = switch (_twoFaMethod) {
      AppConstants.twoFaSmtp => 'Masukkan Email OTP',
      AppConstants.twoFaNotif => 'Masukkan Kode Notifikasi',
      _ => 'Masukkan Kode Authenticator',
    };
    final description = switch (_twoFaMethod) {
      AppConstants.twoFaSmtp => 'Kode 6 digit dikirim ke email kamu.',
      AppConstants.twoFaNotif => 'Kode 6 digit dikirim melalui notifikasi.',
      _ => 'Buka aplikasi authenticator dan masukkan kode yang aktif.',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
      child: Column(
        children: [
          FeatureIcon(
            icon: isTotp
                ? Icons.phonelink_lock_rounded
                : _twoFaMethod == AppConstants.twoFaSmtp
                    ? Icons.mail_outline_rounded
                    : Icons.notifications_outlined,
            tone: isTotp ? 'violet' : 'blue',
            size: 74,
            iconSize: 35,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              height: 1.5,
              color: AppColors.slate500,
            ),
          ),
          const SizedBox(height: 28),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: _hasError
                ? (Matrix4.identity()..translateByDouble(8, 0, 0, 1))
                : Matrix4.identity(),
            child: CodeInput(
              value: _otpCode,
              onChanged: _onOtpChanged,
              hasError: _hasError,
            ),
          ),
          if (_hasError) ...[
            const SizedBox(height: 12),
            const Text(
              'Kode tidak cocok. Silakan coba lagi.',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: AppColors.red,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_sendingOtp) ...[
            const SizedBox(height: 20),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 9),
                Text(
                  'Mengirim kode...',
                  style: TextStyle(fontSize: 13, color: AppColors.slate500),
                ),
              ],
            ),
          ] else if (_canResend) ...[
            const SizedBox(height: 24),
            if (_resendSeconds > 0)
              Text(
                'Kirim ulang dalam 00:${_resendSeconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.slate400,
                ),
              )
            else
              TextButton.icon(
                onPressed: _sendOtp,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 17,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Kirim ulang kode',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  const _ProcessingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 18),
          Text(
            'Memproses transaksi...',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }
}
