<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Rider\RiderLocalTrip;
use App\Models\Rider\RiderLocalTripItem;
use App\Models\Rider\RiderProfile;
use App\Models\User;
use App\Services\Fulfillment\LogisticsSchemaReadiness;
use App\Support\RiderVehicleType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RiderPickupBatchApiController extends Controller
{
    public function show(
        Request $request,
        int $trip,
        LogisticsSchemaReadiness $schema,
    ): JsonResponse {
        $user = $request->user();
        abort_unless(
            $user instanceof User
                && $user->isAccountType(User::TYPE_RIDER)
                && $user->status === User::STATUS_ACTIVE,
            403,
            'Active rider account access is required.',
        );

        $rider = $user->riderProfile;
        abort_unless(
            $rider instanceof RiderProfile
                && $rider->status === 'ACTIVE'
                && RiderVehicleType::isLocalBarangay($rider->vehicle_type),
            403,
            'Local Rider access is required.',
        );

        if (! $schema->sellerPickupBatchesReady()) {
            return response()->json([
                'success' => false,
                'message' => 'Seller pickup batch workflow is unavailable until its additive schema migration is installed.',
            ], 503);
        }

        $batch = RiderLocalTrip::query()
            ->where('rider_profile_id', $rider->id)
            ->where('trip_type', RiderLocalTrip::TYPE_PICKUP)
            ->whereNotNull('seller_profile_id')
            ->with([
                'seller.businessAddress',
                'logisticsCenter.address',
                'items.riderAssignment.shipment.sellerOrder.items',
            ])
            ->findOrFail($trip);

        return response()->json([
            'success' => true,
            'data' => $this->batchPayload($batch),
        ]);
    }

    private function batchPayload(RiderLocalTrip $trip): array
    {
        $items = $trip->items->map(function (RiderLocalTripItem $item): array {
            $assignment = $item->riderAssignment;
            $shipment = $assignment?->shipment;

            return [
                'assignment_id' => $assignment?->id,
                'tracking' => $shipment?->tracking_number,
                'seller_order_number' => $shipment?->sellerOrder?->seller_order_number,
                'products' => $shipment?->sellerOrder?->items?->pluck('product_name')->filter()->values() ?? collect(),
                'assignment_status' => $assignment?->status,
                'shipment_status' => $shipment?->current_status,
                'not_collected_reason' => $assignment?->rejection_reason,
            ];
        })->values();

        return [
            'id' => $trip->id,
            'batch_number' => 'P-'.$trip->id,
            'status' => $trip->status,
            'seller' => $trip->seller?->business_name,
            'pickup_address' => $trip->seller?->businessAddress?->formatted(),
            'logistics_center' => $trip->logisticsCenter?->business_name,
            'destination_address' => $trip->logisticsCenter?->address?->formatted(),
            'parcel_count' => $items->count(),
            'approved_capacity' => $trip->approved_parcel_capacity,
            'collected_count' => $items->where('assignment_status', 'COMPLETED')->count(),
            'items' => $items,
        ];
    }
}