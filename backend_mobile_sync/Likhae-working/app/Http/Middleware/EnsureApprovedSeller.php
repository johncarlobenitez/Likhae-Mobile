<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureApprovedSeller
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        abort_unless(
            $user?->isAccountType(User::TYPE_SELLER)
            && $user->sellerProfile()->where('status', 'ACTIVE')->exists(),
            403,
            'An active seller account is required.',
        );

        return $next($request);
    }
}
