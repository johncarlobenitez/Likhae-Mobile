<?php

namespace App\Models\Rider;

use App\Models\Auth\RegistrationApplication;
use App\Models\Logistics\LogisticsCenter;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RiderApplicationData extends Model
{
    protected $table = 'rider_application_data';

    protected $fillable = [
        'registration_application_id',
        'target_logistics_center_id',
        'vehicle_type',
        'plate_number',
        'drivers_license_number',
    ];

    public function application(): BelongsTo
    {
        return $this->belongsTo(RegistrationApplication::class, 'registration_application_id');
    }

    public function targetLogisticsCenter(): BelongsTo
    {
        return $this->belongsTo(LogisticsCenter::class, 'target_logistics_center_id');
    }
}
