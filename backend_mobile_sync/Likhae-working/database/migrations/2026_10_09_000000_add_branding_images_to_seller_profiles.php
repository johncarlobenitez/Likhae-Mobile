<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table): void {
            $table->string('avatar_path')->nullable();
            $table->string('banner_path')->nullable();
            $table->string('seller_type', 30)->nullable();
            $table->string('tin', 15)->nullable()->unique();
            $table->string('tagline', 180)->nullable();
            $table->text('description')->nullable();
            $table->string('location')->nullable();
            $table->string('business_days', 80)->nullable();
            $table->string('business_hours', 80)->nullable();
            $table->unsignedTinyInteger('processing_days')->default(1);
            $table->string('order_cutoff', 80)->nullable();
            $table->boolean('vacation_mode')->default(false);
            $table->boolean('auto_accept_orders')->default(false);
            $table->boolean('store_visibility')->default(true);
        });

        Schema::table('seller_application_data', function (Blueprint $table): void {
            $table->string('seller_type', 30)->nullable();
            $table->string('tin', 15)->nullable();
        });

        Schema::table('logistics_centers', function (Blueprint $table): void {
            $table->string('tin', 15)->nullable()->unique();
        });
    }

    public function down(): void
    {
        Schema::table('seller_profiles', function (Blueprint $table): void {
            $table->dropUnique(['tin']);
            $table->dropColumn([
                'avatar_path', 'banner_path', 'seller_type', 'tin', 'tagline', 'description',
                'location', 'business_days', 'business_hours', 'processing_days', 'order_cutoff',
                'vacation_mode', 'auto_accept_orders', 'store_visibility',
            ]);
        });

        Schema::table('seller_application_data', function (Blueprint $table): void {
            $table->dropColumn(['seller_type', 'tin']);
        });

        Schema::table('logistics_centers', function (Blueprint $table): void {
            $table->dropUnique(['tin']);
            $table->dropColumn('tin');
        });
    }
};
