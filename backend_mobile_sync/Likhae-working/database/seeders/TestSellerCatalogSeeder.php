<?php

namespace Database\Seeders;

use App\Models\Buyer\Address;
use App\Models\Seller\Category;
use App\Models\Seller\Product;
use App\Models\Seller\ProductImage;
use App\Models\Seller\ProductVariant;
use App\Models\Seller\SellerProfile;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class TestSellerCatalogSeeder extends Seeder
{
    private const TEST_PASSWORD = 'Password 1';

    /** @var array<string, array{first_name:string,last_name:string,email:string,contact_number:string,birthday:string,sex:string,business_name:string,business_registration_number:string,category:string,province_code:string,province_name:string,municipality_code:string,municipality_name:string,barangay_code:string,barangay_name:string,postal_code:string,house_number:string,street_address:string,landmark:string,products:list<array{name:string,subcategory:string,description:string,sku:string,price:float,stock:int}>}> */
    private const SELLERS = [
        [
            'first_name' => 'Alyssa',
            'last_name' => 'Navarro',
            'email' => 'alyssa.navarro@likhae.com',
            'contact_number' => '09178000121',
            'birthday' => '1994-04-12',
            'sex' => 'FEMALE',
            'business_name' => 'Amihan Home Goods',
            'business_registration_number' => 'TEST-SELLER-AMIHAN-001',
            'category' => 'Home and Garden',
            'province_code' => 'LAG',
            'province_name' => 'Laguna',
            'municipality_code' => 'PILA',
            'municipality_name' => 'Pila',
            'barangay_code' => 'BAGONG-POOK',
            'barangay_name' => 'Bagong Pook',
            'postal_code' => '4010',
            'house_number' => '24',
            'street_address' => 'Maharlika Street',
            'landmark' => 'Near Pila Municipal Hall',
            'products' => [
                ['name' => 'Handwoven Abaca Storage Basket', 'subcategory' => 'Home Decor', 'description' => 'A sturdy handwoven abaca basket for organizing linens, toys, or everyday household items. Made by local artisans; slight variations in weave make each piece unique.', 'sku' => 'TEST-AMH-BASKET-001', 'price' => 480.00, 'stock' => 18],
                ['name' => 'Coconut Shell Tea Light Set', 'subcategory' => 'Home Decor', 'description' => 'Set of four polished coconut shell tea light holders made with locally sourced shells. Each holder fits a standard tea light candle.', 'sku' => 'TEST-AMH-CANDLE-002', 'price' => 320.00, 'stock' => 25],
                ['name' => 'Linen Throw Pillow Cover', 'subcategory' => 'Bedding', 'description' => 'Breathable linen-blend cushion cover with a concealed zipper. Sized for a 45 by 45 centimeter insert; insert is not included.', 'sku' => 'TEST-AMH-PILLOW-003', 'price' => 390.00, 'stock' => 22],
                ['name' => 'Herb Starter Garden Kit', 'subcategory' => 'Gardening', 'description' => 'A beginner-friendly kit with three reusable planting pots, seed-starting soil, plant markers, and basil, oregano, and parsley seeds.', 'sku' => 'TEST-AMH-HERB-KIT-004', 'price' => 550.00, 'stock' => 14],
                ['name' => 'Bamboo Kitchen Utensil Set', 'subcategory' => 'Kitchen & Dining', 'description' => 'Five smooth-finished bamboo cooking utensils for everyday meal preparation. Hand wash and dry after use to preserve the natural finish.', 'sku' => 'TEST-AMH-BAMBOO-005', 'price' => 610.00, 'stock' => 16],
            ],
        ],
        [
            'first_name' => 'Marco',
            'last_name' => 'Villanueva',
            'email' => 'marco.villanueva@likhae.com',
            'contact_number' => '09178000122',
            'birthday' => '1991-09-23',
            'sex' => 'MALE',
            'business_name' => 'Habi Streetwear',
            'business_registration_number' => 'TEST-SELLER-HABI-002',
            'category' => "Men's Apparel",
            'province_code' => 'LAG',
            'province_name' => 'Laguna',
            'municipality_code' => 'PILA',
            'municipality_name' => 'Pila',
            'barangay_code' => 'SAN-ANTONIO',
            'barangay_name' => 'San Antonio',
            'postal_code' => '4010',
            'house_number' => '18',
            'street_address' => 'Rizal Avenue',
            'landmark' => 'Across Pila Public Market',
            'products' => [
                ['name' => 'Classic Cotton Crewneck T-Shirt', 'subcategory' => 'T-Shirts & Shirts', 'description' => 'A soft mid-weight cotton crewneck with a relaxed everyday fit. Locally printed graphic, reinforced collar, and machine-washable fabric.', 'sku' => 'TEST-HABI-TEE-001', 'price' => 499.00, 'stock' => 30],
                ['name' => 'Everyday Linen Button-Up Shirt', 'subcategory' => 'T-Shirts & Shirts', 'description' => 'A lightweight linen-blend button-up for warm weather. Features a chest pocket, natural texture, and an easy regular fit.', 'sku' => 'TEST-HABI-SHIRT-002', 'price' => 890.00, 'stock' => 17],
                ['name' => 'Slim Fit Chino Pants', 'subcategory' => 'Pants & Jeans', 'description' => 'Comfortable cotton-stretch chinos with a slim straight leg, belt loops, and four practical pockets. Suitable for casual or work outfits.', 'sku' => 'TEST-HABI-CHINO-003', 'price' => 1090.00, 'stock' => 12],
                ['name' => 'Lightweight Weekend Shorts', 'subcategory' => 'Shorts', 'description' => 'Breathable cotton twill shorts with an elastic-back waistband, secure side pockets, and a comfortable above-the-knee cut.', 'sku' => 'TEST-HABI-SHORTS-004', 'price' => 650.00, 'stock' => 20],
                ['name' => 'Zip-Up Utility Jacket', 'subcategory' => 'Jackets', 'description' => 'A lightweight everyday jacket with a full front zipper, two hand pockets, and a clean utility-inspired silhouette for cool evenings.', 'sku' => 'TEST-HABI-JACKET-005', 'price' => 1490.00, 'stock' => 9],
            ],
        ],
    ];

    public function run(): void
    {
        $this->call(CatalogCategorySeeder::class);

        $adminId = User::query()
            ->where('account_type', User::TYPE_ADMIN)
            ->orderBy('id')
            ->value('id');

        foreach (self::SELLERS as $sellerData) {
            $this->seedSeller($sellerData, $adminId ? (int) $adminId : null);
        }
    }

    /** @param array<string, mixed> $data */
    private function seedSeller(array $data, ?int $adminId): void
    {
        $user = User::query()->firstOrNew(['email' => $data['email']]);
        $user->fill([
            'account_type' => User::TYPE_SELLER,
            'first_name' => $data['first_name'],
            'middle_initial' => null,
            'last_name' => $data['last_name'],
            'sex' => $data['sex'],
            'contact_number' => $data['contact_number'],
            'birthday' => $data['birthday'],
            'email_verified_at' => $user->email_verified_at ?: now(),
            'status' => User::STATUS_ACTIVE,
        ]);
        $user->password = Hash::make(self::TEST_PASSWORD);
        $user->save();

        $address = Address::query()->updateOrCreate(
            ['user_id' => $user->id, 'label' => 'Business'],
            [
                'recipient_name' => $user->name,
                'contact_number' => $user->contact_number,
                'province_code' => $data['province_code'],
                'province_name' => $data['province_name'],
                'municipality_code' => $data['municipality_code'],
                'municipality_name' => $data['municipality_name'],
                'barangay_code' => $data['barangay_code'],
                'barangay_name' => $data['barangay_name'],
                'postal_code' => $data['postal_code'],
                'house_number' => $data['house_number'],
                'street_address' => $data['street_address'],
                'landmark' => $data['landmark'],
                'is_default' => true,
            ],
        );

        $primaryCategory = Category::query()
            ->whereNull('parent_id')
            ->where('name', $data['category'])
            ->where('is_active', true)
            ->firstOrFail();

        $seller = SellerProfile::query()->updateOrCreate(
            ['user_id' => $user->id],
            [
                'primary_category_id' => $primaryCategory->id,
                'business_address_id' => $address->id,
                'business_name' => $data['business_name'],
                'business_registration_number' => $data['business_registration_number'],
                'status' => 'ACTIVE',
                'approved_by_user_id' => $adminId,
                'approved_at' => now(),
            ],
        );

        foreach ($data['products'] as $index => $productData) {
            $productCategory = Category::query()
                ->where('slug', Str::slug($data['category'].'-'.$productData['subcategory']))
                ->where('is_active', true)
                ->firstOrFail();
            $slug = Str::slug('test-'.$data['business_name'].'-'.$productData['name']);

            $product = Product::withTrashed()->updateOrCreate(
                ['slug' => $slug],
                [
                    'seller_profile_id' => $seller->id,
                    'category_id' => $productCategory->id,
                    'name' => $productData['name'],
                    'description' => $productData['description'],
                    'status' => 'ACTIVE',
                    'published_at' => now(),
                    'archived_at' => null,
                ],
            );

            if ($product->trashed()) {
                $product->restore();
            }

            ProductVariant::query()->updateOrCreate(
                ['product_id' => $product->id, 'sku' => $productData['sku']],
                [
                    'price' => $productData['price'],
                    'discount_type' => 'none',
                    'discount_value' => 0,
                    'payment_method' => 'cod_online',
                    'stock' => $productData['stock'],
                    'is_default' => true,
                    'is_active' => true,
                ],
            );

            ProductImage::query()->updateOrCreate(
                [
                    'product_id' => $product->id,
                    'file_path' => 'products/mock/'.Str::slug($productData['sku']).'.png',
                ],
                [
                    'alt_text' => $productData['name'],
                    'is_primary' => true,
                    'sort_order' => 0,
                ],
            );
        }
    }
}
