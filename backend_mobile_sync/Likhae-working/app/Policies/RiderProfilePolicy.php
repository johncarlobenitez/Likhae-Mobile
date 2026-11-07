<?php

namespace App\Policies;

use App\Models\Rider\RiderProfile;
use App\Models\User;

class RiderProfilePolicy
{
    public function before(User $user): ?bool
    {
        return $user->isAccountType(User::TYPE_ADMIN) ? true : null;
    }

    public function view(User $user, RiderProfile $rider): bool
    {
        if ($user->isAccountType(User::TYPE_RIDER)) {
            return $rider->user_id === $user->id;
        }

        if ($user->isAccountType(User::TYPE_LOGISTICS)) {
            return $rider->logisticsCenter?->owner_user_id === $user->id;
        }

        return false;
    }

    public function update(User $user, RiderProfile $rider): bool
    {
        return $this->view($user, $rider);
    }
}
