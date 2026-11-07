<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('commission_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_order_id')->unique()->constrained('seller_orders')->restrictOnDelete();
            $table->decimal('commission_rate', 5, 4)->default(0.1000);
            $table->decimal('commissionable_amount', 12, 2);
            $table->decimal('commission_amount', 12, 2);
            $table->enum('status', ['PENDING', 'SETTLED', 'VOID'])->default('PENDING');
            $table->timestamp('calculated_at')->nullable();
            $table->timestamp('settled_at')->nullable();
            $table->timestamps();

            $table->index(['status', 'calculated_at']);
        });

        Schema::create('rider_earnings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('rider_assignment_id')->unique()->constrained('rider_assignments')->restrictOnDelete();
            $table->foreignId('rider_profile_id')->constrained('rider_profiles')->restrictOnDelete();
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['PENDING', 'PAID', 'VOID'])->default('PENDING');
            $table->timestamp('earned_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamps();

            $table->index(['rider_profile_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('rider_earnings');
        Schema::dropIfExists('commission_transactions');
    }
};
