<?php

namespace Tests\Feature;

use App\Models\Seller\Product;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SoftDeleteRetentionTest extends TestCase
{
    use RefreshDatabase;

    public function test_purge_command_removes_only_products_past_the_30_day_recovery_window(): void
    {
        $this->seed(DatabaseSeeder::class);
        $seller = User::query()->where('email', 'seller@likhae.com')->sole();
        $product = Product::query()->whereBelongsTo($seller->sellerProfile)->sole();
        $product->delete();
        DB::table('products')->where('id', $product->id)->update(['deleted_at' => now()->subDays(31)]);

        Artisan::call('likhae:purge-expired-soft-deletes');

        $this->assertDatabaseMissing('products', ['id' => $product->id]);
    }
}
