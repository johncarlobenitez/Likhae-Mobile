<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Blade;
use Tests\TestCase;

class PhilippineAddressFormComponentTest extends TestCase
{
    public function test_shared_address_component_uses_the_existing_psgc_endpoints_and_official_fields(): void
    {
        $html = Blade::render('<form><x-shared.philippine-address-fields /></form>');

        $this->assertStringContainsString('data-postal-address', $html);
        $this->assertStringContainsString('data-postal-base="/address/philippines"', $html);
        $this->assertStringContainsString('name="region_code"', $html);
        $this->assertStringContainsString('name="province_code"', $html);
        $this->assertStringContainsString('name="municipality_code"', $html);
        $this->assertStringContainsString('name="barangay_code"', $html);
        $this->assertStringContainsString('name="postal_code"', $html);
    }
}
