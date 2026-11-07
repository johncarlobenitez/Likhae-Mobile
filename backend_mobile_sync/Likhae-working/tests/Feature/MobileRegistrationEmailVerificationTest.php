<?php

namespace Tests\Feature;

use App\Mail\RegistrationEmailVerificationCode;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class MobileRegistrationEmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_mobile_registration_email_code_can_be_exchanged_for_a_token(): void
    {
        Mail::fake();
        $email = 'mobile.buyer@example.com';

        $this->postJson(route('api.v1.auth.register.email-verification.send'), ['email' => $email])
            ->assertOk()
            ->assertJsonPath('success', true);

        $mailable = Mail::sent(RegistrationEmailVerificationCode::class)->first();
        $this->assertNotNull($mailable);

        $this->postJson(route('api.v1.auth.register.email-verification.verify'), [
            'email' => $email,
            'code' => $mailable->code,
        ])->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('message', 'Email verified. Submit this token with registration.')
            ->assertJsonStructure(['email_verification_token', 'expires_at']);
    }

    public function test_mobile_registration_email_code_cannot_be_sent_to_an_existing_account(): void
    {
        Mail::fake();
        User::factory()->create(['email' => 'existing.mobile@example.com']);

        $this->postJson(route('api.v1.auth.register.email-verification.send'), [
            'email' => 'EXISTING.MOBILE@example.com',
        ])->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        Mail::assertNothingSent();
    }

    public function test_mobile_address_endpoints_are_exposed_under_v1(): void
    {
        $this->getJson(route('api.v1.address.philippines.postal-code', [
            'municipality' => '0403424000',
            'province_name' => 'Laguna',
            'municipality_name' => 'City of San Pablo',
        ]))->assertOk()
            ->assertJsonStructure(['postal_code']);
    }
}
