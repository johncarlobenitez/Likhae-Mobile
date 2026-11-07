Buyer and rider address map API deployment patch

Copy these files into the Laravel project root, preserving their folders:
- routes/api.php
- app/Http/Controllers/Api/MapProxyController.php
- config/geoapify.php

The API route is GET /api/v1/maps/geocode. Ensure the Laravel server environment contains GEOAPIFY_API_KEY. Do not put this key in the Flutter app.

After upload, clear Laravel's route and config caches:
  php artisan route:clear
  php artisan config:clear

If production uses cached configuration, rebuild it after confirming GEOAPIFY_API_KEY is set:
  php artisan config:cache

Verify route registration with:
  php artisan route:list --path=api/v1/maps/geocode

If the app still reports a 404 after the route is registered, rebuild Flutter with API_BASE_URL pointing to that same Laravel host and ending in /api/v1.
