<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->enum('account_type', ['BUYER', 'SELLER', 'ADMIN', 'LOGISTICS', 'RIDER']);
            $table->string('first_name', 100);
            $table->string('middle_initial', 10)->nullable();
            $table->string('last_name', 100);
            $table->enum('sex', ['MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'])->nullable();
            $table->string('email')->unique();
            $table->string('contact_number', 30)->unique();
            $table->date('birthday');
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');
            $table->enum('status', ['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'])->default('PENDING');
            $table->rememberToken();
            $table->timestamps();

            $table->index(['account_type', 'status']);
            $table->index(['last_name', 'first_name']);
        });

        Schema::create('addresses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('label', 50)->nullable();
            $table->string('recipient_name', 200);
            $table->string('contact_number', 30);
            $table->string('province_code', 50);
            $table->string('province_name', 150);
            $table->string('municipality_code', 50);
            $table->string('municipality_name', 150);
            $table->string('barangay_code', 50);
            $table->string('barangay_name', 150);
            $table->string('postal_code', 20)->nullable();
            $table->string('house_number', 100)->nullable();
            $table->string('street_address', 255);
            $table->string('landmark', 255)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->boolean('is_default')->default(false);
            $table->timestamps();

            $table->index(['user_id', 'is_default']);
            $table->index(['province_code', 'municipality_code', 'barangay_code'], 'addresses_geo_codes_idx');
        });

        Schema::create('registration_applications', function (Blueprint $table) {
            $table->id();
            $table->string('application_number', 50)->unique();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('status', ['PENDING', 'UNDER_REVIEW', 'APPROVED', 'REJECTED', 'CANCELLED'])->default('PENDING');
            $table->foreignId('reviewed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('decision_notes')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
            $table->index(['status', 'submitted_at']);
        });

        Schema::create('application_documents', function (Blueprint $table) {
            $table->id();
            $table->foreignId('registration_application_id')->constrained('registration_applications')->cascadeOnDelete();
            $table->string('document_type', 100);
            $table->string('file_path', 500);
            $table->string('original_name', 255)->nullable();
            $table->string('mime_type', 100)->nullable();
            $table->enum('verification_status', ['PENDING', 'VERIFIED', 'REJECTED'])->default('PENDING');
            $table->foreignId('verified_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('verified_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamps();

            $table->index(['registration_application_id', 'document_type'], 'application_documents_app_type_idx');
            $table->index('verification_status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('application_documents');
        Schema::dropIfExists('registration_applications');
        Schema::dropIfExists('addresses');
        Schema::dropIfExists('users');
    }
};
