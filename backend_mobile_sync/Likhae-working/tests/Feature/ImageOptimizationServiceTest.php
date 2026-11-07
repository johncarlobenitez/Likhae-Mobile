<?php

namespace Tests\Feature;

use App\Services\Media\ImageOptimizationService;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class ImageOptimizationServiceTest extends TestCase
{
    public function test_it_resizes_and_reencodes_uploaded_images_as_webp(): void
    {
        Storage::fake('public');

        $path = app(ImageOptimizationService::class)->store(
            UploadedFile::fake()->image('camera-photo.jpg', 3000, 2000)->size(5000),
            'optimized-images'
        );

        Storage::disk('public')->assertExists($path);
        $this->assertStringEndsWith('.webp', $path);

        [$width, $height] = getimagesize(Storage::disk('public')->path($path));
        $this->assertLessThanOrEqual(1920, max($width, $height));
    }
}
