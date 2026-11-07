<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('disputes', function (Blueprint $table) {
            $table->id();
            $table->string('dispute_number', 60)->unique();
            $table->foreignId('opened_by_user_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('assigned_admin_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('order_id')->nullable()->constrained('orders')->nullOnDelete();
            $table->foreignId('seller_order_id')->nullable()->constrained('seller_orders')->nullOnDelete();
            $table->foreignId('shipment_id')->nullable()->constrained('shipments')->nullOnDelete();
            $table->string('type', 100);
            $table->string('subject', 255);
            $table->longText('description');
            $table->enum('status', ['OPEN', 'UNDER_REVIEW', 'RESOLVED', 'CLOSED', 'REJECTED'])->default('OPEN');
            $table->timestamp('opened_at');
            $table->timestamp('resolved_at')->nullable();
            $table->longText('resolution')->nullable();
            $table->timestamps();

            $table->index(['status', 'opened_at']);
            $table->index('assigned_admin_user_id');
        });

        Schema::create('dispute_evidence', function (Blueprint $table) {
            $table->id();
            $table->foreignId('dispute_id')->constrained('disputes')->cascadeOnDelete();
            $table->foreignId('uploaded_by_user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('file_path', 500);
            $table->string('original_name', 255)->nullable();
            $table->string('mime_type', 100)->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();

            $table->index('dispute_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dispute_evidence');
        Schema::dropIfExists('disputes');
    }
};
