<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('api_token_hash', 64)->nullable()->unique();
            $table->timestamp('api_token_expires_at')->nullable();
            $table->json('notification_preferences')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->dropUnique(['api_token_hash']);
            $table->dropColumn(['api_token_hash', 'api_token_expires_at', 'notification_preferences']);
        });
    }
};