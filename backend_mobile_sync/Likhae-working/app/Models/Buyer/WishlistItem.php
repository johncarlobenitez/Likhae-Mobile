<?php

namespace App\Models\Buyer;

use App\Models\Seller\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Model;

class WishlistItem extends Model
{
    protected $fillable = ['user_id', 'product_id'];

    public function user(): BelongsTo { return $this->belongsTo(User::class); }

    public function product(): BelongsTo { return $this->belongsTo(Product::class); }
}
