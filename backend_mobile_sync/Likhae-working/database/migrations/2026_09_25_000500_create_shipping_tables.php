<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const SHIPMENT_STATUSES = [
        'PLACED',
        'CONFIRMED',
        'PREPARING',
        'READY_FOR_PICKUP',
        'PICKED_UP',
        'AT_SORTING_CENTER',
        'SORTED',
        'ASSIGNED_TO_RIDER',
        'OUT_FOR_DELIVERY',
        'DELIVERED',
        'COMPLETED',
        'DELIVERY_FAILED',
        'RETURNED',
    ];

    public function up(): void
    {
        Schema::create('shipments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_order_id')->unique()->constrained('seller_orders')->restrictOnDelete();
            $table->string('tracking_number', 100)->unique();
            $table->foreignId('logistics_center_id')->nullable()->constrained('logistics_centers')->nullOnDelete();
            $table->foreignId('service_area_id')->nullable()->constrained('service_areas')->nullOnDelete();
            $table->string('destination_province_code', 50);
            $table->string('destination_province_name', 150);
            $table->string('destination_municipality_code', 50);
            $table->string('destination_municipality_name', 150);
            $table->string('destination_barangay_code', 50);
            $table->string('destination_barangay_name', 150);
            $table->enum('current_status', self::SHIPMENT_STATUSES)->default('PLACED');
            $table->timestamps();

            $table->index(['logistics_center_id', 'current_status']);
            $table->index(['service_area_id', 'current_status']);
            $table->index(['destination_province_code', 'destination_municipality_code', 'destination_barangay_code'], 'shipments_destination_geo_codes_idx');
        });

        Schema::create('pickup_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->foreignId('requested_by_user_id')->constrained('users')->restrictOnDelete();
            $table->enum('status', ['PENDING', 'APPROVED', 'REJECTED', 'CANCELLED', 'FULFILLED'])->default('PENDING');
            $table->foreignId('reviewed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('requested_at')->nullable();
            $table->timestamp('reviewed_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index(['shipment_id', 'status']);
            $table->index(['status', 'requested_at']);
        });

        Schema::create('rider_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->foreignId('rider_profile_id')->constrained('rider_profiles')->restrictOnDelete();
            $table->enum('assignment_type', ['PICKUP', 'DELIVERY']);
            $table->enum('status', ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED', 'REJECTED', 'CANCELLED'])->default('ASSIGNED');
            $table->foreignId('assigned_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('assigned_at')->nullable();
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->text('rejection_reason')->nullable();
            $table->timestamps();

            $table->index(['shipment_id', 'assignment_type', 'status'], 'rider_assignments_shipment_type_status_idx');
            $table->index(['rider_profile_id', 'status']);
        });

        Schema::create('waybills', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->foreignId('generated_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedInteger('format_version')->default(1);
            $table->string('label_path', 500);
            $table->timestamp('generated_at')->nullable();
            $table->timestamps();

            $table->unique(['shipment_id', 'format_version']);
        });

        Schema::create('parcel_scans', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->foreignId('scanned_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('logistics_center_id')->nullable()->constrained('logistics_centers')->nullOnDelete();
            $table->foreignId('rider_assignment_id')->nullable()->constrained('rider_assignments')->nullOnDelete();
            $table->string('scan_type', 100);
            $table->enum('scan_method', ['QR', 'BARCODE', 'MANUAL']);
            $table->string('scanned_code', 150);
            $table->enum('result', ['SUCCESS', 'FAILED']);
            $table->text('notes')->nullable();
            $table->timestamp('scanned_at');
            $table->timestamps();

            $table->index(['shipment_id', 'scanned_at']);
            $table->index(['logistics_center_id', 'scanned_at']);
        });

        Schema::create('shipment_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->enum('status', self::SHIPMENT_STATUSES);
            $table->foreignId('actor_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('logistics_center_id')->nullable()->constrained('logistics_centers')->nullOnDelete();
            $table->foreignId('rider_assignment_id')->nullable()->constrained('rider_assignments')->nullOnDelete();
            $table->text('notes')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();

            $table->index(['shipment_id', 'occurred_at']);
            $table->index(['status', 'occurred_at']);
        });

        Schema::create('delivery_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shipment_id')->constrained('shipments')->cascadeOnDelete();
            $table->foreignId('rider_assignment_id')->constrained('rider_assignments')->restrictOnDelete();
            $table->unsignedInteger('attempt_number');
            $table->enum('status', ['DELIVERED', 'FAILED', 'RESCHEDULED', 'RETURNED']);
            $table->text('failure_reason')->nullable();
            $table->string('proof_path', 500)->nullable();
            $table->timestamp('attempted_at');
            $table->timestamp('next_attempt_at')->nullable();
            $table->timestamps();

            $table->unique(['shipment_id', 'attempt_number']);
            $table->index(['rider_assignment_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_attempts');
        Schema::dropIfExists('shipment_events');
        Schema::dropIfExists('parcel_scans');
        Schema::dropIfExists('waybills');
        Schema::dropIfExists('rider_assignments');
        Schema::dropIfExists('pickup_requests');
        Schema::dropIfExists('shipments');
    }
};
