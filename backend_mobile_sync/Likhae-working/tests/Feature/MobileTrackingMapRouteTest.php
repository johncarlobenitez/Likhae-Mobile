<?php

namespace Tests\Feature;

use App\Http\Controllers\Buyer\TrackingController;
use Tests\TestCase;

class MobileTrackingMapRouteTest extends TestCase
{
    public function test_mobile_map_uses_the_web_tracking_controller_and_requires_authentication(): void
    {
        $route = app('router')->getRoutes()->getByName('api.v1.buyer.tracking.map');
        $this->assertSame(TrackingController::class.'@live', $route->getActionName());
        $this->getJson('/api/v1/buyer/tracking/TEST-PARCEL/map')
            ->assertUnauthorized();
    }
}
