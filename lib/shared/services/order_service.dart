import '../models/models.dart';
import 'firestore_facade.dart';

abstract final class OrderService {
  static Future<String> createOrder(Map<String, dynamic> data) =>
      FS.createOrder(data);
  static Future<void> acceptOrder(String orderId, {double? price}) =>
      FS.acceptOrder(orderId, price: price);
  static Future<void> declineOrder(String orderId) => FS.declineOrder(orderId);
  static Future<void> cancelOrder(String orderId) => FS.cancelOrder(orderId);
  static Future<void> startOrder(String orderId) => FS.startOrder(orderId);
  static Future<void> completeOrder(String orderId) => FS.completeOrder(orderId);
  static Stream<List<OrderModel>> myOrdersStream() => FS.myOrdersStream();
  static Stream<List<OrderModel>> orderHistoryStream({OrderStatus? status}) =>
      FS.orderHistoryStream(status: status);
  static Stream<List<OrderModel>> providerOrdersStream(
          {List<OrderStatus>? statuses}) =>
      FS.providerOrdersStream(statuses: statuses);
}
