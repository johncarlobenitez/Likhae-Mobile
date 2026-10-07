LARAVEL PHP UPLOAD FILES

Copy the folders/files here into:

  C:\xampp\htdocs\Likhae-working

Files included:

  routes/api.php
  app/Http/Controllers/Api/MobileAuthController.php
  app/Http/Controllers/Api/RiderApiController.php
  app/Http/Requests/StoreRegistrationRequest.php

After copying, run from the Laravel project:

  php artisan route:clear
  php artisan config:clear
  php artisan cache:clear

Registration endpoint added:

  POST /api/v1/auth/register

Rider notification endpoints added:

  GET  /api/v1/rider/notifications
  POST /api/v1/rider/notifications/read-all

These routes require the rider's authenticated API token. Notifications are
read from the authenticated user's notifications table.

The mobile Flutter files remain in the Flutter project and are not included here.
