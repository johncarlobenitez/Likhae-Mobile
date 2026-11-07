<?php

namespace Tests\Feature;

use App\Models\Buyer\Address;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class BuyerAddressPsgcValidationTest extends TestCase
{
    use RefreshDatabase;

    public function test_buyer_can_save_and_edit_an_address_with_matching_psgc_codes(): void
    {
        config(['services.psgc.local_first' => true]);
        $buyer = User::factory()->create();

        $this->actingAs($buyer)
            ->post(route('buyer.account.addresses.store'), $this->addressPayload())
            ->assertRedirect();

        $address = Address::query()->where('user_id', $buyer->id)->sole();
        $this->assertSame('0403424000', $address->municipality_code);
        $this->assertSame('4000', $address->postal_code);

        $this->actingAs($buyer)
            ->put(route('buyer.account.addresses.update', $address), $this->addressPayload([
                'street_address' => 'Updated Mahogany Street',
                'latitude' => '14.0699',
                'longitude' => '121.3259',
                'is_default' => '1',
            ]))
            ->assertRedirect();

        $this->assertDatabaseHas('addresses', [
            'id' => $address->id,
            'street_address' => 'Updated Mahogany Street',
            'barangay_code' => '0403424001',
        ]);
    }

    public function test_buyer_address_rejects_a_barangay_that_does_not_belong_to_the_selected_municipality(): void
    {
        config(['services.psgc.local_first' => true]);
        $buyer = User::factory()->create();

        $this->actingAs($buyer)
            ->post(route('buyer.account.addresses.store'), $this->addressPayload([
                'barangay_code' => '9999999999',
            ]))
            ->assertRedirect()
            ->assertSessionHasErrors('barangay_code');

        $this->assertDatabaseCount('addresses', 0);
    }

    private function addressPayload(array $overrides = []): array
    {
        return array_replace([
            'label' => 'Home',
            'recipient_name' => 'Test Buyer',
            'contact_number' => '09171234567',
            'region_code' => '0400000000',
            'region_name' => 'Region IV-A (CALABARZON)',
            'province_code' => '0403400000',
            'province_name' => 'Laguna',
            'municipality_code' => '0403424000',
            'municipality_name' => 'City of San Pablo',
            'barangay_code' => '0403424001',
            'barangay_name' => 'Bagong Bayan II-A',
            'postal_code' => '4000',
            'house_number' => '12',
            'street_address' => 'Mahogany Street',
            'landmark' => 'Near the barangay hall',
            'latitude' => '14.0698',
            'longitude' => '121.3258',
        ], $overrides);
    }
}
