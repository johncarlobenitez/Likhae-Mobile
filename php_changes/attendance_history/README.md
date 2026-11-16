# Attendance history API fields

The mobile fix reads the existing `data.history` response, so shifts display even before this PHP update is uploaded. The existing endpoint omits saved shift rates and payroll details; those fields will remain unavailable until this update is deployed.

Source: `Likhae-working (10).zip`, downloaded November 16, 2026. The only change to `MobileWorkflowApiController.php` adds saved rate, region, and payroll/overtime fields to `attendance()` using the same session and payroll records as the Laravel timekeeping page. Authentication and rider-scoped history are unchanged.

Copy `app/Http/Controllers/Api/MobileWorkflowApiController.php` into the corresponding Laravel project path. If that controller has newer server changes, merge only the added fields in `attendance()` instead of replacing the entire file. No migration or rate recalculation is needed.

Verify as an authenticated inter-hub rider: GET `/api/v1/rider/attendance` returns `data.history` with `daily_rate_snapshot`, `region_type`, and `payroll`. Compare a closed and active shift with the web timekeeping history. Rebuild/install the mobile app to use the corrected parser.
