<?php

namespace App\Models\Buyer;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Cart extends Model
{
    use HasFactory;

    public const STATUS_ACTIVE = 'ACTIVE';
    public const STATUS_CONVERTED = 'CONVERTED';
    public const STATUS_ABANDONED = 'ABANDONED';

    protected $fillable = [
        'buyer_user_id',
        'status',
        'converted_at',
    ];

    protected function casts(): array
    {
        return ['converted_at' => 'datetime'];
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_user_id');
    }

    /** Transitional alias. */
    public function user(): BelongsTo
    {
        return $this->buyer();
    }

    public function items(): HasMany
    {
        return $this->hasMany(CartItem::class);
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }
}
