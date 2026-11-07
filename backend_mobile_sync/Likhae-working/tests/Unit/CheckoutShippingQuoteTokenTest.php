<?php

namespace Tests\Unit;

use App\Models\Buyer\Address;
use App\Models\Buyer\CartItem;
use App\Models\Seller\Product;
use App\Models\Seller\ProductVariant;
use App\Models\User;
use App\Services\Marketplace\CheckoutService;
use Illuminate\Support\Collection;
use Tests\TestCase;

class CheckoutShippingQuoteTokenTest extends TestCase
{
    public function test_shipping_quote_token_is_a_stable_signature_of_the_current_shipping_quote(): void
    {
        $buyer = new User();
        $buyer->id = 17;

        $address = new Address();
        $address->id = 8;

        $product = new Product();
        $product->seller_profile_id = 31;

        $variant = new ProductVariant();
        $variant->id = 44;
        $variant->product_id = 5;
        $variant->setRelation('product', $product);

        $item = new CartItem();
        $item->id = 12;
        $item->product_variant_id = 44;
        $item->quantity = 2;
        $item->setRelation('productVariant', $variant);

        $items = new Collection([$item]);
        $preview = [
            'groups' => [
                31 => [
                    'shipping_fee' => '75.00',
                    'shipping_voucher_discount' => '0.00',
                    'shipping_rate_snapshot' => ['origin' => 'Laguna', 'fee' => '75.00'],
                    'routing_decision' => ['hub_id' => 4],
                ],
            ],
        ];
        $service = app(CheckoutService::class);

        $token = $service->shippingQuoteToken($buyer, $address, $items, $preview);
        $repeatedToken = $service->shippingQuoteToken($buyer, $address, $items, $preview);
        $changedQuote = $preview;
        $changedQuote['groups'][31]['shipping_fee'] = '90.00';
        $changedToken = $service->shippingQuoteToken($buyer, $address, $items, $changedQuote);

        $this->assertMatchesRegularExpression('/\A[a-f0-9]{64}\z/', $token);
        $this->assertSame($token, $repeatedToken);
        $this->assertNotSame($token, $changedToken);
    }
}
