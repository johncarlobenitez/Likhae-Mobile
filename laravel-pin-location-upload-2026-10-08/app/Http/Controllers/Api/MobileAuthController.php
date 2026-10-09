<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Auth\PhilippineAddressController;
use App\Http\Requests\StoreRegistrationRequest;
use App\Mail\RegistrationEmailVerificationCode;
use App\Models\User;
use App\Models\Admin\PlatformSetting;
use App\Services\RegistrationWorkflowService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Symfony\Component\Mailer\Exception\TransportExceptionInterface;

class MobileAuthController extends Controller
{
    private const REGISTRATION_EMAIL_CODE_TTL_MINUTES = 10;

    private const REGISTRATION_EMAIL_CODE_MAX_ATTEMPTS = 5;

    public function sendRegistrationEmailVerificationCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
        ]);
        $email = mb_strtolower(trim($data['email']));

        if (User::query()->whereRaw('LOWER(email) = ?', [$email])->exists()) {
            return response()->json([
                'message' => 'An account with this email already exists.',
                'errors' => ['email' => ['An account with this email already exists.']],
            ], 422);
        }

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        try {
            Mail::to($email)->send(new RegistrationEmailVerificationCode($code));
        } catch (TransportExceptionInterface $exception) {
            report($exception);

            return response()->json([
                'message' => 'The verification email could not be sent. Check the SMTP settings and try again.',
            ], 503);
        }

        Cache::put(
            $this->mobileEmailCodeCacheKey($email),
            [
                'hash' => Hash::make($code),
                'attempts' => 0,
                'expires_at' => now()->addMinutes(self::REGISTRATION_EMAIL_CODE_TTL_MINUTES)->timestamp,
            ],
            now()->addMinutes(self::REGISTRATION_EMAIL_CODE_TTL_MINUTES),
        );

        return response()->json([
            'message' => 'A verification code was sent. It expires in 10 minutes.',
        ]);
    }

    public function verifyRegistrationEmailVerificationCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:255'],
            'code' => ['required', 'digits:6'],
        ]);
        $email = mb_strtolower(trim($data['email']));
        $cacheKey = $this->mobileEmailCodeCacheKey($email);
        $challenge = Cache::get($cacheKey);

        if (! is_array($challenge) || ! isset($challenge['hash'], $challenge['attempts'], $challenge['expires_at'])) {
            return response()->json([
                'message' => 'This code has expired. Request a new verification code.',
            ], 422);
        }

        if ((int) $challenge['expires_at'] <= now()->timestamp) {
            Cache::forget($cacheKey);

            return response()->json([
                'message' => 'This code has expired. Request a new verification code.',
            ], 422);
        }

        if ((int) $challenge['attempts'] >= self::REGISTRATION_EMAIL_CODE_MAX_ATTEMPTS) {
            Cache::forget($cacheKey);

            return response()->json([
                'message' => 'Too many incorrect attempts. Request a new verification code.',
            ], 429);
        }

        if (! Hash::check($data['code'], $challenge['hash'])) {
            $attempts = (int) $challenge['attempts'] + 1;

            if ($attempts >= self::REGISTRATION_EMAIL_CODE_MAX_ATTEMPTS) {
                Cache::forget($cacheKey);

                return response()->json([
                    'message' => 'Too many incorrect attempts. Request a new verification code.',
                ], 429);
            }

            Cache::put(
                $cacheKey,
                [
                    'hash' => $challenge['hash'],
                    'attempts' => $attempts,
                    'expires_at' => $challenge['expires_at'],
                ],
                now()->addSeconds(max(1, (int) $challenge['expires_at'] - now()->timestamp)),
            );

            return response()->json([
                'message' => 'That verification code is incorrect.',
                'errors' => ['code' => ['That verification code is incorrect.']],
            ], 422);
        }

        Cache::forget($cacheKey);
        $verificationToken = Str::random(64);
        Cache::put(
            $this->mobileEmailVerificationTokenKey($verificationToken),
            $email,
            now()->addMinutes(self::REGISTRATION_EMAIL_CODE_TTL_MINUTES),
        );

        return response()->json([
            'message' => 'Email verified. You can continue your registration.',
            'verification_token' => $verificationToken,
        ]);
    }

    public function register(
        StoreRegistrationRequest $request,
        RegistrationWorkflowService $workflow,
    ): JsonResponse {
        if (! (bool) PlatformSetting::valueOf('registration_enabled', true)) {
            return response()->json([
                'success' => false,
                'message' => 'New registrations are temporarily disabled.',
            ], 403);
        }

        $verificationToken = trim((string) $request->input('email_verification_token'));
        $verifiedEmail = $verificationToken === ''
            ? null
            : Cache::get($this->mobileEmailVerificationTokenKey($verificationToken));
        $requestEmail = mb_strtolower(trim((string) $request->input('email')));

        if (! is_string($verifiedEmail) || $verifiedEmail !== $requestEmail) {
            return response()->json([
                'message' => 'Verify your email address before submitting your registration.',
                'errors' => ['email' => ['Verify your email address before submitting your registration.']],
            ], 422);
        }

        if (! PhilippineAddressController::selectionIsValid(
            (string) $request->input('region_code'),
            (string) $request->input('region'),
            (string) $request->input('province_code'),
            (string) $request->input('province'),
            (string) $request->input('municipality_code'),
            (string) $request->input('municipality'),
            (string) $request->input('barangay_code'),
            (string) $request->input('barangay'),
        )) {
            return response()->json([
                'success' => false,
                'message' => 'Please select a valid Philippine address.',
                'errors' => ['address' => ['The selected address is invalid.']],
            ], 422);
        }

        $expectedPostalCode = PhilippineAddressController::expectedPostalCodeFor(
            (string) $request->input('province_code'),
            (string) $request->input('municipality_code'),
            (string) $request->input('province'),
            (string) $request->input('municipality'),
        );
        if ($expectedPostalCode !== null
            && filled($request->input('postal_code'))
            && (string) $request->input('postal_code') !== $expectedPostalCode) {
            return response()->json([
                'success' => false,
                'message' => 'The postal code does not match the selected municipality.',
                'errors' => ['postal_code' => ['Use the postal code for the selected municipality.']],
            ], 422);
        }

        $application = $workflow->submit($request);
        Cache::forget($this->mobileEmailVerificationTokenKey($verificationToken));

        return response()->json([
            'success' => true,
            'message' => 'Registration submitted. Wait for account approval before signing in.',
            'data' => [
                'application_number' => $application->application_number,
                'status' => $application->status,
                'email' => $application->user?->email,
            ],
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string'],
            'device_name' => ['sometimes', 'nullable', 'string', 'max:100'],
        ]);

        $email = mb_strtolower(trim($credentials['email']));
        $rateLimitKey = 'mobile-login:'.hash('sha256', $email.'|'.$request->ip());

        if (RateLimiter::tooManyAttempts($rateLimitKey, 5)) {
            return response()->json([
                'success' => false,
                'message' => 'Too many sign-in attempts. Try again in '.RateLimiter::availableIn($rateLimitKey).' seconds.',
                'errors' => ['email' => ['Too many sign-in attempts.']],
            ], 429);
        }

        $user = User::query()->where('email', $email)->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            RateLimiter::hit($rateLimitKey, 60);

            return response()->json([
                'success' => false,
                'message' => 'Invalid email or password.',
                'errors' => ['email' => ['Invalid email or password.']],
            ], 401);
        }

        if (! $user->isActive() || ! $user->email_verified_at) {
            return response()->json([
                'success' => false,
                'message' => $user->inactiveMessage(),
                'errors' => ['email' => [$user->inactiveMessage()]],
            ], 403);
        }

        $mobileRoles = $this->mobileRoles($user);
        if ($mobileRoles === []) {
            return response()->json([
                'success' => false,
                'message' => 'This account does not have Buyer or Rider mobile access.',
                'errors' => ['email' => ['This account does not have Buyer or Rider mobile access.']],
            ], 403);
        }

        RateLimiter::clear($rateLimitKey);

        $plainTextToken = Str::random(64);
        $expiresAt = now()->addDays(30);
        $user->forceFill([
            'api_token_hash' => hash('sha256', $plainTextToken),
            'api_token_expires_at' => $expiresAt,
        ])->save();

        return response()->json([
            'success' => true,
            'message' => 'Signed in successfully.',
            'token_type' => 'Bearer',
            'token' => $plainTextToken,
            'access_token' => $plainTextToken,
            'expires_at' => $expiresAt->toIso8601String(),
            'device_name' => trim((string) ($credentials['device_name'] ?? '')) ?: 'likhae-mobile',
            'user' => $this->userPayload($user, $mobileRoles),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        /** @var User $user */
        $user = $request->user();
        $mobileRoles = $this->mobileRoles($user);

        if (! $user->isActive()) {
            return response()->json(['success' => false, 'message' => $user->inactiveMessage()], 403);
        }

        if ($mobileRoles === []) {
            return response()->json([
                'success' => false,
                'message' => 'This account no longer has Buyer or Rider mobile access.',
            ], 403);
        }

        return response()->json([
            'success' => true,
            'user' => $this->userPayload($user, $mobileRoles),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->forceFill([
            'api_token_hash' => null,
            'api_token_expires_at' => null,
        ])->save();

        return response()->json([
            'success' => true,
            'message' => 'Signed out successfully.',
        ]);
    }

    /** @return array<int, string> */
    private function mobileRoles(User $user): array
    {
        return match (strtoupper((string) $user->account_type)) {
            User::TYPE_BUYER => ['buyer'],
            User::TYPE_RIDER => ['rider'],
            default => [],
        };
    }

    /** @param array<int, string> $mobileRoles */
    private function userPayload(User $user, array $mobileRoles): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'first_name' => $user->first_name,
            'middle_initial' => $user->middle_initial,
            'last_name' => $user->last_name,
            'email' => $user->email,
            'contact_number' => $user->contact_number,
            'account_type' => $user->account_type,
            'status' => $user->status,
            'email_verified' => $user->email_verified_at !== null,
            'roles' => $mobileRoles,
            'mobile_roles' => $mobileRoles,
        ];
    }

    private function mobileEmailCodeCacheKey(string $email): string
    {
        return 'mobile_registration_email_code:'.hash('sha256', $email);
    }

    private function mobileEmailVerificationTokenKey(string $token): string
    {
        return 'mobile_registration_email_verified:'.hash('sha256', $token);
    }
}
