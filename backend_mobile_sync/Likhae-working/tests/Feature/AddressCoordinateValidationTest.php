<?php

namespace Tests\Feature;

use App\Models\Buyer\Address;
use App\Models\User;
use App\Services\Marketplace\CheckoutService;
use App\Support\AddressCoordinateValidator;
use Illuminate\Support\Collection;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class AddressCoordinateValidationTest extends TestCase
{
    public function test_empty_coordinates_are_rejected_instead_of_becoming_zero_zero(): void
    {
        $this->expectException(ValidationException::class);

        AddressCoordinateValidator::assertValid(['latitude' => '', 'longitude' => '']);
    }

    public function test_non_finite_or_out_of_range_coordinates_are_rejected(): void
    {
        $this->expectException(ValidationException::class);

        AddressCoordinateValidator::assertValid(['latitude' => 'NaN', 'longitude' => '181']);
    }

    public function test_valid_coordinates_are_accepted(): void
    {
        AddressCoordinateValidator::assertValid(['latitude' => '14.5995', 'longitude' => '120.9842']);

        $this->assertTrue(true);
    }

    public function test_checkout_service_rejects_an_unpinned_address_for_every_caller(): void
    {
        $this->expectException(ValidationException::class);

        app(CheckoutService::class)->placeOrder(
            new User(),
            new Address(['latitude' => null, 'longitude' => null]),
            new Collection(),
            'COD',
        );
    }

    public function test_changed_address_cannot_reuse_the_previous_confirmed_coordinates(): void
    {
        $this->expectException(ValidationException::class);

        AddressCoordinateValidator::assertFreshForAddress(new Address([
            'province_code' => 'P1',
            'province_name' => 'Province',
            'municipality_code' => 'M1',
            'municipality_name' => 'Municipality',
            'barangay_code' => 'B1',
            'barangay_name' => 'Barangay',
            'street_address' => 'Old Street',
            'latitude' => '14.5995000',
            'longitude' => '120.9842000',
        ]), [
            'province_code' => 'P1',
            'province_name' => 'Province',
            'municipality_code' => 'M1',
            'municipality_name' => 'Municipality',
            'barangay_code' => 'B1',
            'barangay_name' => 'Barangay',
            'street_address' => 'New Street',
            'latitude' => '14.5995000',
            'longitude' => '120.9842000',
        ]);
    }

    public function test_changed_address_accepts_a_new_confirmed_pin(): void
    {
        AddressCoordinateValidator::assertFreshForAddress(new Address([
            'province_code' => 'P1',
            'province_name' => 'Province',
            'municipality_code' => 'M1',
            'municipality_name' => 'Municipality',
            'barangay_code' => 'B1',
            'barangay_name' => 'Barangay',
            'street_address' => 'Old Street',
            'latitude' => '14.5995000',
            'longitude' => '120.9842000',
        ]), [
            'province_code' => 'P1',
            'province_name' => 'Province',
            'municipality_code' => 'M1',
            'municipality_name' => 'Municipality',
            'barangay_code' => 'B1',
            'barangay_name' => 'Barangay',
            'street_address' => 'New Street',
            'latitude' => '14.5996000',
            'longitude' => '120.9843000',
        ]);

        $this->assertTrue(true);
    }
}
