<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminUserDetailsTest extends TestCase
{
    use RefreshDatabase;

    public function test_view_button_opens_each_admin_managed_account_and_excludes_riders(): void
    {
        $admin = User::factory()->create(['account_type' => User::TYPE_ADMIN]);
        $this->actingAs($admin);

        foreach ([User::TYPE_BUYER, User::TYPE_SELLER, User::TYPE_ADMIN, User::TYPE_LOGISTICS] as $type) {
            $account = $type === User::TYPE_ADMIN
                ? $admin
                : User::factory()->create(['account_type' => $type]);

            $this->get(route('admin.users.show', $account))
                ->assertOk()
                ->assertSee($account->email)
                ->assertSee(ucfirst(strtolower($type)));
        }

        $rider = User::factory()->create(['account_type' => User::TYPE_RIDER]);
        $this->get(route('admin.users.show', $rider))->assertNotFound();
    }
}
