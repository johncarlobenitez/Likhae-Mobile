<?php

require __DIR__.'/../../vendor/autoload.php';
$app = require __DIR__.'/../../bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$database = Illuminate\Support\Facades\DB::connection()->getDatabaseName();
$tables = Illuminate\Support\Facades\DB::select(
    "SELECT table_name, table_type FROM information_schema.tables WHERE table_schema = ? ORDER BY table_name",
    [$database],
);

echo json_encode([
    'database' => $database,
    'count' => count($tables),
    'tables' => array_map(static fn ($row) => (array) $row, $tables),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), PHP_EOL;
