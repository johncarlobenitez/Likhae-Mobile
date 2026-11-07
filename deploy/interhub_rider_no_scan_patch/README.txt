Inter-Hub rider no-scan patch

Copy the files in this folder into the same relative paths in the Laravel project:

- app/Http/Controllers/Api/RiderTransferApiController.php
- app/Services/Fulfillment/TransferManifestService.php

The existing routes/api.php already registers the rider transfer start endpoint and does not need to change. The API controller now starts transport without requiring rider-submitted parcel codes. The manifest service still requires every parcel to have been scanned and released by the origin hub; destination receipt scans remain unchanged.
