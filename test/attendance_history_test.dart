import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/services/workspace_mobile_service.dart';

void main() {
  test('reads Laravel dashboard history and keeps saved rates', () {
    final rows = WorkspaceMobileService.attendanceRows({
      'data': {
        'effective_daily_rate': 900,
        'open_session': {'id': 2},
        'estimated_current_pay': 630.22,
        'history': [
          {'id': 2, 'daily_rate_snapshot': 645, 'gross_pay': null},
          {'id': 1, 'gross_pay': 1717.31, 'payroll_status': 'REVIEW_REQUIRED'},
        ],
      },
    });
    expect(rows, hasLength(2));
    expect(rows.first['daily_rate_snapshot'], 645);
    expect(rows.first['estimated_current_pay'], 630.22);
    expect(rows.last['gross_pay'], 1717.31);
    expect(rows.last['payroll']['status'], 'REVIEW_REQUIRED');
    expect(rows.last.containsKey('daily_rate_snapshot'), isFalse);
    expect(rows.last.containsKey('estimated_current_pay'), isFalse);
  });

  test('preserves flat API history and detailed payroll', () {
    final rows = WorkspaceMobileService.attendanceRows({
      'data': [
        {
          'id': 1,
          'payroll': {'status': 'PAID', 'amount': 645},
        },
      ],
    });
    expect(rows.single['payroll']['amount'], 645);
  });

  test('distinguishes empty history from malformed data', () {
    expect(
      WorkspaceMobileService.attendanceRows({
        'data': {'history': []},
      }),
      isEmpty,
    );
    expect(
      () => WorkspaceMobileService.attendanceRows({'data': {}}),
      throwsFormatException,
    );
  });
}
