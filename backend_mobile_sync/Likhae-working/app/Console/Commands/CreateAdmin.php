<?php

namespace App\Console\Commands;

use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rules\Password;

class CreateAdmin extends Command
{
    protected $signature = 'app:create-admin';

    protected $description = 'Create an active LIKHAE administrator using the final users schema';

    public function handle(): int
    {
        $firstName = trim((string) $this->ask('Administrator first name'));
        $middleInitial = trim((string) ($this->ask('Middle initial (optional)') ?? ''));
        $lastName = trim((string) $this->ask('Administrator last name'));
        $email = mb_strtolower(trim((string) $this->ask('Administrator email')));
        $contactNumber = trim((string) $this->ask('Contact number (09XXXXXXXXX or +639XXXXXXXXX)'));
        $birthday = trim((string) $this->ask('Birthday (YYYY-MM-DD)'));
        $password = $this->secret('Password (8-72 characters, uppercase, lowercase and a number)');
        $confirmation = $this->secret('Confirm password');

        $validator = Validator::make([
            'first_name' => $firstName,
            'middle_initial' => $middleInitial !== '' ? $middleInitial : null,
            'last_name' => $lastName,
            'email' => $email,
            'contact_number' => $contactNumber,
            'birthday' => $birthday,
            'password' => $password,
            'password_confirmation' => $confirmation,
        ], [
            'first_name' => ['required', 'string', 'max:100'],
            'middle_initial' => ['nullable', 'string', 'max:10'],
            'last_name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'contact_number' => ['required', 'string', 'max:30', 'regex:/^(?:\+63|0)9\d{9}$/', 'unique:users,contact_number'],
            'birthday' => ['required', 'date', 'before:today'],
            'password' => ['required', 'confirmed', 'max:72', Password::min(8)->mixedCase()->numbers()],
        ]);

        if ($validator->fails()) {
            foreach ($validator->errors()->all() as $error) {
                $this->error($error);
            }

            return self::FAILURE;
        }

        User::create([
            'account_type' => User::TYPE_ADMIN,
            'first_name' => $firstName,
            'middle_initial' => $middleInitial !== '' ? $middleInitial : null,
            'last_name' => $lastName,
            'sex' => null,
            'email' => $email,
            'contact_number' => $contactNumber,
            'birthday' => $birthday,
            'password' => $password,
            'status' => User::STATUS_ACTIVE,
            'email_verified_at' => now(),
        ]);

        $this->info('Administrator created. Sign in at '.route('login').' to review registrations.');

        return self::SUCCESS;
    }
}
