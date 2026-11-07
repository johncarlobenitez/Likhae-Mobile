<?php

namespace App\Models\Buyer;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Review extends Model
{
    protected $fillable = [
        'order_item_id',
        'buyer_user_id',
        'rating',
        'rider_profile_id',
        'rider_rating',
        'rider_comment',
        'comment',
        'seller_reply',
        'seller_replied_at',
        'status',
    ];

    protected function casts(): array
    {
        return [
            'seller_replied_at' => 'datetime',
        ];
    }

    public function orderItem(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class);
    }

    public function buyer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'buyer_user_id');
    }
}
