<?php

namespace App\Models\Seller;

use App\Models\Auth\RegistrationApplication;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellerApplicationData extends Model
{
    protected $table = 'seller_application_data';

    protected $fillable = [
        'registration_application_id',
        'category_id',
        'business_name',
        'business_registration_number',
        'seller_type',
        'tin',
    ];

    public function application(): BelongsTo
    {
        return $this->belongsTo(RegistrationApplication::class, 'registration_application_id');
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }
}
