<?php

namespace App\Models\Rider;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RiderAssignmentLocation extends Model
{
    protected $fillable = [
        'rider_assignment_id',
        'latitude',
        'longitude',
        'recorded_at',
    ];

    protected function casts(): array
    {
        return [
            'latitude' => 'float',
            'longitude' => 'float',
            'recorded_at' => 'datetime',
        ];
    }

    public function riderAssignment(): BelongsTo
    {
        return $this->belongsTo(RiderAssignment::class);
    }
}
