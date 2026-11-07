<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\Account\ProfilePhotoService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ProfilePhotoServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_profile_photo_replaces_and_removes_the_previous_file(): void
    {
        Storage::fake('public');
        $user = User::factory()->create(['profile_photo_path' => 'profile-photos/old.jpg']);
        Storage::disk('public')->put('profile-photos/old.jpg', 'old photo');

        app(ProfilePhotoService::class)->replace($user, UploadedFile::fake()->image('new.webp'));

        $user->refresh();
        $this->assertStringStartsWith('profile-photos/', $user->profile_photo_path);
        Storage::disk('public')->assertExists($user->profile_photo_path);
        Storage::disk('public')->assertMissing('profile-photos/old.jpg');
    }
}
