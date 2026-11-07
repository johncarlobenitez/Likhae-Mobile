<?php

namespace App\Http\Middleware;

use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class EnsureWorkspaceRole
{
    public function handle(Request $request, Closure $next, string $role): Response
    {
        if (! Auth::check()) {
            return redirect()->route('login')->withErrors(['email' => 'Please sign in first.']);
        }

        /** @var User $user */
        $user = Auth::user();

        if (! $user->isActive()) {
            $message = $user->inactiveMessage();

            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            return redirect()->route(
                in_array(strtolower($role), ['logistics', 'rider', 'courier'], true)
                    ? 'logistics.login'
                    : 'login'
            )->withErrors(['email' => $message]);
        }

        $expectedType = strtolower($role) === 'courier'
            ? User::TYPE_RIDER
            : strtoupper($role);

        abort_unless($user->isAccountType($expectedType), 403);

        return $next($request);
    }
}
