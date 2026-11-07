<?php

namespace App\Models\Admin;

use App\Events\NotificationCreated;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

class Notification extends Model
{
    protected $fillable = [
        'user_id',
        'type',
        'title',
        'message',
        'reference_type',
        'reference_id',
        'action_url',
        'read_at',
    ];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::created(function (self $notification): void {
            DB::afterCommit(function () use ($notification): void {
                try {
                    NotificationCreated::dispatch($notification);
                } catch (Throwable $exception) {
                    // Realtime delivery is an enhancement. Never roll back the
                    // persisted notification when Reverb is temporarily offline.
                    Log::warning('Notification realtime broadcast could not start.', [
                        'notification_id' => $notification->id,
                        'exception' => $exception->getMessage(),
                    ]);
                }
            });
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function scopeUnread(Builder $query): Builder
    {
        return $query->whereNull('read_at');
    }
}
