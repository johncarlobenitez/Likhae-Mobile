<?php

namespace App\Models\Admin;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellerComplianceAction extends Model
{
    protected $fillable = [
        'seller_compliance_case_id',
        'performed_by_user_id',
        'action_type',
        'reason',
        'performed_at',
    ];

    protected function casts(): array
    {
        return ['performed_at' => 'datetime'];
    }

    public function complianceCase(): BelongsTo
    {
        return $this->belongsTo(SellerComplianceCase::class, 'seller_compliance_case_id');
    }

    public function performedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'performed_by_user_id');
    }
}
