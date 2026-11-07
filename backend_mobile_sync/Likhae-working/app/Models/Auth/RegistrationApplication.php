<?php

namespace App\Models\Auth;

use App\Models\Logistics\LogisticsApplicationData;
use App\Models\Rider\RiderApplicationData;
use App\Models\Seller\SellerApplicationData;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class RegistrationApplication extends Model
{
    public const STATUS_PENDING = 'PENDING';
    public const STATUS_UNDER_REVIEW = 'UNDER_REVIEW';
    public const STATUS_APPROVED = 'APPROVED';
    public const STATUS_REJECTED = 'REJECTED';
    public const STATUS_CANCELLED = 'CANCELLED';

    protected $fillable = [
        'application_number',
        'user_id',
        'status',
        'reviewed_by_user_id',
        'submitted_at',
        'reviewed_at',
        'decision_notes',
        'rejection_reason',
    ];

    protected function casts(): array
    {
        return [
            'submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by_user_id');
    }

    public function documents(): HasMany
    {
        return $this->hasMany(ApplicationDocument::class);
    }

    public function sellerData(): HasOne
    {
        return $this->hasOne(SellerApplicationData::class);
    }

    public function logisticsData(): HasOne
    {
        return $this->hasOne(LogisticsApplicationData::class);
    }

    public function riderData(): HasOne
    {
        return $this->hasOne(RiderApplicationData::class);
    }

    public function getApplicationTypeAttribute(): string
    {
        return (string) ($this->user?->account_type ?? '');
    }
}
