<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Logistics\Shipment;
use Illuminate\Http\JsonResponse;

class TrackingApiController extends Controller
{
    public function show(string $trackingNumber): JsonResponse
    {
        $shipment = Shipment::query()
            ->where('tracking_number', $trackingNumber)
            ->with(['events.actor', 'deliveryAttempts', 'sellerOrder.order'])
            ->firstOrFail();

        return response()->json([
            'success' => true,
            'data' => [
                'tracking_number' => $shipment->tracking_number,
                'current_status' => $shipment->current_status,
                'seller_order_id' => $shipment->seller_order_id,
                'events' => $shipment->events
                    ->sortByDesc('occurred_at')
                    ->map(fn ($event) => [
                        'status' => $event->status,
                        'notes' => $event->notes,
                        'actor' => $event->actor?->name,
                        'occurred_at' => optional($event->occurred_at)->toIso8601String(),
                    ])->values(),
                'delivery_attempts' => $shipment->deliveryAttempts
                    ->sortByDesc('attempt_number')
                    ->map(fn ($attempt) => [
                        'attempt_number' => $attempt->attempt_number,
                        'status' => $attempt->status,
                        'failure_reason' => $attempt->failure_reason,
                        'attempted_at' => optional($attempt->attempted_at)->toIso8601String(),
                    ])->values(),
            ],
        ]);
    }
}
