<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('seller_compliance_cases', function (Blueprint $table) {
            $table->id();
            $table->string('case_number', 60)->unique();
            $table->foreignId('seller_profile_id')->constrained('seller_profiles')->restrictOnDelete();
            $table->foreignId('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->foreignId('opened_by_admin_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('violation_type', 120);
            $table->longText('description');
            $table->enum('status', ['OPEN', 'UNDER_REVIEW', 'RESOLVED', 'CLOSED'])->default('OPEN');
            $table->timestamp('opened_at');
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->index(['seller_profile_id', 'status']);
            $table->index(['product_id', 'status']);
        });

        Schema::create('seller_compliance_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_compliance_case_id')->constrained('seller_compliance_cases')->cascadeOnDelete();
            $table->foreignId('performed_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->enum('action_type', ['WARNING', 'PRODUCT_SUSPEND', 'SELLER_SUSPEND', 'SELLER_REACTIVATE', 'NOTE']);
            $table->text('reason')->nullable();
            $table->timestamp('performed_at');
            $table->timestamps();

            $table->index(['seller_compliance_case_id', 'performed_at'], 'seller_compliance_actions_case_time_idx');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('seller_compliance_actions');
        Schema::dropIfExists('seller_compliance_cases');
    }
};
