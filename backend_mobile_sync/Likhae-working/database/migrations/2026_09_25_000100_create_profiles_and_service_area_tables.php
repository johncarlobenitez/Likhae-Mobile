<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->foreignId('parent_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('name', 150);
            $table->string('slug', 180)->unique();
            $table->text('description')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->index(['parent_id', 'is_active']);
        });

        Schema::create('seller_application_data', function (Blueprint $table) {
            $table->id();
            $table->foreignId('registration_application_id')->unique()->constrained('registration_applications')->cascadeOnDelete();
            $table->foreignId('category_id')->constrained('categories')->restrictOnDelete();
            $table->string('business_name', 200);
            $table->string('business_registration_number', 100)->nullable();
            $table->timestamps();
        });

        Schema::create('logistics_application_data', function (Blueprint $table) {
            $table->id();
            $table->foreignId('registration_application_id')->unique()->constrained('registration_applications')->cascadeOnDelete();
            $table->foreignId('business_address_id')->nullable()->constrained('addresses')->nullOnDelete();
            $table->string('business_name', 200);
            $table->string('business_registration_number', 100)->nullable();
            $table->string('dti_registration_number', 100)->nullable();
            $table->timestamps();
        });

        Schema::create('seller_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->restrictOnDelete();
            $table->foreignId('primary_category_id')->constrained('categories')->restrictOnDelete();
            $table->foreignId('business_address_id')->nullable()->constrained('addresses')->nullOnDelete();
            $table->string('business_name', 200);
            $table->string('business_registration_number', 100)->nullable()->unique();
            $table->enum('status', ['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'])->default('PENDING');
            $table->foreignId('approved_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'primary_category_id']);
        });

        Schema::create('logistics_centers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_user_id')->unique()->constrained('users')->restrictOnDelete();
            $table->foreignId('address_id')->nullable()->constrained('addresses')->nullOnDelete();
            $table->string('code', 50)->unique();
            $table->string('business_name', 200);
            $table->string('business_registration_number', 100)->nullable()->unique();
            $table->string('dti_registration_number', 100)->nullable()->unique();
            $table->enum('status', ['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'])->default('PENDING');
            $table->foreignId('approved_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();

            $table->index('status');
        });

        Schema::create('rider_application_data', function (Blueprint $table) {
            $table->id();
            $table->foreignId('registration_application_id')->unique()->constrained('registration_applications')->cascadeOnDelete();
            $table->foreignId('target_logistics_center_id')->constrained('logistics_centers')->restrictOnDelete();
            $table->string('vehicle_type', 100);
            $table->string('plate_number', 50);
            $table->string('drivers_license_number', 100);
            $table->timestamps();

            $table->index('plate_number');
            $table->index('drivers_license_number');
        });

        Schema::create('rider_profiles', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->restrictOnDelete();
            $table->foreignId('logistics_center_id')->constrained('logistics_centers')->restrictOnDelete();
            $table->string('vehicle_type', 100);
            $table->string('plate_number', 50)->unique();
            $table->string('drivers_license_number', 100)->unique();
            $table->enum('status', ['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'])->default('PENDING');
            $table->foreignId('approved_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable();
            $table->timestamps();

            $table->index(['logistics_center_id', 'status']);
        });

        Schema::create('service_areas', function (Blueprint $table) {
            $table->id();
            $table->foreignId('logistics_center_id')->constrained('logistics_centers')->cascadeOnDelete();
            $table->string('code', 50);
            $table->string('name', 150);
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['logistics_center_id', 'code']);
            $table->index(['logistics_center_id', 'is_active']);
        });

        Schema::create('service_area_locations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('service_area_id')->constrained('service_areas')->cascadeOnDelete();
            $table->string('province_code', 50);
            $table->string('province_name', 150);
            $table->string('municipality_code', 50);
            $table->string('municipality_name', 150);
            $table->string('barangay_code', 50);
            $table->string('barangay_name', 150);
            $table->timestamps();

            $table->unique(['service_area_id', 'barangay_code']);
            $table->index(['province_code', 'municipality_code', 'barangay_code'], 'service_area_locations_geo_codes_idx');
        });

        Schema::create('rider_area_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('rider_profile_id')->constrained('rider_profiles')->cascadeOnDelete();
            $table->foreignId('service_area_id')->constrained('service_areas')->cascadeOnDelete();
            $table->foreignId('assigned_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->boolean('is_active')->default(true);
            $table->timestamp('assigned_at');
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();

            $table->index(['service_area_id', 'is_active']);
            $table->index(['rider_profile_id', 'is_active']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rider_area_assignments');
        Schema::dropIfExists('service_area_locations');
        Schema::dropIfExists('service_areas');
        Schema::dropIfExists('rider_profiles');
        Schema::dropIfExists('rider_application_data');
        Schema::dropIfExists('logistics_centers');
        Schema::dropIfExists('seller_profiles');
        Schema::dropIfExists('logistics_application_data');
        Schema::dropIfExists('seller_application_data');
        Schema::dropIfExists('categories');
    }
};
