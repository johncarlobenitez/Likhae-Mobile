<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PhilippineAddressLookupTest extends TestCase
{
    use RefreshDatabase;

    public function test_location_api_and_buyer_form_use_same_origin_urls(): void
    {
        $regions = $this->get(route('address.philippines.regions'));
        $regions->assertOk()->assertJsonFragment(['name' => 'Region IV-A (CALABARZON)']);

        $this->seed(DatabaseSeeder::class);
        $buyer = User::query()->where('email', 'buyer@likhae.com')->sole();

        $this->actingAs($buyer)
            ->get(route('buyer.account', ['tab' => 'addresses']))
            ->assertOk()
            ->assertSee('data-postal-base="/address/philippines"', escape: false)
            ->assertDontSee('data-postal-base="http://', escape: false);
    }
}
