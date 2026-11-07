Likhae Laravel Smart Help API update

Extract this ZIP at the Laravel project root and allow it to overwrite the matching PHP files.
Keep the folder paths inside the ZIP intact.

Included production files:
- routes/api.php
- app/Http/Controllers/Communication/SmartMessagingController.php
- app/Services/Communication/SmartMessagingService.php
- database/migrations/2026_11_05_000100_add_homepage_carousel_fields_to_vouchers.php

The voucher migration file fixes a missing COLUMNS list found in the latest project.
The feature test is in the updated project copy, but is intentionally excluded from this production upload bundle.

After uploading, clear Laravel's route/config cache if those caches are enabled.