# Mobile authentication deployment bundle

This bundle contains the Laravel files for the mobile Google sign-in routes and forgot-password API.

## Files included

- `routes/api.php`: Google exchange and password reset API routes.
- `routes/web.php`: mobile Google authorization route.
- `app/Http/Controllers/Api/MobileAuthController.php`: Google exchange and password reset handlers.
- `app/Http/Controllers/Auth/MobileGoogleAuthenticationController.php`: mobile Google OAuth flow.
- `app/Http/Controllers/Auth/GoogleAuthenticationController.php`: dispatches the OAuth callback to the mobile flow when appropriate.

## Deploy

Copy each file to the same path in the live Laravel project. Back up the live files first. If the live copy has newer unrelated routes or controller code, merge the authentication additions instead of replacing the whole file.

Do not upload or replace `.env` from this bundle. Keep the server's Google and mail configuration on the server.

After upload, run:

```bash
php artisan optimize:clear
php artisan route:list --path=auth
```

The output should include `GET auth/google/mobile`, `POST api/v1/auth/google/exchange`, and `POST api/v1/auth/password/email`.
