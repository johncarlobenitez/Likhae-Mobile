LIKHAE Smart Messaging API patch

Why this patch is needed
The production API currently returns its JSON fallback 404 for
/api/v1/buyer/messages/{conversation}/smart-help. The mobile Smart Help panel
uses this API route to load suggested questions.

Install at the Laravel project root
1. Preserve the folder paths in this package and copy the two app/ files into
   the matching Laravel directories.
2. Add the one-line include from routes/api.php.patch to routes/api.php inside
   the existing v1 bearer-token and policy-acceptance middleware group, directly
   after require __DIR__.'/mobile_parity.php';
   Do not replace routes/api.php wholesale; this patch intentionally leaves all
   other production routes intact.
3. Clear the route cache with: php artisan route:clear

The routes inherit the existing API token and policy middleware. Each buyer and
rider endpoint also checks the workspace role and uses per-action throttling.
No database migration is included because the Smart Messaging tables and service
already exist in the Laravel project.

Verify after installation
- php artisan route:list --path=smart-help should show buyer and rider GET,
  answer, feedback, and handoff routes.
- An unauthenticated GET to /api/v1/buyer/messages/1/smart-help should return
  401 (authentication required), not the API endpoint not found 404.
