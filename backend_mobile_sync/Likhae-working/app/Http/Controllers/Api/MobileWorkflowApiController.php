<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Rider\RiderReturnWorkflowController;
use App\Http\Controllers\Rider\RiderTripController;
use App\Http\Controllers\WorkspaceSettingsController;
use App\Models\Communication\Conversation;
use App\Models\Rider\InterhubAttendanceSession;
use App\Models\Rider\InterhubPayrollItem;
use App\Models\Seller\SellerPromotion;
use App\Services\Finance\EarningPayoutService;
use App\Services\Finance\PayoutDestinationReadiness;
use App\Services\Fulfillment\ShipmentReturnWorkflowService;
use App\Services\PolicyAcceptanceService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Schema;

/** Explicit mobile payloads; mutations stay in the shared, authorized workflows. */
class MobileWorkflowApiController extends Controller
{
    private function page($rows, callable $map): JsonResponse
    {
        return response()->json(['success' => true, 'data' => collect($rows->items())->map($map)->values(),
            'meta' => ['current_page' => $rows->currentPage(), 'last_page' => $rows->lastPage()]]);
    }

    public function returns(Request $request, RiderReturnWorkflowController $controller, ShipmentReturnWorkflowService $service): JsonResponse
    {
        $data = $controller->index($request, $service)->getData();
        $id = (int) $data['rider']->id;
        return $this->page($data['workflows'], function ($row) use ($id): array {
            $actions = [];
            $original = (int) $row->originalDeliveryAssignment?->rider_profile_id === $id;
            $assigned = (int) $row->return_rider_profile_id === $id;
            if ($original && $row->status === 'AWAITING_CENTER_HANDOFF') $actions[] = 'center-handoff';
            if ($assigned && $row->status === 'ASSIGNED_TO_RETURN_RIDER') $actions[] = 'accept';
            if ($assigned && $row->status === 'RETURN_RIDER_ACCEPTED') $actions[] = 'pickup';
            if ($assigned && $row->status === 'IN_TRANSIT_TO_SELLER') $actions[] = 'seller-handoff';
            if ($row->status === 'RETURN_RIDER_HANDOFF_PENDING') {
                if ($assigned && ! $row->handoff_from_confirmed_at) $actions[] = 'handoff/from';
                if ((int) $row->pending_return_rider_profile_id === $id && $row->handoff_from_confirmed_at && ! $row->handoff_to_confirmed_at) $actions[] = 'handoff/to';
            }
            return ['id' => $row->id, 'tracking_number' => $row->shipment?->tracking_number,
                'status' => $row->status, 'reason' => $row->reason,
                'seller' => $row->shipment?->sellerOrder?->sellerProfile?->business_name,
                'seller_address' => $row->shipment?->sellerOrder?->sellerProfile?->businessAddress?->formatted(),
                'center' => $row->logisticsCenter?->business_name, 'actions' => $actions];
        });
    }

    private function tripPayload($trip): array
    {
        $active = $trip->items->whereIn('status', ['QUEUED', 'LOADED']);
        $actions = [];
        if ($active->isNotEmpty() && in_array($trip->status, ['LOADING', 'READY'], true)) {
            if ($active->every(fn ($item) => in_array($item->riderAssignment?->status, ['ASSIGNED', 'ACCEPTED'], true))) {
                $actions = ['accept', 'reject'];
            }
            if ($active->every(fn ($item) => $item->riderAssignment?->status === 'ACCEPTED')) {
                $actions[] = 'load';
                $actions[] = 'start';
            }
        }
        return ['id' => $trip->id, 'status' => $trip->status, 'capacity' => $trip->effective_capacity,
            'parcel_count' => $trip->items->count(), 'actions' => $actions,
            'items' => $trip->items->map(fn ($item) => [
                'id' => $item->id, 'assignment_id' => $item->rider_assignment_id, 'status' => $item->status,
                'tracking_number' => $item->riderAssignment?->shipment?->tracking_number,
                'recipient' => $item->riderAssignment?->shipment?->sellerOrder?->order?->address?->recipient_name,
                'address' => $item->riderAssignment?->shipment?->sellerOrder?->order?->address?->formatted(),
            ])->values()];
    }

    public function trips(Request $request, RiderTripController $controller): JsonResponse
    {
        $data = $controller->index($request)->getData();
        abort_unless($data['localTripsReady'], 503, 'Local trip schema is not installed.');
        return $this->page($data['trips'], fn ($trip) => $this->tripPayload($trip));
    }

    public function trip(Request $request, int $trip, RiderTripController $controller): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->tripPayload($controller->show($request, $trip)->getData()['trip'])]);
    }

    public function payouts(Request $request, EarningPayoutService $payouts, PayoutDestinationReadiness $destinations): JsonResponse
    {
        $rider = $request->user()->riderProfile;
        abort_unless($rider, 403);
        return response()->json(['success' => true, 'data' => [
            'destination_ready' => $destinations->readyFor('rider_profiles'),
            'destination' => $rider->only(['payout_method', 'payout_bank_name', 'payout_account_name', 'payout_account_number']),
            'eligible' => $payouts->eligibleRiderParticipants($rider)->map(fn ($row) => [
                'id' => $row->id, 'amount' => $row->share_amount, 'tracking_number' => $row->pool?->shipment?->tracking_number,
            ])->values(),
            'receipts' => $payouts->riderPayoutReceipts($rider)->map(fn ($row) => [
                'id' => $row->id, 'amount' => $row->amount, 'status' => $row->status,
                'paid_at' => $row->paid_at, 'proof_available' => filled($row->metadata['payout_proof_path'] ?? null),
                'reference' => $row->metadata['payout_external_reference'] ?? null,
            ])->values(),
        ]])->header('Cache-Control', 'private, no-store');
    }

    public function attendance(Request $request): JsonResponse
    {
        $id = $request->user()->riderProfile->id;
        abort_unless(Schema::hasTable('interhub_attendance_sessions') && Schema::hasTable('interhub_payroll_items'), 503, 'Attendance is not installed.');
        $rows = InterhubAttendanceSession::where('rider_profile_id', $id)->with(['manifest', 'payrollItem'])->latest('clock_in_at')->paginate(20);
        return $this->page($rows, fn ($row) => [
            'id' => $row->id, 'clock_in_at' => $row->clock_in_at, 'clock_out_at' => $row->clock_out_at,
            'worked_minutes' => $row->worked_minutes, 'gross_pay' => $row->gross_pay,
            'daily_rate_snapshot' => $row->daily_rate_snapshot, 'region_type' => $row->region_type,
            'overtime_review' => $row->overtime_review,
            'clock_in_source' => $row->clock_in_source, 'clock_out_source' => $row->clock_out_source,
            'manifest_number' => $row->manifest?->manifest_number,
            'payroll' => $row->payrollItem ? [
                'id' => $row->payrollItem->id, 'amount' => $row->payrollItem->amount, 'status' => $row->payrollItem->status,
                'payment_reference' => $row->payrollItem->payment_reference, 'paid_at' => $row->payrollItem->paid_at,
                'proof_available' => filled($row->payrollItem->proof_path),
            ] : null,
        ]);
    }

    public function profileUpdates(Request $request): JsonResponse
    {
        abort_unless(Schema::hasTable('rider_profile_update_requests'), 503, 'Profile review is not installed.');
        return $this->page($request->user()->riderProfile->profileUpdateRequests()->latest()->paginate(20), fn ($row) => $row->only([
            'id', 'vehicle_type', 'plate_number', 'drivers_license_number', 'status', 'review_notes', 'submitted_at', 'reviewed_at',
        ]));
    }

    public function settings(Request $request, WorkspaceSettingsController $controller, PolicyAcceptanceService $policies): JsonResponse
    {
        $data = $controller->show($request, 'rider', $policies)->getData();
        return response()->json(['success' => true, 'data' => $data['preferences']]);
    }

    public function receipt(Request $request, Conversation $conversation): JsonResponse
    {
        abort_unless($conversation->participants()->where('users.id', $request->user()->id)->wherePivotNull('left_at')->exists(), 403);
        $other = $conversation->participants()->where('users.id', '!=', $request->user()->id)->wherePivotNull('left_at')->first();
        $visible = $other && (bool) ($other->notification_preferences['show_online_status'] ?? true);
        return response()->json(['success' => true, 'data' => [
            'recipient_online' => $visible && Cache::store('database')->has('message-presence:user:'.$other->id),
            'recipient_read_at' => $other?->pivot?->last_read_at,
        ]]);
    }

    public function offers(Request $request): JsonResponse
    {
        $rows = SellerPromotion::where('is_active', true)
            ->where(fn ($q) => $q->whereNull('starts_at')->orWhere('starts_at', '<=', now()))
            ->where(fn ($q) => $q->whereNull('ends_at')->orWhere('ends_at', '>', now()))
            ->where(fn ($q) => $q->whereNull('max_redemptions')->orWhereColumn('redemptions_used', '<', 'max_redemptions'))
            ->whereHas('sellerProfile', fn ($q) => $q->where('status', 'ACTIVE')->where('store_visibility', true)->where('vacation_mode', false)
                ->whereHas('user', fn ($u) => $u->where('status', 'ACTIVE')))
            ->with([
                'sellerProfile',
                'components.productVariant.productImage',
                'components.productVariant.product.images',
                'rewardProduct.images',
                'rewardProduct.variants.productImage',
                'rewardProduct.variants.product.images',
                'rewardVariant.productImage',
                'rewardVariant.product.images',
                'buyVariant.productImage',
                'buyVariant.product.images',
            ])
            ->latest()
            ->paginate(20);

        $variant = fn ($v): ?array => $v ? [
            'id' => $v->id,
            'name' => $v->product?->name.' - '.($v->description ?: $v->sku),
            'product_name' => $v->product?->name,
            'variant_name' => $v->description ?: $v->sku,
            'price' => number_format((float) $v->final_price, 2, '.', ''),
            'stock' => (int) $v->stock,
            'image' => $v->productImage?->file_path
                ?? $v->product?->images?->firstWhere('is_primary', true)?->file_path
                ?? $v->product?->images?->first()?->file_path,
        ] : null;

        return $this->page($rows, function ($offer) use ($variant): array {
            $components = $offer->components
                ->filter(fn ($component) => $component->productVariant?->is_active)
                ->values();
            $groups = $components->groupBy(fn ($component) => filled($component->choice_group)
                ? 'choice:'.$component->choice_group
                : 'variant:'.$component->id);
            $usualTotal = (float) $groups->sum(function ($options): float {
                $component = $options->first();
                $availablePrices = $options
                    ->filter(fn ($option) => $option->productVariant
                        && (int) $option->productVariant->stock >= (int) $option->quantity)
                    ->map(fn ($option) => (float) $option->productVariant->price);

                return (float) ($availablePrices->min() ?? 0)
                    * max(1, (int) $component->quantity);
            });
            $bundlePrice = (float) ($offer->bundle_price ?? 0);
            $remaining = $offer->max_redemptions === null
                ? null
                : max(0, (int) $offer->max_redemptions - (int) $offer->redemptions_used);
            $rewardVariants = $offer->rewardVariant
                ? collect([$offer->rewardVariant])
                : ($offer->rewardProduct?->variants ?? collect());

            return [
                'id' => $offer->id,
                'name' => $offer->name,
                'type' => $offer->promotion_type,
                'seller' => $offer->sellerProfile?->business_name,
                'bundle_price' => $offer->bundle_price,
                'usual_total' => $usualTotal > 0 ? number_format($usualTotal, 2, '.', '') : null,
                'savings' => $usualTotal > $bundlePrice
                    ? number_format($usualTotal - $bundlePrice, 2, '.', '')
                    : null,
                'buy_quantity' => $offer->buy_quantity,
                'reward_quantity' => $offer->reward_quantity,
                'reward_discount_percent' => $offer->reward_discount_percent,
                'max_redemptions' => $offer->max_redemptions,
                'redemptions_used' => (int) $offer->redemptions_used,
                'redemptions_remaining' => $remaining,
                'max_per_buyer' => $offer->max_per_buyer,
                'starts_at' => $offer->starts_at?->toIso8601String(),
                'ends_at' => $offer->ends_at?->toIso8601String(),
                'buy_item' => $variant($offer->buyVariant),
                'components' => $components->map(fn ($component) => [
                    'choice_group' => $component->choice_group,
                    'quantity' => (int) $component->quantity,
                    'variant' => $variant($component->productVariant),
                ])->values(),
                'rewards' => $rewardVariants
                    ->filter(fn ($reward) => $reward->is_active && $reward->stock > 0)
                    ->map($variant)
                    ->values(),
            ];
        });
    }

}
