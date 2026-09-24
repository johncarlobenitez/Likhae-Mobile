import 'package:flutter/material.dart';

enum RewardsTab {
  vouchers,
  points,
  cashback,
}

extension RewardsTabInfo on RewardsTab {
  String get label {
    switch (this) {
      case RewardsTab.vouchers:
        return 'My Vouchers';

      case RewardsTab.points:
        return 'Reward Points';

      case RewardsTab.cashback:
        return 'Cashback';
    }
  }

  IconData get icon {
    switch (this) {
      case RewardsTab.vouchers:
        return Icons.confirmation_number_outlined;

      case RewardsTab.points:
        return Icons.stars_outlined;

      case RewardsTab.cashback:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class RewardVoucherData {
  /// Existing display icon/text.
  ///
  /// Examples:
  /// "%"
  /// "₱"
  /// "FREE"
  final String icon;

  /// Display status supplied by Laravel.
  ///
  /// Examples:
  /// Active
  /// Used
  /// Expired
  final String status;

  /// Human-readable benefit.
  ///
  /// Examples:
  /// "10% OFF"
  /// "₱50 OFF"
  final String value;

  /// Voucher conditions supplied by Laravel.
  final String condition;

  final String code;

  /// Display-ready expiration value.
  final String expires;

  /// Optional additional campaign context.
  final String? campaignName;
  final String? sellerName;

  /// Optional explicit usability supplied by Laravel.
  ///
  /// null means this Flutter page does not independently
  /// decide whether the voucher is valid.
  final bool? canUse;

  const RewardVoucherData({
    required this.icon,
    required this.status,
    required this.value,
    required this.condition,
    required this.code,
    required this.expires,
    this.campaignName,
    this.sellerName,
    this.canUse,
  });
}

class VoucherHistoryData {
  final String voucher;
  final String benefit;
  final String order;
  final String status;

  const VoucherHistoryData({
    required this.voucher,
    required this.benefit,
    required this.order,
    required this.status,
  });
}

class PointsActivityData {
  final String label;
  final String date;
  final String amount;

  final bool negative;

  const PointsActivityData({
    required this.label,
    required this.date,
    required this.amount,
    this.negative = false,
  });
}

class CashbackActivityData {
  final String order;
  final String type;
  final String amount;
  final String date;

  const CashbackActivityData({
    required this.order,
    required this.type,
    required this.amount,
    required this.date,
  });
}

typedef RewardsRefreshCallback = Future<void> Function();

typedef RewardVoucherCallback = void Function(
  RewardVoucherData voucher,
);

class RewardsScreen extends StatefulWidget {
  final RewardsTab initialTab;

  final List<RewardVoucherData> activeVouchers;
  final List<VoucherHistoryData> voucherHistory;

  final int pointsBalance;
  final List<PointsActivityData> pointActivities;

  final double availableCashback;
  final double pendingCashback;

  final List<CashbackActivityData>
      cashbackActivities;

  /// Current Buyer rewards rules.
  ///
  /// Keep these configurable so Flutter does not need to be
  /// redesigned if the Laravel rewards rules change later.
  final int pointsPerCompletedOrder;
  final int pointsPerReview;

  /// 0.02 = 2%
  final double cashbackRate;

  final VoidCallback? onBack;
  final VoidCallback? onBrowseProducts;

  /// Retained for compatibility with the previous page.
  ///
  /// This page deliberately does not imply that points or
  /// cashback are automatically redeemable during Checkout.
  final VoidCallback? onGoToCheckout;

  /// Preferred behavior:
  ///
  /// The parent can take the buyer to products/cart/checkout
  /// while preserving this voucher code.
  ///
  /// Merely pressing this button does NOT mark the voucher
  /// as used.
  final RewardVoucherCallback? onUseVoucher;

  final ValueChanged<RewardsTab>? onTabChanged;

  final RewardsRefreshCallback? onRefresh;

  const RewardsScreen({
    super.key,
    this.initialTab = RewardsTab.vouchers,
    this.activeVouchers =
        const <RewardVoucherData>[],
    this.voucherHistory =
        const <VoucherHistoryData>[],
    this.pointsBalance = 0,
    this.pointActivities =
        const <PointsActivityData>[],
    this.availableCashback = 0,
    this.pendingCashback = 0,
    this.cashbackActivities =
        const <CashbackActivityData>[],
    this.pointsPerCompletedOrder = 50,
    this.pointsPerReview = 20,
    this.cashbackRate = 0.02,
    this.onBack,
    this.onBrowseProducts,
    this.onGoToCheckout,
    this.onUseVoucher,
    this.onTabChanged,
    this.onRefresh,
  });

  @override
  State<RewardsScreen> createState() =>
      _RewardsScreenState();
}

class _RewardsScreenState
    extends State<RewardsScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _backgroundSoft =
      Color(0xFFF6EFE7);

  static const Color _backgroundAlt =
      Color(0xFFEFE7DE);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroon2 =
      Color(0xFF642920);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _brown =
      Color(0xFF6C4936);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _warning =
      Color(0xFF9A5B11);

  static const Color _danger =
      Color(0xFFB42318);

  late RewardsTab _activeTab;

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();

    _activeTab = widget.initialTab;
  }

  @override
  void didUpdateWidget(
    covariant RewardsScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.initialTab !=
        widget.initialTab) {
      _activeTab =
          widget.initialTab;
    }
  }

  Future<void> _refresh() async {
    final RewardsRefreshCallback? callback =
        widget.onRefresh;

    if (callback == null ||
        _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await callback();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _changeTab(
    RewardsTab tab,
  ) {
    if (_activeTab == tab) {
      return;
    }

    setState(() {
      _activeTab = tab;
    });

    widget.onTabChanged?.call(
      tab,
    );
  }

  void _useVoucher(
    RewardVoucherData voucher,
  ) {
    if (voucher.canUse == false) {
      _showMessage(
        'This voucher is not currently available for use.',
        error: true,
      );

      return;
    }

    final RewardVoucherCallback? callback =
        widget.onUseVoucher;

    if (callback == null) {
      return;
    }

    /*
     * Important:
     *
     * This does NOT consume or apply the voucher.
     *
     * The actual voucher must still be validated during
     * Checkout by Laravel.
     */
    callback(
      voucher,
    );
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? _danger
                  : _maroonDark,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content:
              Text(
            message,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        bottom: false,
        child:
            Column(
          children: [
            _buildTopBar(),

            Expanded(
              child:
                  RefreshIndicator(
                color:
                    _maroon,
                onRefresh:
                    _refresh,
                child:
                    ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    14,
                    14,
                    14,
                    100,
                  ),
                  children: [
                    _buildHeader(),

                    const SizedBox(
                      height: 18,
                    ),

                    _buildOverviewCards(),

                    const SizedBox(
                      height: 18,
                    ),

                    _buildTabs(),

                    const SizedBox(
                      height: 18,
                    ),

                    AnimatedSwitcher(
                      duration:
                          const Duration(
                        milliseconds:
                            220,
                      ),
                      child:
                          KeyedSubtree(
                        key:
                            ValueKey<RewardsTab>(
                          _activeTab,
                        ),
                        child:
                            _buildActiveTab(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration:
          const BoxDecoration(
        color:
            _background,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          IconButton(
            tooltip:
                'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              color:
                  _text,
            ),
          ),

          const SizedBox(
            width: 2,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Rewards & Vouchers',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize:
                        19,
                    height:
                        1.1,
                    letterSpacing:
                        -0.4,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Seller vouchers, reward points and cashback',
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      TextStyle(
                    color:
                        _muted,
                    fontSize:
                        9.5,
                  ),
                ),
              ],
            ),
          ),

          if (_refreshing) ...[
            const SizedBox(
              width:
                  17,
              height:
                  17,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2,
                color:
                    _maroon,
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),
          ],

          TextButton(
            onPressed:
                widget.onBrowseProducts,
            child:
                const Text(
              'Shop',
              style:
                  TextStyle(
                color:
                    _maroon,
                fontSize:
                    11,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors:
              <Color>[
            _surface,
            _backgroundSoft,
            _backgroundAlt,
          ],
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                _maroon.withValues(
              alpha: 0.055,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              10,
            ),
          ),
        ],
      ),
      child:
          Stack(
        children: [
          Positioned(
            right:
                -45,
            top:
                -55,
            child:
                Container(
              width:
                  150,
              height:
                  150,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    _tan.withValues(
                  alpha: 0.14,
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'BUYER BENEFITS',
                style:
                    TextStyle(
                  color:
                      _maroon,
                  fontSize:
                      8.5,
                  letterSpacing:
                      1.7,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              const Text(
                'Rewards &\nVouchers',
                style:
                    TextStyle(
                  color:
                      _text,
                  fontSize:
                      30,
                  height:
                      1,
                  letterSpacing:
                      -0.8,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height: 9,
              ),

              const Text(
                'Review your current benefits and reward activity from LIKHAE.',
                style:
                    TextStyle(
                  color:
                      _muted,
                  fontSize:
                      11,
                  height:
                      1.5,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              SizedBox(
                height:
                    43,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      widget.onBrowseProducts,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        _maroon,
                    side:
                        const BorderSide(
                      color:
                          _tan,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  icon:
                      const Icon(
                    Icons
                        .shopping_bag_outlined,
                    size:
                        17,
                  ),
                  label:
                      const Text(
                    'Browse Products',
                    style:
                        TextStyle(
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards() {
    return LayoutBuilder(
      builder:
          (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns =
            constraints.maxWidth >=
                    720
                ? 3
                : constraints.maxWidth >=
                        430
                    ? 3
                    : 1;

        const double spacing =
            9;

        final double width =
            columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth -
                        (spacing *
                            (columns -
                                1))) /
                    columns;

        return Wrap(
          spacing:
              spacing,
          runSpacing:
              spacing,
          children:
              <Widget>[
            SizedBox(
              width:
                  width,
              child:
                  _RewardStatCard(
                icon:
                    Icons
                        .confirmation_number_outlined,
                label:
                    'Active vouchers',
                value:
                    '${widget.activeVouchers.length}',
              ),
            ),
            SizedBox(
              width:
                  width,
              child:
                  _RewardStatCard(
                icon:
                    Icons
                        .stars_rounded,
                label:
                    'Reward points',
                value:
                    _formatInteger(
                  widget.pointsBalance,
                ),
              ),
            ),
            SizedBox(
              width:
                  width,
              child:
                  _RewardStatCard(
                icon:
                    Icons
                        .account_balance_wallet_outlined,
                label:
                    'Cashback',
                value:
                    _formatMoney(
                  widget.availableCashback,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      height:
          53,
      padding:
          const EdgeInsets.all(
        5,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          ListView.separated(
        scrollDirection:
            Axis.horizontal,
        itemCount:
            RewardsTab.values.length,
        separatorBuilder:
            (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            width:
                5,
          );
        },
        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final RewardsTab tab =
              RewardsTab.values[index];

          final bool selected =
              tab ==
                  _activeTab;

          return Material(
            color:
                selected
                    ? _maroon
                    : Colors.transparent,
            borderRadius:
                BorderRadius.circular(
              11,
            ),
            child:
                InkWell(
              onTap:
                  () {
                _changeTab(
                  tab,
                );
              },
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
              child:
                  Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      14,
                ),
                alignment:
                    Alignment.center,
                child:
                    Row(
                  children: [
                    Icon(
                      tab.icon,
                      size:
                          15,
                      color:
                          selected
                              ? Colors.white
                              : _brown,
                    ),

                    const SizedBox(
                      width:
                          6,
                    ),

                    Text(
                      tab.label,
                      style:
                          TextStyle(
                        color:
                            selected
                                ? Colors.white
                                : _brown,
                        fontSize:
                            10,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_activeTab) {
      case RewardsTab.vouchers:
        return _buildVouchers();

      case RewardsTab.points:
        return _buildPoints();

      case RewardsTab.cashback:
        return _buildCashback();
    }
  }

  Widget _buildVouchers() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          kicker:
              'AVAILABLE',
          title:
              'My Vouchers',
          description:
              'Seller voucher campaigns currently available to your buyer account.',
        ),

        const SizedBox(
          height:
              14,
        ),

        if (widget.activeVouchers.isEmpty)
          _buildNoVoucherCard()
        else
          ...widget.activeVouchers.map(
            (
              RewardVoucherData voucher,
            ) {
              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom:
                      11,
                ),
                child:
                    _VoucherCard(
                  voucher:
                      voucher,
                  canOpen:
                      widget.onUseVoucher !=
                              null &&
                          voucher.canUse !=
                              false,
                  onUse:
                      () {
                    _useVoucher(
                      voucher,
                    );
                  },
                ),
              );
            },
          ),

        const SizedBox(
          height:
              8,
        ),

        _RewardPanel(
          title:
              'Voucher History',
          icon:
              Icons
                  .history_rounded,
          child:
              widget.voucherHistory.isEmpty
                  ? const _SimpleEmptyRow(
                      title:
                          'No voucher history yet',
                      subtitle:
                          'Used or expired voucher activity will appear here when available.',
                    )
                  : Column(
                      children:
                          widget.voucherHistory
                              .map(
                        (
                          VoucherHistoryData item,
                        ) {
                          return _VoucherHistoryRow(
                            item:
                                item,
                          );
                        },
                      ).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildNoVoucherCard() {
    return Container(
      padding:
          const EdgeInsets.all(
        17,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        border:
            Border.all(
          color:
              _border,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                    54,
                height:
                    54,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                alignment:
                    Alignment.center,
                child:
                    const Text(
                  '%',
                  style:
                      TextStyle(
                    color:
                        _maroon,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NO ACTIVE VOUCHERS',
                      style:
                          TextStyle(
                        color:
                            _maroon,
                        fontSize:
                            7.5,
                        letterSpacing:
                            1,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      'No seller vouchers yet',
                      style:
                          TextStyle(
                        color:
                            _text,
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      'Available seller voucher campaigns will appear here.',
                      style:
                          TextStyle(
                        color:
                            _muted,
                        fontSize:
                            9.5,
                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.onBrowseProducts !=
              null) ...[
            const SizedBox(
              height:
                  15,
            ),

            SizedBox(
              width:
                  double.infinity,
              height:
                  44,
              child:
                  ElevatedButton.icon(
                onPressed:
                    widget.onBrowseProducts,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  elevation:
                      0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                icon:
                    const Icon(
                  Icons
                      .storefront_outlined,
                  size:
                      17,
                ),
                label:
                    const Text(
                  'Browse Products',
                  style:
                      TextStyle(
                    fontSize:
                        10.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPoints() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          kicker:
              'LOYALTY',
          title:
              'Reward Points',
          description:
              'Reward points recorded from eligible buyer activity.',
        ),

        const SizedBox(
          height:
              14,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            22,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              21,
            ),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors:
                  <Color>[
                _maroon,
                _maroon2,
                _maroonDark,
              ],
            ),
            boxShadow:
                <BoxShadow>[
              BoxShadow(
                color:
                    _maroon.withValues(
                  alpha: 0.18,
                ),
                blurRadius:
                    28,
                offset:
                    const Offset(
                  0,
                  13,
                ),
              ),
            ],
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons
                        .stars_rounded,
                    color:
                        Color(
                      0xFFE8C8B2,
                    ),
                    size:
                        19,
                  ),

                  SizedBox(
                    width:
                        7,
                  ),

                  Text(
                    'Current points',
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFFE8C8B2,
                      ),
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    10,
              ),

              Text(
                _formatInteger(
                  widget.pointsBalance,
                ),
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      42,
                  height:
                      1,
                  letterSpacing:
                      -1.2,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    5,
              ),

              const Text(
                'LIKHAE Reward Points',
                style:
                    TextStyle(
                  color:
                      Color(
                    0xFFF4DED4,
                  ),
                  fontSize:
                      10,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height:
                    19,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.only(
                  top:
                      15,
                ),
                decoration:
                    const BoxDecoration(
                  border:
                      Border(
                    top:
                        BorderSide(
                      color:
                          Color(
                        0x33FFFFFF,
                      ),
                    ),
                  ),
                ),
                child:
                    const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .info_outline_rounded,
                      color:
                          Color(
                        0xFFE8C8B2,
                      ),
                      size:
                          16,
                    ),

                    SizedBox(
                      width:
                          7,
                    ),

                    Expanded(
                      child:
                          Text(
                        'The server remains the source of truth for your point balance and activity.',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFFF4DED4,
                          ),
                          fontSize:
                              9.5,
                          height:
                              1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              13,
        ),

        _RewardPanel(
          title:
              'How Points Are Earned',
          icon:
              Icons
                  .add_circle_outline,
          child:
              Column(
            children: [
              _EarnPointCard(
                value:
                    '+${widget.pointsPerCompletedOrder}',
                label:
                    'Completed / delivered order',
                icon:
                    Icons
                        .check_circle_outline,
              ),

              const SizedBox(
                height:
                    9,
              ),

              _EarnPointCard(
                value:
                    '+${widget.pointsPerReview}',
                label:
                    'Product review',
                icon:
                    Icons
                        .rate_review_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              13,
        ),

        _RewardPanel(
          title:
              'Points Activity',
          icon:
              Icons
                  .history_rounded,
          child:
              widget.pointActivities.isEmpty
                  ? const _SimpleEmptyRow(
                      title:
                          'No points activity yet',
                      subtitle:
                          'Eligible order and review activity will appear here.',
                    )
                  : Column(
                      children:
                          widget.pointActivities
                              .map(
                        (
                          PointsActivityData activity,
                        ) {
                          return _PointsActivityRow(
                            activity:
                                activity,
                          );
                        },
                      ).toList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildCashback() {
    final double safeAvailable =
        widget.availableCashback < 0
            ? 0
            : widget.availableCashback;

    final double safePending =
        widget.pendingCashback < 0
            ? 0
            : widget.pendingCashback;

    final double safeRate =
        widget.cashbackRate < 0
            ? 0
            : widget.cashbackRate;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(
          kicker:
              'BUYER SAVINGS',
          title:
              'Cashback',
          description:
              'Cashback recorded from eligible completed buyer orders.',
        ),

        const SizedBox(
          height:
              14,
        ),

        Container(
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration:
              BoxDecoration(
            color:
                _surface,
            borderRadius:
                BorderRadius.circular(
              19,
            ),
            border:
                Border.all(
              color:
                  _border,
            ),
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons
                        .account_balance_wallet_outlined,
                    color:
                        _maroon,
                    size:
                        19,
                  ),

                  SizedBox(
                    width:
                        7,
                  ),

                  Text(
                    'Earned cashback',
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height:
                    9,
              ),

              Text(
                _formatMoney(
                  safeAvailable,
                ),
                style:
                    const TextStyle(
                  color:
                      _maroon,
                  fontSize:
                      32,
                  height:
                      1,
                  letterSpacing:
                      -0.8,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    11,
              ),

              Text(
                safeRate > 0
                    ? 'Current cashback rate: ${_formatPercentage(safeRate)}'
                    : 'Cashback rate is not currently available.',
                style:
                    const TextStyle(
                  color:
                      _muted,
                  fontSize:
                      9.5,
                  height:
                      1.4,
                ),
              ),

              if (widget.onBrowseProducts !=
                  null) ...[
                const SizedBox(
                  height:
                      17,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      45,
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        widget.onBrowseProducts,
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          _maroon,
                      side:
                          const BorderSide(
                        color:
                            _tan,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                    ),
                    icon:
                        const Icon(
                      Icons
                          .shopping_bag_outlined,
                      size:
                          17,
                    ),
                    label:
                        const Text(
                      'Browse Products',
                      style:
                          TextStyle(
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(
          height:
              13,
        ),

        _RewardPanel(
          title:
              'Cashback Status',
          icon:
              Icons
                  .savings_outlined,
          child:
              Column(
            children: [
              _CashbackBalanceRow(
                label:
                    'Earned cashback',
                value:
                    _formatMoney(
                  safeAvailable,
                ),
                icon:
                    Icons
                        .account_balance_wallet_outlined,
                emphasized:
                    true,
              ),

              const SizedBox(
                height:
                    10,
              ),

              _CashbackBalanceRow(
                label:
                    'Pending cashback',
                value:
                    _formatMoney(
                  safePending,
                ),
                icon:
                    Icons
                        .schedule_rounded,
              ),

              const SizedBox(
                height:
                    13,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  12,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFFFF6DE,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFFEAD39A,
                    ),
                  ),
                ),
                child:
                    const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons
                          .info_outline_rounded,
                      color:
                          _warning,
                      size:
                          18,
                    ),

                    SizedBox(
                      width:
                          8,
                    ),

                    Expanded(
                      child:
                          Text(
                        'This page only displays cashback recorded by the rewards system. Checkout redemption should only be enabled when the backend explicitly supports it.',
                        style:
                            TextStyle(
                          color:
                              _warning,
                          fontSize:
                              9,
                          height:
                              1.45,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              13,
        ),

        _RewardPanel(
          title:
              'Cashback Activity',
          icon:
              Icons
                  .history_rounded,
          child:
              widget.cashbackActivities.isEmpty
                  ? const _SimpleEmptyRow(
                      title:
                          'No cashback activity yet',
                      subtitle:
                          'Eligible cashback activity will appear here.',
                    )
                  : Column(
                      children:
                          widget.cashbackActivities
                              .map(
                        (
                          CashbackActivityData activity,
                        ) {
                          return _CashbackActivityRow(
                            activity:
                                activity,
                          );
                        },
                      ).toList(),
                    ),
        ),
      ],
    );
  }

  static String _formatMoney(
    double value,
  ) {
    final double safeValue =
        value < 0
            ? 0
            : value;

    return '₱${safeValue.toStringAsFixed(2)}';
  }

  static String _formatPercentage(
    double rate,
  ) {
    final double percentage =
        rate * 100;

    if (percentage ==
        percentage.roundToDouble()) {
      return '${percentage.toStringAsFixed(0)}%';
    }

    return '${percentage.toStringAsFixed(2)}%';
  }

  static String _formatInteger(
    int value,
  ) {
    final int safeValue =
        value < 0
            ? 0
            : value;

    final String digits =
        safeValue.toString();

    final StringBuffer result =
        StringBuffer();

    for (int index = 0;
        index < digits.length;
        index++) {
      final int remaining =
          digits.length -
              index;

      result.write(
        digits[index],
      );

      if (remaining > 1 &&
          remaining % 3 ==
              1) {
        result.write(
          ',',
        );
      }
    }

    return result.toString();
  }
}

class _RewardStatCard
    extends StatelessWidget {
  final IconData icon;

  final String label;
  final String value;

  const _RewardStatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight:
            92,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                const Color(
              0xFF561C17,
            ),
            size:
                19,
          ),

          const SizedBox(
            height:
                8,
          ),

          Text(
            value,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF3B211B,
              ),
              fontSize:
                  15,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                2,
          ),

          Text(
            label,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF987865,
              ),
              fontSize:
                  8.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading
    extends StatelessWidget {
  final String kicker;
  final String title;
  final String description;

  const _SectionHeading({
    required this.kicker,
    required this.title,
    required this.description,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style:
              const TextStyle(
            color:
                Color(
              0xFF561C17,
            ),
            fontSize:
                8.5,
            letterSpacing:
                1.5,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height:
              5,
        ),

        Text(
          title,
          style:
              const TextStyle(
            color:
                Color(
              0xFF3B211B,
            ),
            fontSize:
                24,
            height:
                1.05,
            letterSpacing:
                -0.6,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height:
              6,
        ),

        Text(
          description,
          style:
              const TextStyle(
            color:
                Color(
              0xFF987865,
            ),
            fontSize:
                10.5,
            height:
                1.45,
          ),
        ),
      ],
    );
  }
}

class _VoucherCard
    extends StatelessWidget {
  final RewardVoucherData voucher;

  final bool canOpen;

  final VoidCallback onUse;

  const _VoucherCard({
    required this.voucher,
    required this.canOpen,
    required this.onUse,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool explicitlyUnavailable =
        voucher.canUse ==
            false;

    return Container(
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                const Color(
              0xFF561C17,
            ).withValues(
              alpha: 0.045,
            ),
            blurRadius:
                20,
            offset:
                const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child:
          Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.all(
              16,
            ),
            child:
                Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width:
                      56,
                  height:
                      56,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF1E4D7,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                  alignment:
                      Alignment.center,
                  child:
                      Text(
                    voucher.icon,
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF561C17,
                      ),
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      12,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.status
                            .toUpperCase(),
                        style:
                            TextStyle(
                          color:
                              explicitlyUnavailable
                                  ? const Color(
                                      0xFF987865,
                                    )
                                  : const Color(
                                      0xFF561C17,
                                    ),
                          fontSize:
                              7.5,
                          letterSpacing:
                              1.1,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      const SizedBox(
                        height:
                            4,
                      ),

                      Text(
                        voucher.value,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B211B,
                          ),
                          fontSize:
                              18,
                          height:
                              1.1,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),

                      if (voucher.campaignName
                              ?.trim()
                              .isNotEmpty ==
                          true) ...[
                        const SizedBox(
                          height:
                              4,
                        ),

                        Text(
                          voucher.campaignName!,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF6C4936,
                            ),
                            fontSize:
                                9.5,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],

                      if (voucher.sellerName
                              ?.trim()
                              .isNotEmpty ==
                          true) ...[
                        const SizedBox(
                          height:
                              3,
                        ),

                        Text(
                          'From ${voucher.sellerName}',
                          maxLines:
                              1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF987865,
                            ),
                            fontSize:
                                8.5,
                          ),
                        ),
                      ],

                      const SizedBox(
                        height:
                            5,
                      ),

                      Text(
                        voucher.condition,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF987865,
                          ),
                          fontSize:
                              9.5,
                          height:
                              1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height:
                1,
            color:
                Color(
              0xFFEADCCC,
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              15,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        10,
                    vertical:
                        8,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFF6EFE7,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFFEADCCC,
                      ),
                    ),
                  ),
                  child:
                      Row(
                    children: [
                      const Icon(
                        Icons
                            .local_offer_outlined,
                        color:
                            Color(
                          0xFF561C17,
                        ),
                        size:
                            16,
                      ),

                      const SizedBox(
                        width:
                            7,
                      ),

                      Expanded(
                        child:
                            Text(
                          voucher.code,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF561C17,
                            ),
                            fontSize:
                                10,
                            letterSpacing:
                                0.7,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (voucher.expires
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        7,
                  ),

                  Text(
                    'Expires ${voucher.expires}',
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFA99386,
                      ),
                      fontSize:
                          8.5,
                    ),
                  ),
                ],

                if (canOpen) ...[
                  const SizedBox(
                    height:
                        12,
                  ),

                  SizedBox(
                    height:
                        44,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          onUse,
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(
                          0xFF561C17,
                        ),
                        foregroundColor:
                            Colors.white,
                        elevation:
                            0,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                        ),
                      ),
                      icon:
                          const Icon(
                        Icons
                            .shopping_bag_outlined,
                        size:
                            16,
                      ),
                      label:
                          const Text(
                        'Shop With Voucher',
                        style:
                            TextStyle(
                          fontSize:
                              10.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height:
                        7,
                  ),

                  const Text(
                    'The voucher is still validated by the server during Checkout.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Color(
                        0xFFA99386,
                      ),
                      fontSize:
                          8,
                      height:
                          1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardPanel
    extends StatelessWidget {
  final String title;

  final IconData icon;

  final Widget child;

  const _RewardPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          19,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                    37,
                height:
                    37,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                alignment:
                    Alignment.center,
                child:
                    Icon(
                  icon,
                  color:
                      const Color(
                    0xFF561C17,
                  ),
                  size:
                      18,
                ),
              ),

              const SizedBox(
                width:
                    9,
              ),

              Expanded(
                child:
                    Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        14,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                15,
          ),

          child,
        ],
      ),
    );
  }
}

class _VoucherHistoryRow
    extends StatelessWidget {
  final VoucherHistoryData item;

  const _VoucherHistoryRow({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            12,
      ),
      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFEFE1D5,
            ),
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  item.voucher,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Text(
                item.status,
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF987865,
                  ),
                  fontSize:
                      8.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                5,
          ),

          Text(
            item.benefit,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF6C4936,
              ),
              fontSize:
                  9.5,
            ),
          ),

          if (item.order
              .trim()
              .isNotEmpty) ...[
            const SizedBox(
              height:
                  3,
            ),

            Text(
              item.order,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFFA99386,
                ),
                fontSize:
                    8.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EarnPointCard
    extends StatelessWidget {
  final String value;
  final String label;

  final IconData icon;

  const _EarnPointCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                39,
            height:
                39,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF1E4D7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                Icon(
              icon,
              color:
                  const Color(
                0xFF561C17,
              ),
              size:
                  18,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Text(
              label,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF987865,
                ),
                fontSize:
                    10,
              ),
            ),
          ),

          const SizedBox(
            width:
                8,
          ),

          Text(
            value,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF561C17,
              ),
              fontSize:
                  18,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsActivityRow
    extends StatelessWidget {
  final PointsActivityData activity;

  const _PointsActivityRow({
    required this.activity,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            12,
      ),
      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFEFE1D5,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                38,
            height:
                38,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF6EFE7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                Icon(
              activity.negative
                  ? Icons
                      .remove_rounded
                  : Icons
                      .add_rounded,
              color:
                  activity.negative
                      ? const Color(
                          0xFF987865,
                        )
                      : const Color(
                          0xFF561C17,
                        ),
              size:
                  17,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  activity.label,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        10.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                if (activity.date
                    .trim()
                    .isNotEmpty) ...[
                  const SizedBox(
                    height:
                        3,
                  ),

                  Text(
                    activity.date,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFA99386,
                      ),
                      fontSize:
                          8.5,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Text(
            activity.amount,
            style:
                TextStyle(
              color:
                  activity.negative
                      ? const Color(
                          0xFF987865,
                        )
                      : const Color(
                          0xFF561C17,
                        ),
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashbackBalanceRow
    extends StatelessWidget {
  final String label;
  final String value;

  final IconData icon;

  final bool emphasized;

  const _CashbackBalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            emphasized
                ? const Color(
                    0xFFF6EFE7,
                  )
                : const Color(
                    0xFFFFFDF9,
                  ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFEADCCC,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                38,
            height:
                38,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF1E4D7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                Icon(
              icon,
              color:
                  const Color(
                0xFF561C17,
              ),
              size:
                  18,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Text(
              label,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF987865,
                ),
                fontSize:
                    10,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(
            width:
                8,
          ),

          Text(
            value,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF561C17,
              ),
              fontSize:
                  12,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashbackActivityRow
    extends StatelessWidget {
  final CashbackActivityData activity;

  const _CashbackActivityRow({
    required this.activity,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            12,
      ),
      decoration:
          const BoxDecoration(
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFEFE1D5,
            ),
          ),
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  activity.order,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        10.5,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              Text(
                activity.amount,
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF561C17,
                  ),
                  fontSize:
                      10.5,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                5,
          ),

          Row(
            children: [
              Expanded(
                child:
                    Text(
                  activity.type,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF987865,
                    ),
                    fontSize:
                        9,
                  ),
                ),
              ),

              if (activity.date
                  .trim()
                  .isNotEmpty)
                Text(
                  activity.date,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFFA99386,
                    ),
                    fontSize:
                        8.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SimpleEmptyRow
    extends StatelessWidget {
  final String title;
  final String subtitle;

  final String? trailing;

  const _SimpleEmptyRow({
    required this.title,
    required this.subtitle,
  }) : trailing = null;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            11,
      ),
      child:
          Row(
        children: [
          Container(
            width:
                42,
            height:
                42,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF6EFE7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                const Icon(
              Icons
                  .history_rounded,
              color:
                  Color(
                0xFF987865,
              ),
              size:
                  19,
            ),
          ),

          const SizedBox(
            width:
                10,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF3B211B,
                    ),
                    fontSize:
                        10.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      3,
                ),

                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF987865,
                    ),
                    fontSize:
                        8.5,
                    height:
                        1.4,
                  ),
                ),
              ],
            ),
          ),

          if (trailing !=
              null) ...[
            const SizedBox(
              width:
                  8,
            ),

            Text(
              trailing!,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFF561C17,
                ),
                fontSize:
                    9.5,
                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}