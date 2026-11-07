<?php

namespace App\Services;

use App\Models\Buyer\Review;
use App\Models\Rider\RiderProfile;

class RiderRatingService
{
    public function record(Review $review, RiderProfile $rider, int $rating, ?string $comment): void
    {
        $review->rider_profile_id = $rider->id;
        $review->rider_rating = $rating;
        $review->rider_comment = $comment;
        $review->save();
    }

    /** @return array{average: float, count: int} */
    public function summary(RiderProfile $rider): array
    {
        $ratings = Review::query()
            ->where('rider_profile_id', $rider->id)
            ->whereNotNull('rider_rating');

        return [
            'average' => round((float) ($ratings->avg('rider_rating') ?? 0), 1),
            'count' => $ratings->count(),
        ];
    }
}