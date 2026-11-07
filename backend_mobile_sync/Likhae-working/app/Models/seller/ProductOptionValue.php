<?php

namespace App\Models\Seller;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class ProductOptionValue extends Model
{
    protected $fillable = [
        'product_option_id',
        'value',
        'sort_order',
    ];

    public function option(): BelongsTo
    {
        return $this->belongsTo(ProductOption::class, 'product_option_id');
    }

    public function variants(): BelongsToMany
    {
        return $this->belongsToMany(
            ProductVariant::class,
            'product_variant_option_values',
            'product_option_value_id',
            'product_variant_id',
        )->withTimestamps();
    }

    public function variantLinks(): HasMany
    {
        return $this->hasMany(ProductVariantOptionValue::class);
    }

    public function images(): HasMany
    {
        return $this->hasMany(ProductImage::class, 'product_option_value_id')->orderBy('sort_order');
    }
}
