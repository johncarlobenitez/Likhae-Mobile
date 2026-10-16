# Laravel deployment files

This folder keeps Laravel-only deployment material separate from the Flutter app source. These files are not imported by the mobile app.

## Structure

- `google-auth/` contains the Google authentication controller replacement and its instructions.
- `rider/product-photos-earnings-update-2026-10-15/` contains the rider API update package.
- `rider/archives/` contains the ZIP copy of that rider API package.
- `rider/sync/patch/` contains rider synchronization patch files and its diagnostic script.
- `rider/sync/backup/` contains the corresponding backup copies.

Each deployable package keeps its Laravel `app/`, `routes/`, `database/`, or `scripts/` paths intact so its files can be copied to the matching Laravel project paths.

## Mobile authentication prerequisites

- Google sign-in uses Laravel Socialite and returns to `likhae://auth/google-callback`. Set `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, and `GOOGLE_REDIRECT_URI` in the Laravel server environment. Register the HTTPS callback URL (`https://likhae.online/auth/google/callback`, or the matching URL for your deployment) with the Google OAuth client.
- Password recovery calls `POST /api/v1/auth/password/email`. Laravel sends its normal reset email, and the user completes the reset on the web form. Configure a working Laravel mail transport in the server environment.
- Keep Google credentials and mail credentials on the Laravel server; do not put them in Flutter build defines.
