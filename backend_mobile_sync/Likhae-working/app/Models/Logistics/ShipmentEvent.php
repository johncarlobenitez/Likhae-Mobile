<?php

namespace App\Models\Logistics;

use App\Models\Rider\RiderAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ShipmentEvent extends Model
{
    protected $table = 'shipment_events';

    protected $fillable = [
        'shipment_id',
        'status',
        'actor_user_id',
        'logistics_center_id',
        'rider_assignment_id',
        'notes',
        'occurred_at',
    ];

    protected function casts(): array
    {
        return ['occurred_at' => 'datetime'];
    }

    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }

    public function logisticsCenter(): BelongsTo
    {
        return $this->belongsTo(LogisticsCenter::class);
    }

    public function riderAssignment(): BelongsTo
    {
        return $this->belongsTo(RiderAssignment::class);
    }
}
