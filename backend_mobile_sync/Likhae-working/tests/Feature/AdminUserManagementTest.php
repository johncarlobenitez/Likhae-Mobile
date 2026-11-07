<?php

namespace Tests\Feature;

use App\Models\User;
use Tests\TestCase;

class AdminUserManagementTest extends TestCase
{
    public function test_final_account_model_uses_fixed_account_type(): void
    {
        $user = new User();
        $user->account_type = User::TYPE_BUYER;
        $user->status = User::STATUS_ACTIVE;

        $this->assertContains('account_type', $user->getFillable());
        $this->assertContains('status', $user->getFillable());
        $this->assertTrue($user->isAccountType(User::TYPE_BUYER));
        $this->assertTrue($user->isActive());
        $this->assertSame('buyer.home', $user->workspaceRoute());
    }

    public function test_laravel_routes_boot_for_current_workspace_names(): void
    {
        $routes = collect(app('router')->getRoutes())->map(fn ($route) => $route->getName())->filter()->values();

        $this->assertTrue($routes->contains('login'));
        $this->assertTrue($routes->contains('register'));
        $this->assertTrue($routes->contains('buyer.home'));
        $this->assertTrue($routes->contains('seller.dashboard'));
        $this->assertTrue($routes->contains('logistics.dashboard'));
        $this->assertTrue($routes->contains('rider.dashboard'));
    }
}
