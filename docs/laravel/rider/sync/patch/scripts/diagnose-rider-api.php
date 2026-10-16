<?php

declare(strict_types=1);

// Local CLI diagnostic only. No public route, login token or database writes.
if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

use App\Http\Controllers\Api\RiderApiController;
use App\Http\Middleware\EnsureRiderOperationalType;
use App\Models\User;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

$root = dirname(__DIR__);
if (! is_file($root.'/vendor/autoload.php')) {
    fwrite(STDERR, "Run this script from the installed Laravel project on the tunnel host PC.\n");
    exit(1);
}

require $root.'/vendor/autoload.php';
$app = require $root.'/bootstrap/app.php';
$app->make(Kernel::class)->bootstrap();

$identity = trim((string) ($argv[1] ?? readline('Rider user ID or email (local lookup): ')));
if ($identity === '') {
    fwrite(STDERR, "A rider user ID or email is required.\n");
    exit(1);
}

$user = ctype_digit($identity)
    ? User::query()->find((int) $identity)
    : User::query()->whereRaw('LOWER(email) = ?', [mb_strtolower($identity)])->first();

if (! $user || ! $user->isAccountType(User::TYPE_RIDER) || ! $user->isActive()) {
    fwrite(STDERR, "No active rider account matched this local database.\n");
    exit(1);
}

printf("Project: %s\nAPP_URL: %s\n", $root, config('app.url'));
printf("Rider user ID: %d; profile ID: %s; status: %s; vehicle: %s\n",
    $user->id, $user->riderProfile?->id ?? 'missing',
    $user->riderProfile?->status ?? 'missing', $user->riderProfile?->vehicle_type ?? 'missing');
echo "Local controller timings below exclude Cloudflare, HTTP and bearer-token authentication.\n";

$queries = 0;
$databaseMs = 0.0;
DB::listen(function (QueryExecuted $event) use (&$queries, &$databaseMs): void {
    $queries++;
    $databaseMs += $event->time;
});
Auth::setUser($user);
$failed = false;
foreach (['dashboard', 'assignments', 'pickups', 'history', 'earnings'] as $method) {
    $queries = 0;
    $databaseMs = 0.0;
    $start = microtime(true);
    try {
        $request = Request::create('/api/v1/rider/'.$method, 'GET', ['per_page' => 20]);
        $request->headers->set('Accept', 'application/json');
        $request->setUserResolver(static fn () => $user);
        $app->instance('request', $request);
        $call = fn (Request $request) => $app->call(
            [app(RiderApiController::class), $method], ['request' => $request]
        );
        $response = $method === 'earnings'
            ? $call($request)
            : app(EnsureRiderOperationalType::class)->handle($request, $call, 'LOCAL_BARANGAY');
        $payload = $response->getData(true);
        $rows = $payload['data']['items'] ?? $payload['data']['recent_parcels'] ?? [];
        printf("%s: HTTP %d; rows=%d; total=%.3fs; queries=%d; database=%.1fms\n",
            $method, $response->getStatusCode(), count($rows),
            microtime(true) - $start, $queries, $databaseMs);
        if ($response->getStatusCode() >= 400) {
            $failed = true;
            echo '  '.($payload['message'] ?? 'Request failed.')."\n";
        }
    } catch (Throwable $error) {
        $failed = true;
        report($error);
        printf("%s: failed (%s); total=%.3fs; queries=%d; database=%.1fms. See storage/logs/laravel.log.\n",
            $method, get_class($error), microtime(true) - $start, $queries, $databaseMs);
    }
}
exit($failed ? 1 : 0);
