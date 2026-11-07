<?php

namespace Database\Factories;

use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class UserFactory extends Factory
{
    protected static ?string $password;

    public function definition(): array
    {
        return [
            'account_type' => 'BUYER',
            'first_name' => fake()->firstName(),
            'middle_initial' => fake()->randomLetter(),
            'last_name' => fake()->lastName(),
            'sex' => fake()->randomElement(['MALE', 'FEMALE', 'PREFER_NOT_TO_SAY']),
            'email' => fake()->unique()->safeEmail(),
            'contact_number' => '09'.fake()->unique()->numerify('#########'),
            'birthday' => fake()->dateTimeBetween('-45 years', '-18 years')->format('Y-m-d'),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('Password1'),
            'status' => 'ACTIVE',
            'remember_token' => Str::random(10),
        ];
    }
}
