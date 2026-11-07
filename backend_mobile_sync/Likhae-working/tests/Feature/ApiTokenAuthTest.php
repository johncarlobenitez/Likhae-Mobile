<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ApiTokenAuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_api_token_can_be_issued_used_and_revoked(): void
    {
        $user = User::factory()->create([
            'account_type' => User::TYPE_RIDER,
            'status' => User::STATUS_ACTIVE,
            'email_verified_at' => now(),
        ]);

        $login = $this->postJson(route('api.v1.auth.login'), [
            'email' => $user->email,
            'password' => 'Password1',
            'device_name' => 'Flutter test device',
        ])->assertOk()->assertJsonPath('token_type', 'Bearer');

        $token = $login->json('access_token');
        $this->assertNotEmpty($token);
        $this->assertSame($token, $login->json('token'));
        $login->assertJsonPath('device_name', 'Flutter test device')
            ->assertJsonPath('user.mobile_roles.0', 'rider');
        $this->assertNotSame($token, $user->fresh()->api_token_hash);

        $this->withToken($token)
            ->getJson(route('api.v1.auth.me'))
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.account_type', User::TYPE_RIDER);

        $this->postJson(route('api.v1.auth.logout'))->assertOk();
        $this->getJson(route('api.v1.auth.me'))->assertUnauthorized();
    }

    public function test_mobile_login_rejects_non_buyer_and_non_rider_accounts(): void
    {
        $seller = User::factory()->create([
            'account_type' => User::TYPE_SELLER,
            'status' => User::STATUS_ACTIVE,
            'email_verified_at' => now(),
        ]);

        $this->postJson(route('api.v1.auth.login'), [
            'email' => $seller->email,
            'password' => 'Password1',
        ])->assertForbidden()
            ->assertJsonPath('message', 'This account does not have Buyer or Rider mobile access.');
    }
}
