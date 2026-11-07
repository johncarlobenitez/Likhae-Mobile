<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('product_variants', 'discount_type')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->string('discount_type', 20)->nullable()->after('price');
                $table->decimal('discount_value', 12, 2)->nullable()->after('discount_type');
                $table->string('payment_method', 20)->nullable()->after('discount_value');
                $table->index(['product_id', 'payment_method'], 'product_variants_product_payment_index');
            });
        }

        if (! Schema::hasColumn('product_images', 'product_option_value_id')) {
            Schema::table('product_images', function (Blueprint $table): void {
                $table->foreignId('product_option_value_id')
                    ->nullable()
                    ->after('product_id')
                    ->constrained('product_option_values')
                    ->nullOnDelete();
                $table->index(
                    ['product_id', 'product_option_value_id'],
                    'product_images_product_option_value_index'
                );
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('product_images', 'product_option_value_id')) {
            Schema::table('product_images', function (Blueprint $table): void {
                $table->dropForeign(['product_option_value_id']);
                $table->dropIndex('product_images_product_option_value_index');
                $table->dropColumn('product_option_value_id');
            });
        }

        if (Schema::hasColumn('product_variants', 'discount_type')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->dropIndex('product_variants_product_payment_index');
                $table->dropColumn(['discount_type', 'discount_value', 'payment_method']);
            });
        }
    }
};
