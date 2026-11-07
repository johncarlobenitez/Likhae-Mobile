<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AdminAccountPersistenceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        $this->withoutVite();
    }

    public function test_admin_account_view_receives_the_current_admin(): void
    {
        $admin = User::factory()->create([
            'account_type' => User::TYPE_ADMIN,
            'status' => User::STATUS_ACTIVE,
        ]);

        $this->actingAs($admin)
            ->get(route('admin.account'))
            ->assertOk()
            ->assertSee($admin->name)
            ->assertSee($admin->email);
    }

    public function test_admin_email_and_notification_preferences_are_persisted(): void
    {
        $admin = User::factory()->create([
            'account_type' => User::TYPE_ADMIN,
            'status' => User::STATUS_ACTIVE,
        ]);

        $this->actingAs($admin)
            ->patch(route('admin.account.update'), [
                'first_name' => 'Ada',
                'last_name' => 'Admin',
                'email' => 'ada.admin@example.test',
                'contact_number' => '09123456789',
            ])
            ->assertRedirect();

        $this->actingAs($admin)->patch(route('admin.account.preferences'), [
            'registrations' => '1',
            'risk' => '1',
            'finance' => '0',
            'messages' => '1',
        ])->assertRedirect();

        $this->assertSame('ada.admin@example.test', $admin->fresh()->email);
        $preferences = $admin->fresh()->notification_preferences;
        ksort($preferences);
        $expectedPreferences = [
            'registrations' => true,
            'risk' => true,
            'finance' => false,
            'messages' => true,
        ];
        ksort($expectedPreferences);
        $this->assertSame($expectedPreferences, $preferences);
    }
}
