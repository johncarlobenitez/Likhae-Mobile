<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('announcements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('created_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('title', 255);
            $table->longText('body');
            $table->timestamp('published_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['is_active', 'published_at']);
        });

        Schema::create('platform_policies', function (Blueprint $table) {
            $table->id();
            $table->foreignId('published_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('title', 255);
            $table->string('version', 50);
            $table->longText('body');
            $table->timestamp('effective_at')->nullable();
            $table->timestamp('published_at')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['title', 'version']);
            $table->index(['is_active', 'effective_at']);
        });

        Schema::create('platform_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key', 120)->unique();
            $table->text('value')->nullable();
            $table->string('value_type', 30)->default('string');
            $table->foreignId('updated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        DB::table('platform_settings')->insert([
            [
                'key' => 'commission_rate',
                'value' => '0.10',
                'value_type' => 'decimal',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'key' => 'default_currency',
                'value' => 'PHP',
                'value_type' => 'string',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('type', 100);
            $table->string('title', 255);
            $table->text('message');
            $table->string('reference_type', 100)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('action_url', 500)->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'read_at']);
            $table->index(['reference_type', 'reference_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('platform_settings');
        Schema::dropIfExists('platform_policies');
        Schema::dropIfExists('announcements');
    }
};
