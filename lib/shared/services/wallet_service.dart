import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class WalletService {
  static Stream<WalletModel?> walletStream() => FS.walletStream();
  static Stream<List<TransactionModel>> txStream() => FS.txStream();
  static Future<bool> credit(double amount, String desc, String icon) =>
      FS.credit(amount, desc, icon);
  static Future<bool> debit(double amount, String desc, String icon) =>
      FS.debit(amount, desc, icon);
  static Future<bool> payOrderWithWallet(String orderId) =>
      FS.payOrderWithWallet(orderId);
  static Future<bool> withdraw(double amount, String pixKey) =>
      FS.withdraw(amount, pixKey);
}
