<?php

namespace App\Models\Logistics;

use App\Models\Rider\RiderAssignment;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeliveryAttempt extends Model
{
    protected $fillable = [
        'shipment_id',
        'rider_assignment_id',
        'attempt_number',
        'status',
        'failure_reason',
        'proof_path',
        'attempted_at',
        'next_attempt_at',
    ];

    protected function casts(): array
    {
        return [
            'attempted_at' => 'datetime',
            'next_attempt_at' => 'datetime',
        ];
    }

    public function shipment(): BelongsTo
    {
        return $this->belongsTo(Shipment::class);
    }

    public function riderAssignment(): BelongsTo
    {
        return $this->belongsTo(RiderAssignment::class);
    }
}
