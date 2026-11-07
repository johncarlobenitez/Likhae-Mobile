<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('logistics_centers', function (Blueprint $table): void {
            $table->decimal('shipping_fee', 12, 2)->default(65)->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('logistics_centers', function (Blueprint $table): void {
            $table->dropColumn('shipping_fee');
        });
    }
};
