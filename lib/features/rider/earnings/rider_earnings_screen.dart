import 'package:flutter/material.dart';

class RiderEarningRowData {
  final String date;

  final String reference;

  final String amount;

  final String status;

  const RiderEarningRowData({
    required this.date,
    required this.reference,
    required this.amount,
    required this.status,
  });

  factory RiderEarningRowData.fromApi(
    Map<String, dynamic> json,
  ) {
    return RiderEarningRowData(
      date: (json['date'] ?? '').toString(),
      reference:
          (json['reference'] ?? '').toString(),
      amount:
          (json['amount'] ?? '').toString(),
      status:
          (json['status'] ?? '').toString(),
    );
  }

  String get normalizedStatus {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }
}

typedef RiderEarningsRefreshCallback =
    Future<void> Function();

class RiderEarningsScreen
    extends StatefulWidget {
  final List<RiderEarningRowData>
      earningsRows;

  final String earningsNotice;

  final RiderEarningsRefreshCallback?
      onRefresh;

  const RiderEarningsScreen({
    super.key,
    this.earningsRows =
        const <RiderEarningRowData>[],
    this.earningsNotice =
        'No rider payout rule or earnings table is configured yet.',
    this.onRefresh,
  });

  @override
  State<RiderEarningsScreen>
      createState() =>
          _RiderEarningsScreenState();
}

class _RiderEarningsScreenState
    extends State<RiderEarningsScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _surfaceSoft =
      Color(0xFFF6EFE7);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  Future<void> _refresh() async {
    final RiderEarningsRefreshCallback?
        callback =
        widget.onRefresh;

    if (callback == null) {
      return;
    }

    await callback();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Earnings',
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: _refresh,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              100,
            ),
            children: <Widget>[
              _buildHeading(),

              const SizedBox(
                height: 22,
              ),

              _buildRecordsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'INCOME MANAGEMENT',
          style: TextStyle(
            color: _maroon,
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        const Text(
          'My Earnings',
          style: TextStyle(
            color: _text,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        Text(
          widget.earningsNotice,
          style: const TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordsSection() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              17,
              17,
              17,
              15,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Earnings Records',
                  style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'LIKHAE will show earnings here after a real payout calculation is configured.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: _border,
          ),

          if (widget
              .earningsRows.isEmpty)
            _buildEmptyState()
          else
            _buildRecords(),
        ],
      ),
    );
  }

  Widget _buildRecords() {
    return Column(
      children: List<Widget>.generate(
        widget.earningsRows.length,
        (
          int index,
        ) {
          final RiderEarningRowData row =
              widget.earningsRows[index];

          return Column(
            children: <Widget>[
              _EarningRecordCard(
                row: row,
              ),

              if (index !=
                  widget
                          .earningsRows
                          .length -
                      1)
                const Divider(
                  height: 1,
                  color: _border,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 40,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons
                  .account_balance_wallet_outlined,
              color: _maroon,
              size: 28,
            ),
          ),

          SizedBox(
            height: 14,
          ),

          Text(
            'No real earnings records are available yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          SizedBox(
            height: 7,
          ),

          Text(
            'Your earnings history will appear here once LIKHAE has a real payout calculation and earnings ledger configured.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningRecordCard
    extends StatelessWidget {
  final RiderEarningRowData row;

  const _EarningRecordCard({
    required this.row,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.all(
        16,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment:
                    Alignment.center,
                decoration: BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons
                      .payments_outlined,
                  color:
                      Color(
                    0xFF561C17,
                  ),
                  size: 21,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      row.reference
                              .trim()
                              .isEmpty
                          ? 'Earnings Record'
                          : row.reference,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF3B211B,
                        ),
                        fontSize: 14,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      row.date,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF987865,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (row.amount
                  .trim()
                  .isNotEmpty)
                Text(
                  row.amount,
                  textAlign:
                      TextAlign.right,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF561C17,
                    ),
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Row(
            children: <Widget>[
              const Text(
                'Status',
                style: TextStyle(
                  color:
                      Color(
                    0xFF987865,
                  ),
                  fontSize: 11.5,
                ),
              ),

              const Spacer(),

              _EarningStatusBadge(
                status: row.status,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarningStatusBadge
    extends StatelessWidget {
  final String status;

  const _EarningStatusBadge({
    required this.status,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String normalized =
        status
            .trim()
            .toLowerCase()
            .replaceAll(
              '-',
              '_',
            )
            .replaceAll(
              ' ',
              '_',
            );

    final Color background;
    final Color foreground;
    final IconData icon;

    switch (normalized) {
      case 'paid':
      case 'completed':
      case 'released':
        background =
            const Color(
          0xFFEAF6EE,
        );

        foreground =
            const Color(
          0xFF237A44,
        );

        icon =
            Icons
                .check_circle_outline_rounded;

        break;

      case 'pending':
      case 'processing':
        background =
            const Color(
          0xFFFFF3DC,
        );

        foreground =
            const Color(
          0xFF906010,
        );

        icon =
            Icons
                .schedule_rounded;

        break;

      case 'failed':
      case 'rejected':
        background =
            const Color(
          0xFFFFF1F0,
        );

        foreground =
            const Color(
          0xFFB42318,
        );

        icon =
            Icons
                .error_outline_rounded;

        break;

      default:
        background =
            const Color(
          0xFFF1E4D7,
        );

        foreground =
            const Color(
          0xFF561C17,
        );

        icon =
            Icons
                .info_outline_rounded;
    }

    final String label =
        status.trim().isEmpty
            ? 'Unknown'
            : status;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(
          100,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            color: foreground,
            size: 14,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
