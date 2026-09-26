import 'package:flutter/material.dart';

class RiderHistoryData {
  final int? id;
  final String trackingCode;
  final String buyerName;
  final String statusLabel;
  final String updatedLabel;
  final String? failureReason;
  final String? imageUrl;

  const RiderHistoryData({
    this.id,
    required this.trackingCode,
    required this.buyerName,
    required this.statusLabel,
    required this.updatedLabel,
    this.failureReason,
    this.imageUrl,
  });

  factory RiderHistoryData.fromApi(
    Map<String, dynamic> json,
  ) {
    return RiderHistoryData(
      id: _parseInt(json['id']),
      trackingCode:
          (json['tracking'] ??
                  json['tracking_code'] ??
                  '')
              .toString(),
      buyerName:
          (json['buyer'] ??
                  json['buyer_name'] ??
                  '')
              .toString(),
      statusLabel:
          (json['status_label'] ??
                  json['status'] ??
                  '')
              .toString(),
      updatedLabel:
          (json['updated'] ??
                  json['updated_at'] ??
                  '')
              .toString(),
      failureReason: _nullableString(
        json['failure_reason'],
      ),
      imageUrl: _nullableString(
        json['image'] ??
            json['image_url'],
      ),
    );
  }

  bool get hasFailureReason {
    return failureReason
            ?.trim()
            .isNotEmpty ==
        true;
  }

  static int? _parseInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String result =
        value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }
}

typedef RiderHistoryRefreshCallback =
    Future<void> Function();

typedef RiderHistoryItemCallback =
    void Function(
  RiderHistoryData history,
);

class RiderHistoryScreen
    extends StatefulWidget {
  final List<RiderHistoryData> history;

  final String? statusMessage;

  final RiderHistoryRefreshCallback?
      onRefresh;

  final RiderHistoryItemCallback?
      onOpenHistory;

  const RiderHistoryScreen({
    super.key,
    this.history =
        const <RiderHistoryData>[],
    this.statusMessage,
    this.onRefresh,
    this.onOpenHistory,
  });

  @override
  State<RiderHistoryScreen>
      createState() =>
          _RiderHistoryScreenState();
}

class _RiderHistoryScreenState
    extends State<RiderHistoryScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonSoft =
      Color(0xFFF1E4D7);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _success =
      Color(0xFF237A44);

  static const Color _successSoft =
      Color(0xFFEAF6EE);

  Future<void> _refresh() async {
    final RiderHistoryRefreshCallback?
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
          'Delivery History',
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
              if (widget
                      .statusMessage
                      ?.trim()
                      .isNotEmpty ==
                  true) ...<Widget>[
                _buildStatusMessage(
                  widget.statusMessage!,
                ),
                const SizedBox(
                  height: 18,
                ),
              ],

              _buildHeader(),

              const SizedBox(
                height: 24,
              ),

              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'RIDER HISTORY',
          style: TextStyle(
            color: _maroon,
            fontSize: 11.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(
          height: 8,
        ),

        Text(
          'Pickup and Delivery History',
          style: TextStyle(
            color: _text,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.45,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(
          height: 9,
        ),

        Text(
          'Completed, failed, returned, and sorting-center handoff records from the deliveries table.',
          style: TextStyle(
            color: _muted,
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          22,
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
              18,
              18,
              18,
              16,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'History',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                SizedBox(
                  height: 5,
                ),

                Text(
                  'This list uses your real rider assignments only.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: _border,
          ),

          if (widget.history.isEmpty)
            _buildEmptyState()
          else
            ...List<Widget>.generate(
              widget.history.length,
              (
                int index,
              ) {
                final RiderHistoryData
                    parcel =
                    widget.history[index];

                return Column(
                  children: <Widget>[
                    _HistoryItem(
                      parcel: parcel,
                      onTap:
                          widget.onOpenHistory ==
                                  null
                              ? null
                              : () {
                                  widget
                                      .onOpenHistory!(
                                    parcel,
                                  );
                                },
                    ),

                    if (index !=
                        widget.history.length -
                            1)
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: _border,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 42,
      ),
      child: Center(
        child: Column(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _maroonSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: _maroon,
                size: 28,
              ),
            ),

            SizedBox(
              height: 14,
            ),

            Text(
              'No rider history found yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            SizedBox(
              height: 6,
            ),

            Text(
              'Your completed and previous pickup or delivery assignments will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage(
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color: _successSoft,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color: const Color(
            0xFFB7DFC5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons
                .check_circle_outline_rounded,
            color: _success,
            size: 20,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _success,
                fontSize: 13,
                height: 1.45,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem
    extends StatelessWidget {
  final RiderHistoryData parcel;

  final VoidCallback? onTap;

  const _HistoryItem({
    required this.parcel,
    this.onTap,
  });

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonSoft =
      Color(0xFFF1E4D7);

  static const Color _danger =
      Color(0xFFB42318);

  static const Color _dangerSoft =
      Color(0xFFFFF1F0);

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
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
                  _HistoryImage(
                    imageUrl:
                        parcel.imageUrl,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          parcel.trackingCode
                                  .trim()
                                  .isEmpty
                              ? 'No tracking code'
                              : parcel
                                  .trackingCode,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color: _text,
                            fontSize: 15,
                            height: 1.25,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        const SizedBox(
                          height: 5,
                        ),

                        Text(
                          'Buyer: ${parcel.buyerName}',
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            color: _muted,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          '${parcel.statusLabel} - ${parcel.updatedLabel}',
                          style:
                              const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (parcel
                  .hasFailureReason) ...<
                  Widget>[
                const SizedBox(
                  height: 12,
                ),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(
                    11,
                  ),
                  decoration:
                      BoxDecoration(
                    color: _dangerSoft,
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFF5C5C1,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: <Widget>[
                      const Icon(
                        Icons
                            .error_outline_rounded,
                        color: _danger,
                        size: 18,
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Expanded(
                        child: Text(
                          'Reason: ${parcel.failureReason}',
                          style:
                              const TextStyle(
                            color: _danger,
                            fontSize: 12,
                            height: 1.45,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: 13,
              ),

              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          _maroonSoft,
                      borderRadius:
                          BorderRadius
                              .circular(
                        100,
                      ),
                    ),
                    child: Text(
                      parcel.statusLabel,
                      style:
                          const TextStyle(
                        color: _maroon,
                        fontSize: 11,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),
                  ),

                  const Spacer(),

                  if (onTap != null)
                    const Icon(
                      Icons
                          .chevron_right_rounded,
                      color:
                          Color(
                        0xFFA99386,
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

class _HistoryImage
    extends StatelessWidget {
  final String? imageUrl;

  const _HistoryImage({
    required this.imageUrl,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? url =
        imageUrl?.trim();

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(
          0xFFF3ECE4,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child: url == null ||
              url.isEmpty
          ? const Center(
              child: Icon(
                Icons
                    .inventory_2_outlined,
                color: Color(
                  0xFFA99386,
                ),
                size: 25,
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (
                BuildContext context,
                Widget child,
                ImageChunkEvent?
                    loadingProgress,
              ) {
                if (loadingProgress ==
                    null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(
                        0xFF561C17,
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace?
                    stackTrace,
              ) {
                return const Center(
                  child: Icon(
                    Icons
                        .broken_image_outlined,
                    color: Color(
                      0xFFA99386,
                    ),
                    size: 25,
                  ),
                );
              },
            ),
    );
  }
}
