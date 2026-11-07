<?php

namespace App\Models\Rider;

use App\Models\Logistics\ServiceArea;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RiderAreaAssignment extends Model
{
    protected $fillable = [
        'rider_profile_id',
        'service_area_id',
        'assigned_by_user_id',
        'is_active',
        'assigned_at',
        'ended_at',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
            'assigned_at' => 'datetime',
            'ended_at' => 'datetime',
        ];
    }

    public function riderProfile(): BelongsTo
    {
        return $this->belongsTo(RiderProfile::class);
    }

    public function serviceArea(): BelongsTo
    {
        return $this->belongsTo(ServiceArea::class);
    }

    public function assigner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_by_user_id');
    }
}
