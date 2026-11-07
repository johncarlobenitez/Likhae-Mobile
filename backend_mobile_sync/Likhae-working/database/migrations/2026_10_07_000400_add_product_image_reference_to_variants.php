<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('product_variants', 'product_image_id')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->foreignId('product_image_id')
                    ->nullable()
                    ->after('product_id')
                    ->constrained('product_images')
                    ->nullOnDelete();
                $table->index(
                    ['product_id', 'product_image_id'],
                    'product_variants_product_image_index'
                );
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('product_variants', 'product_image_id')) {
            Schema::table('product_variants', function (Blueprint $table): void {
                $table->dropForeign(['product_image_id']);
                $table->dropIndex('product_variants_product_image_index');
                $table->dropColumn('product_image_id');
            });
        }
    }
};
