<?php

namespace App\Models\Rider;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RiderEarning extends Model
{
    protected $fillable = [
        'rider_assignment_id',
        'rider_profile_id',
        'amount',
        'status',
        'earned_at',
        'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'decimal:2',
            'earned_at' => 'datetime',
            'paid_at' => 'datetime',
        ];
    }

    public function riderAssignment(): BelongsTo
    {
        return $this->belongsTo(RiderAssignment::class);
    }

    public function riderProfile(): BelongsTo
    {
        return $this->belongsTo(RiderProfile::class);
    }
}
