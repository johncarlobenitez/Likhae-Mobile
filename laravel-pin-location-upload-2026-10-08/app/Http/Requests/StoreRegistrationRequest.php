<?php

namespace App\Http\Requests;

use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\Validator;

class StoreRegistrationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $google = $this->hasSession()
            ? $this->session()->get('google_buyer_registration')
            : null;
        $googleEmail = is_array($google) ? ($google['email'] ?? null) : null;

        $this->merge([
            'account_type' => $googleEmail ? 'buyer' : strtolower(trim((string) $this->input('account_type'))),
            'email' => mb_strtolower(trim((string) ($googleEmail ?: $this->input('email')))),
            'contact_number' => $this->normalizeContactNumber((string) $this->input('contact_number')),
            'sex' => strtolower(trim((string) $this->input('sex'))),
            'plate_number' => filled($this->input('plate_number'))
                ? mb_strtoupper(trim((string) $this->input('plate_number')))
                : null,
            'drivers_license_number' => filled($this->input('drivers_license_number'))
                ? mb_strtoupper(trim((string) $this->input('drivers_license_number')))
                : null,
            'business_registration_number' => filled($this->input('business_registration_number'))
                ? trim((string) $this->input('business_registration_number'))
                : null,
            'dti_registration_number' => filled($this->input('dti_registration_number'))
                ? trim((string) $this->input('dti_registration_number'))
                : null,
        ]);
    }

    public function rules(): array
    {
        $type = strtolower((string) $this->input('account_type'));
        $isSeller = $type === 'seller';
        $isLogistics = $type === 'logistics';
        $isRider = $type === 'rider';

        $businessRegistrationRules = ['nullable', 'string', 'max:100'];
        if ($isSeller) {
            $businessRegistrationRules[] = Rule::unique('seller_profiles', 'business_registration_number');
        } elseif ($isLogistics) {
            $businessRegistrationRules[] = Rule::unique('logistics_centers', 'business_registration_number');
        }

        return [
            'account_type' => ['required', Rule::in(['buyer', 'seller', 'logistics', 'rider'])],
            'first_name' => ['required', 'string', 'max:100'],
            'middle_initial' => ['nullable', 'string', 'max:10'],
            'last_name' => ['required', 'string', 'max:100'],
            'sex' => ['required', Rule::in(['male', 'female', 'other', 'prefer_not_to_say'])],
            'email' => ['required', 'email', 'max:255', Rule::unique('users', 'email')],
            // The mobile API verifies this token before registration. It is
            // optional here so the existing browser registration flow can
            // continue using its session-based email verification.
            'email_verification_token' => ['sometimes', 'nullable', 'string', 'size:64'],
            'contact_number' => [
                'required',
                'string',
                'max:30',
                'regex:/^(?:\+63|0)9\d{9}$/',
                Rule::unique('users', 'contact_number'),
            ],
            'birthday' => ['required', 'date', 'before:today'],
            'age' => ['required', 'integer', 'between:18,120'],

            'region' => ['required', 'string', 'max:150'],
            'region_code' => ['required', 'string', 'max:50'],
            'province' => ['required', 'string', 'max:150'],
            'province_code' => ['required', 'string', 'max:50'],
            'municipality' => ['required', 'string', 'max:150'],
            'municipality_code' => ['required', 'string', 'max:50'],
            'barangay' => ['required', 'string', 'max:150'],
            'barangay_code' => ['required', 'string', 'max:50'],
            'postal_code' => ['nullable', 'string', 'max:20'],
            'house_number' => ['nullable', 'string', 'max:100'],
            'street' => ['required', 'string', 'max:255'],
            'landmark' => ['nullable', 'string', 'max:255'],
            // Location is not required to submit a registration. If a client
            // provides it, still validate the coordinate range.
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],

            'business_name' => [Rule::requiredIf($isSeller || $isLogistics), 'nullable', 'string', 'max:200'],
            'line_of_business' => [Rule::requiredIf($isSeller), 'nullable', 'integer', Rule::exists('categories', 'id')->where('is_active', true)],
            'business_registration_number' => $businessRegistrationRules,
            'dti_registration_number' => ['nullable', 'string', 'max:100', Rule::unique('logistics_centers', 'dti_registration_number')],

            'target_logistics_center_id' => [
                Rule::requiredIf($isRider),
                'nullable',
                'integer',
                Rule::exists('logistics_centers', 'id')->where('status', 'ACTIVE'),
            ],
            'vehicle_type' => [Rule::requiredIf($isRider), 'nullable', Rule::in(['motorcycle', 'car', 'van', 'truck'])],
            'plate_number' => [
                Rule::requiredIf($isRider),
                'nullable',
                'string',
                'max:50',
                Rule::unique('rider_profiles', 'plate_number'),
            ],
            'drivers_license_number' => [
                Rule::requiredIf($isRider),
                'nullable',
                'string',
                'max:100',
                Rule::unique('rider_profiles', 'drivers_license_number'),
            ],

            'valid_id' => ['required', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
            'business_permit' => [Rule::requiredIf($isSeller || $isLogistics), 'nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
            'or_cr' => [Rule::requiredIf($isRider), 'nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],
            'drivers_license' => [Rule::requiredIf($isRider), 'nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:5120'],

            'password' => ['required', 'confirmed', 'max:72', Password::min(8)->mixedCase()->numbers()],
            'terms' => ['accepted'],
        ];
    }

    public function after(): array
    {
        return [function (Validator $validator): void {
            if (! $this->filled('birthday') || ! $this->filled('age')) {
                return;
            }

            try {
                $calculated = \Carbon\Carbon::parse($this->input('birthday'))->age;
            } catch (\Throwable) {
                return;
            }

            if ((int) $this->input('age') !== $calculated) {
                $validator->errors()->add('age', 'The age must match the selected birthday.');
            }
        }];
    }

    public function accountTypeConstant(): string
    {
        return match (strtolower((string) $this->input('account_type'))) {
            'seller' => User::TYPE_SELLER,
            'logistics' => User::TYPE_LOGISTICS,
            'rider' => User::TYPE_RIDER,
            default => User::TYPE_BUYER,
        };
    }

    private function normalizeContactNumber(string $value): string
    {
        $number = preg_replace('/[^0-9+]/', '', trim($value)) ?? '';

        if (preg_match('/^9\d{9}$/', $number)) {
            return '+63'.$number;
        }

        return $number;
    }
}
