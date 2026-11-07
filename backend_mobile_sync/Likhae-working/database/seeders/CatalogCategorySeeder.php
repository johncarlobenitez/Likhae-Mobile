<?php

namespace Database\Seeders;

use App\Models\Seller\Category;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class CatalogCategorySeeder extends Seeder
{
    public function run(): void
    {
        $catalog = [
            'Pet Supplies' => [
                'Dog Supplies', 'Cat Supplies', 'Pet Food', 'Pet Grooming', 'Pet Toys',
            ],
            'Electronics and Gadgets' => [
                'Mobile Phones', 'Computers & Laptops', 'Mobile Accessories', 'Audio Devices', 'Gaming',
            ],
            "Women's Apparel" => [
                'Tops', 'Dresses', 'Bottoms', 'Activewear', 'Sleepwear',
            ],
            "Men's Apparel" => [
                'T-Shirts & Shirts', 'Pants & Jeans', 'Shorts', 'Jackets', 'Activewear',
            ],
            'Kids and Baby' => [
                'Baby Clothing', 'Kids Clothing', 'Toys', 'Baby Care', 'Feeding Supplies',
            ],
            'Home and Garden' => [
                'Kitchen & Dining', 'Home Décor', 'Bedding', 'Gardening', 'Home Improvement',
            ],
            'Sports and Outdoors' => [
                'Fitness Equipment', 'Basketball & Volleyball', 'Badminton', 'Cycling', 'Camping & Hiking',
            ],
            'Health and Beauty' => [
                'Skin Care', 'Hair Care', 'Makeup', 'Personal Care', 'Fragrances',
            ],
            'Books and Media' => [
                'Fiction', 'Non-Fiction', 'Textbooks', "Children's Books", 'Comics & Manga',
            ],
            'Food and Gourmet' => [
                'Snacks', 'Beverages', 'Coffee & Tea', 'Packaged Food', 'Local Delicacies',
            ],
            'Furniture and Office Equipment' => [
                'Home Furniture', 'Office Furniture', 'Office Supplies', 'Storage & Shelving', 'Printers & Accessories',
            ],
            'Jewelry and Watches' => [
                'Necklaces', 'Earrings', 'Rings', 'Bracelets', 'Watches',
            ],
        ];

        foreach ($catalog as $mainCategoryName => $subcategories) {
            $mainCategory = Category::updateOrCreate(
                ['slug' => Str::slug($mainCategoryName)],
                [
                    'parent_id' => null,
                    'name' => $mainCategoryName,
                    'is_active' => true,
                ],
            );

            foreach ($subcategories as $subcategoryName) {
                Category::updateOrCreate(
                    ['slug' => Str::slug($mainCategoryName.'-'.$subcategoryName)],
                    [
                        'parent_id' => $mainCategory->id,
                        'name' => $subcategoryName,
                        'is_active' => true,
                    ],
                );
            }
        }
    }
}
