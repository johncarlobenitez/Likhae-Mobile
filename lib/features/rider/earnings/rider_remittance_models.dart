double _amount(dynamic value) => double.tryParse('$value') ?? 0;

class RiderCodCollection {
  final int id;
  final String tracking;
  final String reference;
  final double collectedAmount;

  const RiderCodCollection({
    required this.id,
    required this.tracking,
    required this.reference,
    required this.collectedAmount,
  });

  factory RiderCodCollection.fromApi(Map<String, dynamic> json) =>
      RiderCodCollection(
        id: int.parse('${json['id']}'),
        tracking: '${json['tracking'] ?? ''}',
        reference: '${json['reference'] ?? ''}',
        collectedAmount: _amount(json['collected_amount']),
      );
}

class RiderRemittance {
  final int id;
  final String reference;
  final String status;
  final double expectedAmount;
  final double submittedAmount;
  final double? verifiedAmount;

  const RiderRemittance({
    required this.id,
    required this.reference,
    required this.status,
    required this.expectedAmount,
    required this.submittedAmount,
    this.verifiedAmount,
  });

  factory RiderRemittance.fromApi(Map<String, dynamic> json) => RiderRemittance(
    id: int.parse('${json['id']}'),
    reference: '${json['reference'] ?? ''}',
    status: '${json['status'] ?? ''}',
    expectedAmount: _amount(json['expected_amount']),
    submittedAmount: _amount(json['submitted_amount']),
    verifiedAmount: json['verified_amount'] == null
        ? null
        : _amount(json['verified_amount']),
  );
}

class RiderRemittanceSnapshot {
  final bool available;
  final List<RiderCodCollection> collections;
  final List<RiderRemittance> history;

  const RiderRemittanceSnapshot({
    required this.available,
    required this.collections,
    required this.history,
  });
}
