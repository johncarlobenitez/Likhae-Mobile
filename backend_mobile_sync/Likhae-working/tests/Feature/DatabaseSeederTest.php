<?php

namespace Tests\Feature;

use App\Models\Logistics\LogisticsCenter;
use App\Models\Rider\RiderProfile;
use App\Models\Seller\Category;
use App\Models\Seller\SellerProfile;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DatabaseSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_accounts_are_complete_and_seeding_preserves_existing_passwords(): void
    {
        $this->seed(DatabaseSeeder::class);

        $emails = [
            'admin@likhae.com',
            'buyer@likhae.com',
            'seller@likhae.com',
            'jnt@likhae.online',
            'carlomartinez@likhae.online',
        ];
        $users = User::query()->whereIn('email', $emails)->get();

        $this->assertCount(5, $users);

        foreach ($users as $user) {
            $this->assertSame(User::STATUS_ACTIVE, $user->status);
            $this->assertNotNull($user->email_verified_at);
            $this->assertNotEmpty($user->contact_number);
            $this->assertNotNull($user->birthday);
            $this->assertTrue($user->addresses()->exists());
            $this->assertTrue(Hash::check('Password1', $user->password));
        }

        $seller = $users->firstWhere('email', 'seller@likhae.com');
        $logistics = $users->firstWhere('email', 'jnt@likhae.online');
        $rider = $users->firstWhere('email', 'carlomartinez@likhae.online');

        $this->assertDatabaseHas('seller_profiles', ['user_id' => $seller->id, 'status' => 'ACTIVE']);
        $this->assertDatabaseHas('logistics_centers', ['owner_user_id' => $logistics->id, 'status' => 'ACTIVE']);
        $this->assertDatabaseHas('rider_profiles', ['user_id' => $rider->id, 'status' => 'ACTIVE']);

        $backstreet = User::query()->where('email', 'backstreetclub@likhae.online')->firstOrFail();
        $this->assertSame('SELLER', $backstreet->account_type);
        $this->assertSame(User::STATUS_ACTIVE, $backstreet->status);
        $this->assertTrue(Hash::check('Password1', $backstreet->password));
        $mensApparel = Category::query()
            ->whereNull('parent_id')
            ->where('name', "Men's Apparel")
            ->firstOrFail();
        $this->assertDatabaseHas('seller_profiles', [
            'user_id' => $backstreet->id,
            'business_name' => 'Backstreet Club',
            'primary_category_id' => $mensApparel->id,
            'status' => 'ACTIVE',
        ]);
        $this->assertDatabaseHas('addresses', [
            'user_id' => $backstreet->id,
            'label' => 'Business',
            'barangay_name' => 'San Antonio',
            'municipality_name' => 'Pila',
            'province_name' => 'Laguna',
            'postal_code' => '4010',
        ]);

        $buyer = $users->firstWhere('email', 'buyer@likhae.com');
        $buyer->forceFill(['password' => Hash::make('BuyerChanged1')])->save();

        $this->seed(DatabaseSeeder::class);

        $this->assertCount(5, User::query()->whereIn('email', $emails)->get());
        $this->assertTrue(Hash::check('BuyerChanged1', $buyer->fresh()->password));
    }
}
