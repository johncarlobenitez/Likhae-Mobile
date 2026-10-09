LIKHAE Laravel upload bundle

Copy the contents of this folder into the root of the existing Laravel project.
Keep the directory structure exactly as provided.

Included changes:
- Buyer address latitude/longitude validation and API payload
- Delivery coordinates copied into order addresses
- Rider pickup/delivery coordinates returned to the mobile API
- Migration for latitude/longitude on order_addresses
- Existing mobile registration OTP and Philippine address API files

After copying the files:

1. Check .env and configure the real database connection.
2. Make sure storage/logs is writable by PHP.
3. Run:

   php artisan migrate --force
   php artisan optimize:clear

Do not upload or replace .env, vendor, storage, or the whole database folder.
