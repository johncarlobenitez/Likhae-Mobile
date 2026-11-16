<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Communication\Conversation;
use App\Models\Communication\Message;
use App\Models\Rider\InterhubAttendanceSession;
use App\Services\Fulfillment\InterhubTimekeepingService;
use App\Services\Marketplace\SellerPromotionBuyerService;
use App\Support\RiderVehicleType;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MobileWorkflowApiController extends Controller
{
    public function offers(Request $request, SellerPromotionBuyerService $offers): JsonResponse
    {
        $limit = min(max($request->integer('per_page', 20), 1), 50);
        $rows = $offers->forMarketplace($request->user(), $limit);

        // The marketplace service loads each offer's products and product photos.
        // Load variant photos as well for cases where a product has no main photo.
        if ($rows instanceof \Illuminate\Database\Eloquent\Collection) {
            $rows->loadMissing([
                'buyVariant.productImage',
                'rewardVariant.productImage',
                'rewardProduct.variants.productImage',
            ]);
        }

        $publicImagePath = static function (?string $path): ?string {
            if (! filled($path)) {
                return null;
            }

            if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
                return $path;
            }

            $path = ltrim($path, '/');

            return str_starts_with($path, 'storage/') ? '/'.$path : '/storage/'.$path;
        };
        $variantData = static function ($variant, bool $preferProductImage = false) use ($publicImagePath): ?array {
            if (! $variant) {
                return null;
            }

            $productImages = $variant->product?->images ?? collect();
            $primaryProductImage = $productImages->firstWhere('is_primary', true)?->file_path;
            $firstProductImage = $productImages->first()?->file_path;
            $variantImage = $variant->productImage?->file_path;
            $imagePath = collect($preferProductImage
                ? [$primaryProductImage, $firstProductImage, $variantImage]
                : [$variantImage, $primaryProductImage, $firstProductImage])
                ->first(fn ($path): bool => filled($path));
            $image = $publicImagePath($imagePath);
            $variantName = $variant->description ?: $variant->sku;

            return [
                'id' => (int) $variant->id,
                'name' => trim(($variant->product?->name ?? '').' - '.($variantName ?? '')),
                'product_name' => $variant->product?->name,
                'variant_name' => $variantName,
                'price' => number_format((float) $variant->final_price, 2, '.', ''),
                'stock' => (int) $variant->stock,
                'image' => $image,
                'product_image' => $image,
                'image_url' => $image,
                'product_image_url' => $image,
            ];
        };

        return response()->json([
            'success' => true,
            'data' => $rows->map(function ($offer) use ($variantData, $publicImagePath): array {
                $components = $offer->components
                    ->filter(fn ($component) => $component->productVariant?->is_active)
                    ->values();
                $previewComponents = $components->map(function ($component) use ($variantData): array {
                    $item = $variantData($component->productVariant);
                    $image = $item['image'] ?? null;

                    return [
                        'id' => (int) $component->id,
                        'product_variant_id' => (int) $component->product_variant_id,
                        'choice_group' => $component->choice_group,
                        'quantity' => (int) $component->quantity,
                        'product_name' => $component->productVariant?->product?->name,
                        'image' => $image,
                        'product_image' => $image,
                        'variant' => $item,
                    ];
                })->values();
                $groups = $components->groupBy(fn ($component) => filled($component->choice_group)
                    ? 'choice:'.$component->choice_group
                    : 'variant:'.$component->id);
                $usualTotal = (float) $groups->sum(function ($options): float {
                    $component = $options->first();
                    $availablePrices = $options
                        ->filter(fn ($option) => $option->productVariant
                            && (int) $option->productVariant->stock >= (int) $option->quantity)
                        ->map(fn ($option) => (float) $option->productVariant->price);

                    return (float) ($availablePrices->min() ?? 0) * max(1, (int) $component->quantity);
                });
                $bundlePrice = $offer->bundle_price === null ? null : (float) $offer->bundle_price;
                $remaining = $offer->max_redemptions === null
                    ? null
                    : max(0, (int) $offer->max_redemptions - (int) $offer->redemptions_used);

                $buyItem = $variantData($offer->buyVariant, true);
                $previewItems = [];
                if ($buyItem !== null) {
                    $previewItems[] = $buyItem + [
                        'role' => 'QUALIFYING',
                        'quantity' => (int) ($offer->buy_quantity ?? 1),
                    ];
                }

                $rewardVariants = $offer->rewardVariant
                    ? collect([$offer->rewardVariant])
                    : ($offer->rewardProduct?->variants ?? collect());
                $rewardPreviewVariant = $rewardVariants->first(
                    fn ($variant) => $variant->is_active && $variant->stock > 0,
                ) ?? $rewardVariants->first(fn ($variant) => $variant->is_active)
                    ?? $rewardVariants->first();
                $rewardItem = $variantData($rewardPreviewVariant, true);
                if ($rewardItem !== null && $offer->rewardProduct) {
                    $rewardImage = $rewardItem['image']
                        ?? $publicImagePath($offer->rewardProduct->images?->firstWhere('is_primary', true)?->file_path)
                        ?? $publicImagePath($offer->rewardProduct->images?->first()?->file_path);
                    $rewardItem['image'] = $rewardImage;
                    $rewardItem['product_image'] = $rewardImage;
                    $rewardItem['image_url'] = $rewardImage;
                    $rewardItem['product_image_url'] = $rewardImage;
                }
                if ($rewardItem !== null) {
                    $previewItems[] = $rewardItem + [
                        'role' => 'REWARD',
                        'quantity' => (int) ($offer->reward_quantity ?? 1),
                    ];
                } elseif ($offer->rewardProduct) {
                    $rewardImage = $publicImagePath($offer->rewardProduct->images?->firstWhere('is_primary', true)?->file_path)
                        ?? $publicImagePath($offer->rewardProduct->images?->first()?->file_path);
                    $previewItems[] = [
                        'id' => 'reward-product-'.$offer->rewardProduct->id,
                        'product_id' => (int) $offer->rewardProduct->id,
                        'name' => $offer->rewardProduct->name,
                        'product_name' => $offer->rewardProduct->name,
                        'image' => $rewardImage,
                        'product_image' => $rewardImage,
                        'image_url' => $rewardImage,
                        'product_image_url' => $rewardImage,
                        'role' => 'REWARD',
                        'quantity' => (int) ($offer->reward_quantity ?? 1),
                    ];
                }

                return [
                    'id' => (int) $offer->id,
                    'name' => $offer->name,
                    'type' => $offer->promotion_type,
                    'seller' => [
                        'id' => (int) $offer->sellerProfile?->id,
                        'name' => $offer->sellerProfile?->business_name,
                    ],
                    'bundle_price' => $bundlePrice,
                    'usual_total' => $usualTotal > 0 ? number_format($usualTotal, 2, '.', '') : null,
                    'savings' => $bundlePrice !== null && $usualTotal > $bundlePrice
                        ? number_format($usualTotal - $bundlePrice, 2, '.', '')
                        : null,
                    'buy_quantity' => $offer->buy_quantity === null ? null : (int) $offer->buy_quantity,
                    'reward_quantity' => $offer->reward_quantity === null ? null : (int) $offer->reward_quantity,
                    'reward_discount_percent' => $offer->reward_discount_percent === null ? null : (float) $offer->reward_discount_percent,
                    'max_redemptions' => $offer->max_redemptions === null ? null : (int) $offer->max_redemptions,
                    'redemptions_used' => (int) $offer->redemptions_used,
                    'redemptions_remaining' => $offer->buyer_redemptions_remaining ?? $remaining,
                    'max_per_buyer' => $offer->max_per_buyer === null ? null : (int) $offer->max_per_buyer,
                    'starts_at' => $offer->starts_at?->toIso8601String(),
                    'ends_at' => $offer->ends_at?->toIso8601String(),
                    'buy_item' => $buyItem,
                    'preview_items' => $previewItems,
                    'preview_components' => $previewComponents,
                    'components' => $previewComponents,
                    'rewards' => $rewardVariants
                        ->filter(fn ($variant) => $variant->is_active && $variant->stock > 0)
                        ->map(fn ($variant): ?array => $variantData($variant, true))
                        ->values(),
                ];
            })->values(),
        ])->header('Cache-Control', 'private, no-store');
    }

    public function settings(Request $request): JsonResponse
    {
        abort_unless($request->user()->riderProfile, 403);

        $defaults = [
            'theme' => 'system',
            'language' => 'en',
            'rider_notification_sounds' => true,
            'show_online_status' => true,
            'rider_ai_assistant_enabled' => true,
            'rider_ai_response_sound' => false,
            'rider_assignment_updates' => true,
            'rider_route_updates' => true,
            'rider_chat_updates' => true,
            'rider_earnings_updates' => true,
            'rider_safety_updates' => true,
        ];
        $preferences = array_merge($defaults, (array) $request->user()->notification_preferences);
        if (! is_string($preferences['language'])
            || ! array_key_exists($preferences['language'], config('app.supported_locales', ['en' => 'English']))) {
            $preferences['language'] = 'en';
        }

        return response()->json([
            'success' => true,
            'data' => ['preferences' => $preferences],
        ])->header('Cache-Control', 'private, no-store');
    }

    public function receipt(Request $request, int $conversation): JsonResponse
    {
        $thread = Conversation::query()
            ->whereKey($conversation)
            ->whereHas('participants', fn ($query) => $query
                ->where('users.id', $request->user()->id)
                ->whereNull('conversation_participants.left_at'))
            ->with([
                'participantRecords' => fn ($query) => $query->whereNull('left_at')->with('user:id,first_name,middle_initial,last_name,name_extension'),
            ])
            ->firstOrFail();
        $latestMessage = Message::query()
            ->where('conversation_id', $thread->id)
            ->orderByDesc('sent_at')
            ->orderByDesc('id')
            ->first(['id', 'conversation_id', 'sender_user_id', 'sent_at']);

        return response()->json([
            'success' => true,
            'data' => [
                'conversation_id' => (string) $thread->id,
                'latest_message_id' => $latestMessage ? (string) $latestMessage->id : null,
                'latest_message_at' => $latestMessage?->sent_at?->toIso8601String(),
                'participants' => $thread->participantRecords->map(function ($participant) use ($latestMessage): array {
                    $readAt = $participant->last_read_at;

                    return [
                        'user_id' => (string) $participant->user_id,
                        'name' => $participant->user?->name,
                        'read_at' => $readAt?->toIso8601String(),
                        'has_read_latest' => $latestMessage !== null
                            && $readAt !== null
                            && $readAt->greaterThanOrEqualTo($latestMessage->sent_at),
                    ];
                })->values(),
            ],
        ])->header('Cache-Control', 'private, no-store');
    }

    public function attendance(Request $request, InterhubTimekeepingService $timekeeping): JsonResponse
    {
        $rider = $request->user()->riderProfile;
        abort_unless($rider && RiderVehicleType::isInterLogistics($rider->vehicle_type), 403);

        $dashboard = $timekeeping->driverDashboardData($rider);
        $history = collect($dashboard['attendanceHistory'])->map(function (InterhubAttendanceSession $session): array {
            return [
                'id' => (int) $session->id,
                'clock_in_at' => $session->clock_in_at?->toIso8601String(),
                'clock_out_at' => $session->clock_out_at?->toIso8601String(),
                'worked_minutes' => $session->worked_minutes,
                'gross_pay' => $session->gross_pay === null ? null : (float) $session->gross_pay,
                'overtime_review' => (bool) $session->overtime_review,
                'manifest_number' => $session->manifest?->manifest_number,
                'daily_rate_snapshot' => $session->daily_rate_snapshot === null ? null : (float) $session->daily_rate_snapshot,
                'region_type' => $session->region_type,
                'payroll_status' => $session->payrollItem?->status,
                'payroll' => $session->payrollItem ? [
                    'id' => (int) $session->payrollItem->id,
                    'status' => $session->payrollItem->status,
                    'amount' => (float) $session->payrollItem->amount,
                    'payment_reference' => $session->payrollItem->payment_reference,
                    'proof_available' => filled($session->payrollItem->proof_path),
                    'overtime_paid_at' => $session->payrollItem->overtime_paid_at?->toIso8601String(),
                    'overtime_paid_amount' => $session->payrollItem->overtimePaidAmount(),
                    'overtime_hours_paid' => $session->payrollItem->overtimeHoursPaid(),
                    'overtime_payment_reference' => $session->payrollItem->overtime_payment_reference,
                ] : null,
                'events' => $session->events->map(fn ($event): array => [
                    'type' => $event->event_type,
                    'created_at' => $event->created_at?->toIso8601String(),
                ])->values(),
            ];
        })->values();
        $openSession = $dashboard['openSession'];

        return response()->json([
            'success' => true,
            'data' => [
                'timekeeping_ready' => $dashboard['timekeepingReady'],
                'region_type' => $dashboard['regionType'],
                'effective_daily_rate' => $dashboard['effectiveRate']?->daily_rate === null
                    ? null
                    : (float) $dashboard['effectiveRate']->daily_rate,
                'open_session' => $openSession ? [
                    'id' => (int) $openSession->id,
                    'clock_in_at' => $openSession->clock_in_at?->toIso8601String(),
                    'manifest_number' => $openSession->manifest?->manifest_number,
                ] : null,
                'current_minutes' => $dashboard['currentMinutes'],
                'estimated_current_pay' => $dashboard['estimatedCurrentPay'],
                'today' => [
                    'minutes' => $dashboard['todayMinutes'],
                    'status' => $dashboard['todayStatus'],
                    'pay_estimate' => $dashboard['todayPayEstimate'],
                ],
                'period' => [
                    'hours' => $dashboard['totalPeriodHours'] ?? 0,
                    'pay_estimate' => $dashboard['estimatedPeriodPay'] ?? 0,
                ],
                'history' => $history,
            ],
        ])->header('Cache-Control', 'private, no-store');
    }
}
