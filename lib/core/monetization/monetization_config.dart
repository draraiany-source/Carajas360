import '../catalog/homolog_catalog.dart';
import '../constants/app_constants.dart';
import 'money.dart';

/// Feature flags + precos de monetizacao (Admin / platformConfig).
/// Em homologacao usa defaults seguros (Sandbox, sem cobranca real).
class MonetizationConfig {
  final bool creditsEnabled;
  final bool protectedPaymentsEnabled;
  final bool commissionEnabled;
  final bool proEnabled;
  final bool sponsoredEnabled;
  final bool welcomeCreditsEnabled;
  final bool launchModeEnabled;
  final double commissionRate;
  final MoneyCents proPriceMonthly;
  final int defaultLeadCreditCost;
  final int maxProfessionalsPerLead;
  final List<CreditPackage> creditPackages;
  final List<HighlightPlan> highlightPlans;

  const MonetizationConfig({
    this.creditsEnabled = true,
    this.protectedPaymentsEnabled = true,
    this.commissionEnabled = true,
    this.proEnabled = true,
    this.sponsoredEnabled = true,
    this.welcomeCreditsEnabled = true,
    this.launchModeEnabled = true,
    this.commissionRate = AppConst.commission,
    this.proPriceMonthly = const MoneyCents(3990),
    this.defaultLeadCreditCost = 5,
    this.maxProfessionalsPerLead = 5,
    this.creditPackages = const [],
    this.highlightPlans = const [],
  });

  static MonetizationConfig defaults() => MonetizationConfig(
        creditPackages: CreditPackage.defaults,
        highlightPlans: HighlightPlan.defaults,
      );

  factory MonetizationConfig.fromMap(Map<String, dynamic>? m) {
    final d = defaults();
    if (m == null || m.isEmpty) return d;
    final rate = (m['commissionRate'] as num?)?.toDouble() ?? d.commissionRate;
    final clamped = rate.clamp(0.0, 0.30);
    return MonetizationConfig(
      creditsEnabled: m['creditsEnabled'] as bool? ?? d.creditsEnabled,
      protectedPaymentsEnabled:
          m['protectedPaymentsEnabled'] as bool? ?? d.protectedPaymentsEnabled,
      commissionEnabled:
          m['commissionEnabled'] as bool? ?? d.commissionEnabled,
      proEnabled: m['proEnabled'] as bool? ?? d.proEnabled,
      sponsoredEnabled: m['sponsoredEnabled'] as bool? ?? d.sponsoredEnabled,
      welcomeCreditsEnabled:
          m['welcomeCreditsEnabled'] as bool? ?? d.welcomeCreditsEnabled,
      launchModeEnabled:
          m['launchModeEnabled'] as bool? ?? d.launchModeEnabled,
      commissionRate: clamped.toDouble(),
      proPriceMonthly: MoneyCents(
          (m['proPriceCents'] as num?)?.toInt() ?? d.proPriceMonthly.cents),
      defaultLeadCreditCost: (m['defaultLeadCreditCost'] as num?)?.toInt() ??
          d.defaultLeadCreditCost,
      maxProfessionalsPerLead:
          (m['maxProfessionalsPerLead'] as num?)?.toInt() ??
              d.maxProfessionalsPerLead,
      creditPackages: (m['creditPackages'] as List?)
              ?.map((e) => CreditPackage.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          d.creditPackages,
      highlightPlans: (m['highlightPlans'] as List?)
              ?.map((e) => HighlightPlan.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          d.highlightPlans,
    );
  }

  Map<String, dynamic> toMap() => {
        'creditsEnabled': creditsEnabled,
        'protectedPaymentsEnabled': protectedPaymentsEnabled,
        'commissionEnabled': commissionEnabled,
        'proEnabled': proEnabled,
        'sponsoredEnabled': sponsoredEnabled,
        'welcomeCreditsEnabled': welcomeCreditsEnabled,
        'launchModeEnabled': launchModeEnabled,
        'commissionRate': commissionRate,
        'proPriceCents': proPriceMonthly.cents,
        'defaultLeadCreditCost': defaultLeadCreditCost,
        'maxProfessionalsPerLead': maxProfessionalsPerLead,
        'creditPackages': creditPackages.map((e) => e.toMap()).toList(),
        'highlightPlans': highlightPlans.map((e) => e.toMap()).toList(),
      };

  /// Homolog nunca mistura com producao: flags de cobranca real off.
  bool get sandboxOnly =>
      HomologCatalog.enabled || launchModeEnabled;

  static bool validateCommissionRate(double rate) =>
      rate >= 0 && rate <= 0.30;
}

class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final MoneyCents price;
  final int bonusCredits;

  const CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    this.bonusCredits = 0,
  });

  int get totalCredits => credits + bonusCredits;

  static const defaults = [
    CreditPackage(
        id: 'pkg_10', name: '10 creditos', credits: 10, price: MoneyCents(1990)),
    CreditPackage(
        id: 'pkg_30',
        name: '30 creditos',
        credits: 30,
        price: MoneyCents(4990),
        bonusCredits: 5),
    CreditPackage(
        id: 'pkg_100',
        name: '100 creditos',
        credits: 100,
        price: MoneyCents(14990),
        bonusCredits: 20),
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'credits': credits,
        'priceCents': price.cents,
        'bonusCredits': bonusCredits,
      };

  factory CreditPackage.fromMap(Map<String, dynamic> m) => CreditPackage(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        credits: (m['credits'] as num?)?.toInt() ?? 0,
        price: MoneyCents((m['priceCents'] as num?)?.toInt() ?? 0),
        bonusCredits: (m['bonusCredits'] as num?)?.toInt() ?? 0,
      );
}

class HighlightPlan {
  final String id;
  final String name;
  final int hours;
  final MoneyCents price;

  const HighlightPlan({
    required this.id,
    required this.name,
    required this.hours,
    required this.price,
  });

  static const defaults = [
    HighlightPlan(
        id: 'hl_24h', name: '24 horas', hours: 24, price: MoneyCents(1990)),
    HighlightPlan(
        id: 'hl_7d', name: '7 dias', hours: 24 * 7, price: MoneyCents(7990)),
    HighlightPlan(
        id: 'hl_30d', name: '30 dias', hours: 24 * 30, price: MoneyCents(19990)),
  ];

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'hours': hours,
        'priceCents': price.cents,
      };

  factory HighlightPlan.fromMap(Map<String, dynamic> m) => HighlightPlan(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        hours: (m['hours'] as num?)?.toInt() ?? 24,
        price: MoneyCents((m['priceCents'] as num?)?.toInt() ?? 0),
      );
}
