<?php

namespace App\Models\Admin;

use App\Models\Seller\SellerOrder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class CommissionTransaction extends Model
{
    protected $fillable = [
        'seller_order_id',
        'commission_rate',
        'commissionable_amount',
        'commission_amount',
        'status',
        'calculated_at',
        'settled_at',
    ];

    protected function casts(): array
    {
        return [
            'commission_rate' => 'decimal:4',
            'commissionable_amount' => 'decimal:2',
            'commission_amount' => 'decimal:2',
            'calculated_at' => 'datetime',
            'settled_at' => 'datetime',
        ];
    }

    public function sellerOrder(): BelongsTo
    {
        return $this->belongsTo(SellerOrder::class);
    }
}
