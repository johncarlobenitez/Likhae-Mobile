<?php

namespace App\Services\Reports;

use App\Models\Admin\CommissionTransaction;
use App\Models\Buyer\Order;
use App\Models\Logistics\Shipment;
use App\Models\Rider\RiderAssignment;
use App\Models\Seller\Product;
use App\Models\Seller\SellerOrder;
use App\Models\User;
use Illuminate\Support\Collection;

class PlatformReportService
{
    public function adminSummary(): array
    {
        return [
            'users' => User::query()->count(),
            'active_users' => User::query()->where('status', 'ACTIVE')->count(),
            'products' => Product::query()->count(),
            'orders' => Order::query()->count(),
            'seller_orders' => SellerOrder::query()->count(),
            'shipments' => Shipment::query()->count(),
            'commission_total' => (float) CommissionTransaction::query()->sum('commission_amount'),
        ];
    }

    public function sellerSummary(int $sellerProfileId): array
    {
        $orders = SellerOrder::query()->where('seller_profile_id', $sellerProfileId);

        return [
            'seller_orders' => (clone $orders)->count(),
            'gross_sales' => (float) (clone $orders)->sum('grand_total'),
            'pending_orders' => (clone $orders)->whereNotIn('status', ['COMPLETED', 'CANCELLED'])->count(),
            'products' => Product::query()->where('seller_profile_id', $sellerProfileId)->count(),
        ];
    }

    public function logisticsSummary(int $logisticsCenterId): array
    {
        $shipments = Shipment::query()->where('logistics_center_id', $logisticsCenterId);

        return [
            'shipments' => (clone $shipments)->count(),
            'at_sorting_center' => (clone $shipments)->where('current_status', 'AT_SORTING_CENTER')->count(),
            'sorted' => (clone $shipments)->where('current_status', 'SORTED')->count(),
            'out_for_delivery' => (clone $shipments)->where('current_status', 'OUT_FOR_DELIVERY')->count(),
            'delivered' => (clone $shipments)->where('current_status', 'DELIVERED')->count(),
        ];
    }

    public function riderSummary(int $riderProfileId): array
    {
        $assignments = RiderAssignment::query()->where('rider_profile_id', $riderProfileId);

        return [
            'assignments' => (clone $assignments)->count(),
            'pickup_assignments' => (clone $assignments)->where('assignment_type', 'PICKUP')->count(),
            'delivery_assignments' => (clone $assignments)->where('assignment_type', 'DELIVERY')->count(),
            'completed_assignments' => (clone $assignments)->where('status', 'COMPLETED')->count(),
        ];
    }

    public function recentShipmentStatuses(int $limit = 10): Collection
    {
        return Shipment::query()
            ->latest('updated_at')
            ->limit($limit)
            ->get(['tracking_number', 'current_status', 'updated_at']);
    }
}
