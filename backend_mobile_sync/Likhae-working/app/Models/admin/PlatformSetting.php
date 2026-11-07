<?php

namespace App\Models\Admin;

use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PlatformSetting extends Model
{
    protected $table = 'platform_settings';

    protected $fillable = [
        'key',
        'value',
        'value_type',
        'updated_by_user_id',
    ];

    public function updatedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'updated_by_user_id');
    }

    public static function valueOf(string $key, mixed $default = null): mixed
    {
        $setting = static::query()->where('key', $key)->first();

        if (! $setting) {
            return $default;
        }

        return match (strtolower((string) $setting->value_type)) {
            'boolean' => filter_var($setting->value, FILTER_VALIDATE_BOOLEAN),
            'integer' => (int) $setting->value,
            'decimal', 'float' => (float) $setting->value,
            default => $setting->value,
        };
    }

    public static function put(string $key, mixed $value, string $type = 'string', ?int $updatedBy = null): self
    {
        $normalizedType = match (strtolower($type)) {
            'bool' => 'boolean',
            'int' => 'integer',
            'float' => 'decimal',
            default => strtolower($type),
        };

        $storedValue = $normalizedType === 'boolean'
            ? ($value ? '1' : '0')
            : (string) $value;

        return static::query()->updateOrCreate(
            ['key' => $key],
            [
                'value' => $storedValue,
                'value_type' => $normalizedType,
                'updated_by_user_id' => $updatedBy,
            ],
        );
    }

    public static function commissionRate(): float
    {
        return min(1.0, max(0.0, (float) static::valueOf('commission_rate', 0.10)));
    }

    public static function defaultCurrency(): string
    {
        return strtoupper((string) static::valueOf('default_currency', 'PHP'));
    }
}
