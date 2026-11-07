<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('carts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('buyer_user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('status', ['ACTIVE', 'CONVERTED', 'ABANDONED'])->default('ACTIVE');
            $table->timestamp('converted_at')->nullable();
            $table->timestamps();

            $table->index(['buyer_user_id', 'status']);
        });

        Schema::create('cart_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('cart_id')->constrained('carts')->cascadeOnDelete();
            $table->foreignId('product_variant_id')->constrained('product_variants')->restrictOnDelete();
            $table->unsignedInteger('quantity')->default(1);
            $table->timestamps();

            $table->unique(['cart_id', 'product_variant_id']);
        });

        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number', 60)->unique();
            $table->foreignId('buyer_user_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('source_cart_id')->nullable()->constrained('carts')->nullOnDelete();
            $table->enum('status', ['PLACED', 'PROCESSING', 'COMPLETED', 'CANCELLED', 'PARTIALLY_CANCELLED', 'RETURNED'])->default('PLACED');
            $table->char('currency', 3)->default('PHP');
            $table->decimal('subtotal', 12, 2)->default(0);
            $table->decimal('discount_total', 12, 2)->default(0);
            $table->decimal('shipping_total', 12, 2)->default(0);
            $table->decimal('grand_total', 12, 2)->default(0);
            $table->enum('payment_status', ['PENDING', 'PAID', 'FAILED', 'CANCELLED'])->default('PENDING');
            $table->timestamp('placed_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->text('cancellation_reason')->nullable();
            $table->timestamps();

            $table->index(['buyer_user_id', 'status']);
            $table->index(['status', 'placed_at']);
            $table->index('payment_status');
        });

        Schema::create('order_addresses', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->unique()->constrained('orders')->cascadeOnDelete();
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
            $table->timestamps();

            $table->index(['province_code', 'municipality_code', 'barangay_code'], 'order_addresses_geo_codes_idx');
        });

        Schema::create('seller_orders', function (Blueprint $table) {
            $table->id();
            $table->string('seller_order_number', 60)->unique();
            $table->foreignId('order_id')->constrained('orders')->cascadeOnDelete();
            $table->foreignId('seller_profile_id')->constrained('seller_profiles')->restrictOnDelete();
            $table->foreignId('voucher_id')->nullable()->constrained('vouchers')->nullOnDelete();
            $table->enum('status', ['PLACED', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP', 'PICKED_UP', 'COMPLETED', 'CANCELLED'])->default('PLACED');
            $table->decimal('item_subtotal', 12, 2)->default(0);
            $table->decimal('voucher_discount', 12, 2)->default(0);
            $table->decimal('shipping_fee', 12, 2)->default(0);
            $table->decimal('grand_total', 12, 2)->default(0);
            $table->timestamps();

            $table->unique(['order_id', 'seller_profile_id']);
            $table->index(['seller_profile_id', 'status']);
        });

        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('seller_order_id')->constrained('seller_orders')->cascadeOnDelete();
            $table->foreignId('product_id')->nullable()->constrained('products')->nullOnDelete();
            $table->foreignId('product_variant_id')->nullable()->constrained('product_variants')->nullOnDelete();
            $table->string('product_name', 200);
            $table->string('sku', 100);
            $table->string('variant_description', 500)->nullable();
            $table->decimal('unit_price', 12, 2);
            $table->unsignedInteger('quantity');
            $table->decimal('discount_amount', 12, 2)->default(0);
            $table->decimal('line_total', 12, 2);
            $table->timestamps();

            $table->index('seller_order_id');
            $table->index('product_id');
        });

        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_id')->constrained('orders')->restrictOnDelete();
            $table->enum('method', ['COD', 'ONLINE']);
            $table->string('provider', 100)->nullable();
            $table->string('provider_reference', 150)->nullable()->index();
            $table->decimal('amount', 12, 2);
            $table->enum('status', ['PENDING', 'PAID', 'FAILED', 'CANCELLED'])->default('PENDING');
            $table->timestamp('initiated_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->text('failure_reason')->nullable();
            $table->timestamps();

            $table->index(['order_id', 'status']);
        });

        Schema::create('reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('order_item_id')->unique()->constrained('order_items')->restrictOnDelete();
            $table->foreignId('buyer_user_id')->constrained('users')->restrictOnDelete();
            $table->unsignedTinyInteger('rating');
            $table->text('comment')->nullable();
            $table->text('seller_reply')->nullable();
            $table->timestamp('seller_replied_at')->nullable();
            $table->enum('status', ['PENDING', 'PUBLISHED', 'HIDDEN'])->default('PUBLISHED');
            $table->timestamps();

            $table->index(['buyer_user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
        Schema::dropIfExists('payments');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('seller_orders');
        Schema::dropIfExists('order_addresses');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('cart_items');
        Schema::dropIfExists('carts');
    }
};
