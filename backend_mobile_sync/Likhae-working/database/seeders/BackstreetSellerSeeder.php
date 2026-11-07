<?php

namespace Database\Seeders;

use App\Models\Buyer\Address;
use App\Models\Seller\Category;
use App\Models\Seller\SellerProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class BackstreetSellerSeeder extends Seeder
{
    public function run(): void
    {
        $this->call(CatalogCategorySeeder::class);

        $admin = User::query()
            ->where('account_type', 'ADMIN')
            ->orderBy('id')
            ->firstOrFail();

        $sellerUser = User::firstOrNew(['email' => 'backstreetclub@likhae.online']);
        $sellerUser->fill([
            'account_type' => 'SELLER',
            'first_name' => 'Backstreet',
            'middle_initial' => null,
            'last_name' => 'Club',
            'sex' => $sellerUser->sex ?: 'PREFER_NOT_TO_SAY',
            'contact_number' => '09170000003',
            'birthday' => '1995-01-01',
            'email_verified_at' => $sellerUser->email_verified_at ?: now(),
            'status' => User::STATUS_ACTIVE,
        ]);
        $sellerUser->password = Hash::make('Password1');
        $sellerUser->save();

        $businessAddress = Address::updateOrCreate(
            ['user_id' => $sellerUser->id, 'label' => 'Business'],
            [
                'recipient_name' => $sellerUser->name,
                'contact_number' => $sellerUser->contact_number,
                'province_code' => 'LAG',
                'province_name' => 'Laguna',
                'municipality_code' => 'PILA',
                'municipality_name' => 'Pila',
                'barangay_code' => 'SAN-ANTONIO',
                'barangay_name' => 'San Antonio',
                'postal_code' => '4010',
                'house_number' => '1',
                'street_address' => 'Barangay San Antonio',
                'landmark' => 'Pila, Laguna',
                'is_default' => true,
            ],
        );

        $mensApparel = Category::query()
            ->whereNull('parent_id')
            ->where('name', "Men's Apparel")
            ->firstOrFail();

        SellerProfile::updateOrCreate(
            ['user_id' => $sellerUser->id],
            [
                'primary_category_id' => $mensApparel->id,
                'business_address_id' => $businessAddress->id,
                'business_name' => 'Backstreet Club',
                'business_registration_number' => 'SELLER-BACKSTREET-CLUB',
                'status' => 'ACTIVE',
                'approved_by_user_id' => $admin->id,
                'approved_at' => now(),
            ],
        );
    }
}
