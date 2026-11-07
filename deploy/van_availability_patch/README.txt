Van rider availability deployment patch

Production files (copy into the Laravel project root, preserving folders):
- app/Support/RiderVehicleType.php
- app/Http/Controllers/Api/RiderAvailabilityApiController.php
- app/Services/Fulfillment/TransferManifestService.php
- app/Http/Controllers/Logistics/TransferController.php
- routes/api.php

The tests/ folder contains regression tests for the change. It is optional for production upload and can be kept for validation in your development/staging checkout.

After uploading the production files, clear Laravel's route/config caches if your deployment process requires it, then verify van riders can switch online/offline and that offline vans are excluded from new transfer assignments.
