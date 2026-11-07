<?php

namespace App\Policies;

use App\Models\Seller\SellerProfile;
use App\Models\User;

class SellerProfilePolicy
{
    public function before(User $user): ?bool
    {
        return $user->isAccountType(User::TYPE_ADMIN) ? true : null;
    }

    public function view(User $user, SellerProfile $seller): bool
    {
        return $user->isAccountType(User::TYPE_SELLER)
            && $seller->user_id === $user->id;
    }

    public function update(User $user, SellerProfile $seller): bool
    {
        return $this->view($user, $seller);
    }
}
