<?php

namespace App\Models\Logistics;

use App\Models\Auth\RegistrationApplication;
use App\Models\Buyer\Address;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LogisticsApplicationData extends Model
{
    protected $table = 'logistics_application_data';

    protected $fillable = [
        'registration_application_id',
        'business_address_id',
        'business_name',
        'business_registration_number',
        'dti_registration_number',
        'tin',
    ];

    public function application(): BelongsTo
    {
        return $this->belongsTo(RegistrationApplication::class, 'registration_application_id');
    }

    public function businessAddress(): BelongsTo
    {
        return $this->belongsTo(Address::class, 'business_address_id');
    }
}
