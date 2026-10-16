Laravel Google Authentication controller replacement

Copy this folder's app/ directory into the Laravel project root and overwrite:

app/Http/Controllers/Auth/GoogleAuthenticationController.php

This version preserves the web Buyer Google sign-in and dispatches mobile OAuth
callbacks to MobileGoogleAuthenticationController when the mobile session is
present.

This file alone does not add the /auth/google/mobile route. The Laravel project
must also have that route in routes/web.php and the matching
MobileGoogleAuthenticationController.php file.
