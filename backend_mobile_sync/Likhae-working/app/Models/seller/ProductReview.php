<?php

namespace App\Models\Seller;

use App\Models\Buyer\Review;

/** @deprecated Use App\Models\Buyer\Review. */
class ProductReview extends Review
{
    protected $table = 'reviews';
}
