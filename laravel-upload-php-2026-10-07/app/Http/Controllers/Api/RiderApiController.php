<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Communication\Conversation;
use App\Models\Rider\RiderAssignment;
use App\Models\Rider\RiderEarning;
use App\Models\Rider\RiderProfile;
use App\Models\User;
use App\Services\Communication\ConversationService;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class RiderApiController extends Controller
{
    public function dashboard(Request $request): JsonResponse
    {
        $rider = $this->rider($request);
        $assignments = RiderAssignment::query()->where('rider_profile_id', $rider->id);
        $deliveries = (clone $assignments)->delivery();

        $stats = [
            ['label' => 'Assigned Parcels', 'value' => (clone $deliveries)->whereIn('status', ['ASSIGNED', 'ACCEPTED'])->count()],
            ['label' => 'In Transit', 'value' => (clone $deliveries)->where('status', 'IN_PROGRESS')->count()],
            ['label' => 'Out for Delivery', 'value' => (clone $deliveries)->where('status', 'IN_PROGRESS')->whereHas('shipment', fn ($query) => $query->where('current_status', 'OUT_FOR_DELIVERY'))->count()],
            ['label' => 'Completed Today', 'value' => (clone $deliveries)->where('status', 'COMPLETED')->whereDate('completed_at', today())->count()],
        ];

        $recent = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->delivery()
            ->with($this->assignmentRelations())
            ->latest()
            ->limit(8)
            ->get()
            ->map(fn (RiderAssignment $assignment): array => $this->assignmentPayload($assignment))
            ->values();

        return response()->json([
            'success' => true,
            'data' => ['stats' => $stats, 'recent_parcels' => $recent],
        ]);
    }

    public function assignments(Request $request): JsonResponse
    {
        $rider = $this->rider($request);
        $query = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->delivery()
            ->whereIn('status', ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'])
            ->with($this->assignmentRelations())
            ->latest();
        $rows = $query->paginate($this->perPage($request));

        $statsQuery = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->delivery();
        $stats = [
            'assigned' => (clone $statsQuery)->whereIn('status', ['ASSIGNED', 'ACCEPTED'])->count(),
            'out_for_delivery' => (clone $statsQuery)->where('status', 'IN_PROGRESS')->whereHas('shipment', fn ($builder) => $builder->where('current_status', 'OUT_FOR_DELIVERY'))->count(),
            'delivered_today' => (clone $statsQuery)->where('status', 'COMPLETED')->whereDate('completed_at', today())->count(),
            'failed_today' => (clone $statsQuery)->whereHas('deliveryAttempts', fn ($builder) => $builder->whereDate('attempted_at', today())->whereIn('status', ['FAILED', 'RESCHEDULED', 'RETURNED']))->count(),
        ];

        return $this->paginated($rows, fn (RiderAssignment $assignment): array => $this->assignmentPayload($assignment), ['stats' => $stats]);
    }

    public function pickups(Request $request): JsonResponse
    {
        $rider = $this->rider($request);
        $query = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->pickup()
            ->whereIn('status', ['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS'])
            ->with($this->assignmentRelations())
            ->latest();
        $rows = $query->paginate($this->perPage($request));

        $statsQuery = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->pickup();
        $stats = [
            'ready' => (clone $statsQuery)->where('status', 'ASSIGNED')->count(),
            'accepted' => (clone $statsQuery)->whereIn('status', ['ACCEPTED', 'IN_PROGRESS'])->count(),
            'picked_up' => (clone $statsQuery)->where('status', 'COMPLETED')->whereDate('completed_at', today())->count(),
        ];

        return $this->paginated($rows, fn (RiderAssignment $assignment): array => $this->assignmentPayload($assignment), ['stats' => $stats]);
    }

    public function verifyPickup(Request $request, RiderAssignment $assignment): JsonResponse
    {
        $this->assertAssignment($request, $assignment, RiderAssignment::TYPE_PICKUP);
        $data = $request->validate(['tracking_code' => ['required', 'string', 'max:150']]);
        $expected = (string) $assignment->shipment?->tracking_number;
        $verified = $expected !== '' && hash_equals($expected, trim($data['tracking_code']));

        return response()->json([
            'success' => true,
            'data' => ['verified' => $verified],
        ]);
    }

    public function updateLocation(Request $request, RiderAssignment $assignment): JsonResponse
    {
        $this->assertAssignment($request, $assignment, RiderAssignment::TYPE_DELIVERY);
        abort_unless(
            $assignment->status === 'IN_PROGRESS'
                && $assignment->shipment?->current_status === 'OUT_FOR_DELIVERY',
            409,
            'Live location is only accepted during an active delivery.',
        );

        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);
        $location = $assignment->liveLocation()->updateOrCreate([], [
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'recorded_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'latitude' => $location->latitude,
                'longitude' => $location->longitude,
                'recorded_at' => $location->recorded_at?->toIso8601String(),
            ],
        ]);
    }

    public function history(Request $request): JsonResponse
    {
        $rider = $this->rider($request);
        $rows = RiderAssignment::query()
            ->where('rider_profile_id', $rider->id)
            ->where(function ($query): void {
                $query->whereIn('status', ['COMPLETED', 'REJECTED', 'CANCELLED'])
                    ->orWhereHas('deliveryAttempts');
            })
            ->with($this->assignmentRelations())
            ->latest()
            ->paginate($this->perPage($request));

        return $this->paginated($rows, function (RiderAssignment $assignment): array {
            $attempt = $assignment->deliveryAttempts->sortByDesc('attempt_number')->first();
            $shipment = $assignment->shipment;
            $buyer = $shipment?->sellerOrder?->order?->address?->recipient_name
                ?? $shipment?->sellerOrder?->order?->buyer?->name
                ?? 'Buyer unavailable';

            return [
                'id' => $assignment->id,
                'tracking' => $shipment?->tracking_number ?? 'Tracking unavailable',
                'buyer' => $buyer,
                'status' => $attempt?->status ?? $shipment?->current_status ?? $assignment->status,
                'status_label' => str($attempt?->status ?? $shipment?->current_status ?? $assignment->status)->headline()->toString(),
                'updated_at' => ($attempt?->attempted_at ?? $assignment->completed_at ?? $assignment->updated_at)?->toIso8601String(),
                'failure_reason' => $attempt?->failure_reason,
                'image_url' => $this->assignmentImage($assignment),
            ];
        });
    }

    public function earnings(Request $request): JsonResponse
    {
        $rider = $this->rider($request);
        $rows = $rider->earnings()->with('riderAssignment.shipment')->latest()->paginate($this->perPage($request));

        return $this->paginated($rows, fn (RiderEarning $earning): array => [
            'date' => $earning->earned_at?->format('M d, Y') ?? $earning->created_at?->format('M d, Y') ?? 'Date unavailable',
            'reference' => $earning->riderAssignment?->shipment?->tracking_number ?? 'Assignment #'.$earning->rider_assignment_id,
            'amount' => (float) $earning->amount,
            'status' => str($earning->status)->headline()->toString(),
        ], [
            'total' => (float) $rider->earnings()->sum('amount'),
            'notice' => 'Recorded earnings from completed pickup and delivery assignments.',
        ]);
    }

    public function profile(Request $request): JsonResponse
    {
        $rider = $this->rider($request)->load(['user', 'logisticsCenter', 'areaAssignments.serviceArea']);
        $user = $rider->user;

        return response()->json([
            'success' => true,
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'first_name' => $user->first_name,
                    'middle_initial' => $user->middle_initial,
                    'last_name' => $user->last_name,
                    'email' => $user->email,
                    'contact_number' => $user->contact_number,
                    'birthday' => $user->birthday?->toDateString(),
                    'sex' => $user->sex,
                    'status' => $user->status,
                    'account_type' => $user->account_type,
                    'profile_photo_url' => $user->profile_photo_path ? Storage::disk('public')->url($user->profile_photo_path) : null,
                ],
                'rider' => [
                    'id' => $rider->id,
                    'user_id' => $rider->user_id,
                    'vehicle_type' => $rider->vehicle_type,
                    'plate_number' => $rider->plate_number,
                    'status' => $rider->status,
                    'primary_role' => 'Rider',
                    'logistics_center' => $rider->logisticsCenter?->business_name,
                    'service_areas' => $rider->areaAssignments->where('is_active', true)->pluck('serviceArea.name')->filter()->values(),
                ],
            ],
        ]);
    }

    public function notifications(Request $request): JsonResponse
    {
        $this->rider($request);
        $rows = $request->user()->notifications()->latest()->paginate(
            min(max($request->integer('per_page', 20), 1), 50),
        );

        return response()->json([
            'success' => true,
            'data' => $rows->getCollection()->map(fn ($notification): array => [
                'id' => $notification->id,
                'type' => $notification->type,
                'title' => $notification->title,
                'message' => $notification->message,
                'action_url' => $notification->action_url,
                'reference_type' => $notification->reference_type,
                'reference_id' => $notification->reference_id,
                'read_at' => $notification->read_at?->toIso8601String(),
                'created_at' => $notification->created_at?->toIso8601String(),
            ])->values(),
            'unread_count' => $request->user()->notifications()->whereNull('read_at')->count(),
            'meta' => [
                'current_page' => $rows->currentPage(),
                'last_page' => $rows->lastPage(),
                'total' => $rows->total(),
            ],
        ]);
    }

    public function markNotificationsRead(Request $request): JsonResponse
    {
        $this->rider($request);
        $request->user()->notifications()->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(['success' => true]);
    }

    public function conversations(Request $request, ConversationService $service): JsonResponse
    {
        $this->rider($request);
        $user = $request->user();
        $rows = $service->listFor($user)->map(function (Conversation $conversation) use ($user): array {
            $other = $conversation->participants->first(
                fn (User $participant): bool => (int) $participant->id !== (int) $user->id,
            );
            $self = $conversation->participants->first(
                fn (User $participant): bool => (int) $participant->id === (int) $user->id,
            );
            $lastReadAt = $self?->pivot?->last_read_at;
            $unread = $conversation->messages
                ->where('sender_user_id', '!=', $user->id)
                ->filter(fn ($message): bool => $lastReadAt === null || $message->sent_at?->gt($lastReadAt))
                ->count();
            $shipment = $conversation->shipment;

            return [
                'id' => (string) $conversation->id,
                'conversation_id' => (string) $conversation->id,
                'buyer_id' => (string) ($other?->id ?? ''),
                'buyer_name' => $other?->name ?? 'LIKHAE User',
                'order_id' => $conversation->order?->order_number,
                'tracking_code' => $shipment?->tracking_number,
                'last_message' => $conversation->latestMessage?->body ?? '',
                'last_message_at' => $conversation->latestMessage?->sent_at?->toIso8601String(),
                'unread_count' => $unread,
            ];
        })->values();

        return response()->json(['success' => true, 'data' => $rows]);
    }

    public function conversationMessages(Request $request, int $conversation): JsonResponse
    {
        $this->rider($request);
        $thread = Conversation::query()
            ->whereKey($conversation)
            ->whereHas('participants', fn ($query) => $query->where('users.id', $request->user()->id))
            ->with(['messages.sender', 'participantRecords'])
            ->firstOrFail();
        app(ConversationService::class)->markRead($thread, $request->user());

        return response()->json([
            'success' => true,
            'data' => $thread->messages->map(fn ($message): array => [
                'id' => (string) $message->id,
                'conversation_id' => (string) $message->conversation_id,
                'body' => $message->body,
                'sender_user_id' => $message->sender_user_id,
                'sent_at' => $message->sent_at?->toIso8601String(),
                'from_rider' => (int) $message->sender_user_id === (int) $request->user()->id,
            ])->values(),
        ]);
    }

    public function sendMessage(Request $request, ConversationService $service): JsonResponse
    {
        $this->rider($request);
        $data = $request->validate([
            'conversation_id' => ['required', 'integer'],
            'body' => ['required', 'string', 'max:2000'],
        ]);
        $thread = Conversation::query()
            ->whereKey($data['conversation_id'])
            ->whereHas('participants', fn ($query) => $query->where('users.id', $request->user()->id))
            ->with(['participants', 'shipment'])
            ->firstOrFail();
        $recipient = $thread->participants->first(
            fn (User $participant): bool => (int) $participant->id !== (int) $request->user()->id,
        );
        abort_unless($recipient, 409, 'The conversation has no other participant.');

        $message = $service->send($request->user(), (int) $recipient->id, trim($data['body']), [
            'type' => $thread->type,
            'order_id' => $thread->order_id,
            'seller_order_id' => $thread->seller_order_id,
            'shipment_id' => $thread->shipment_id,
        ]);

        return response()->json([
            'success' => true,
            'data' => [
                'id' => (string) $message->id,
                'conversation_id' => (string) $message->conversation_id,
                'body' => $message->body,
                'sent_at' => $message->sent_at?->toIso8601String(),
                'from_rider' => true,
            ],
        ], 201);
    }

    private function rider(Request $request): RiderProfile
    {
        abort_unless($request->user()?->isAccountType(User::TYPE_RIDER), 403, 'Rider access is required.');
        $rider = $request->user()->riderProfile;
        abort_unless($rider, 403, 'A rider profile is required.');

        return $rider;
    }

    private function assertAssignment(Request $request, RiderAssignment $assignment, string $type): void
    {
        $rider = $this->rider($request);
        abort_unless(
            (int) $assignment->rider_profile_id === (int) $rider->id
                && $assignment->assignment_type === $type,
            403,
            'This assignment does not belong to the rider.',
        );
    }

    private function assignmentRelations(): array
    {
        return [
            'shipment.sellerOrder.items.product.images',
            'shipment.sellerOrder.order.address',
            'shipment.sellerOrder.order.buyer',
            'shipment.sellerOrder.sellerProfile.user',
            'shipment.sellerOrder.sellerProfile.businessAddress',
            'shipment.deliveryAttempts',
        ];
    }

    private function assignmentPayload(RiderAssignment $assignment): array
    {
        $shipment = $assignment->shipment;
        $sellerOrder = $shipment?->sellerOrder;
        $order = $sellerOrder?->order;
        $address = $order?->address;
        $current = strtolower((string) $shipment?->current_status);
        $status = match ($assignment->status) {
            'ASSIGNED' => 'assigned',
            'ACCEPTED' => 'accepted',
            'IN_PROGRESS' => $assignment->assignment_type === RiderAssignment::TYPE_PICKUP
                ? 'accepted'
                : ($current === 'out_for_delivery' ? 'out_for_delivery' : 'in_transit'),
            'COMPLETED' => $assignment->assignment_type === RiderAssignment::TYPE_PICKUP
                ? 'picked_up'
                : 'delivered',
            default => strtolower((string) ($shipment?->current_status ?? $assignment->status)),
        };
        $latestAttempt = $assignment->deliveryAttempts->sortByDesc('attempt_number')->first();
        if ($latestAttempt && in_array($latestAttempt->status, ['FAILED', 'RESCHEDULED', 'RETURNED'], true)) {
            $status = strtolower($latestAttempt->status === 'RESCHEDULED' ? 'accepted' : 'delivery_failed');
        }

        return [
            'id' => $assignment->id,
            'assignment_type' => $assignment->assignment_type,
            'tracking' => $shipment?->tracking_number ?? '',
            'buyer_name' => $address?->recipient_name ?? $order?->buyer?->name ?? 'Buyer unavailable',
            'buyer_contact' => $address?->contact_number ?? $order?->buyer?->contact_number ?? 'Not available',
            'seller_name' => $sellerOrder?->sellerProfile?->business_name ?? 'Seller unavailable',
            'address' => $assignment->assignment_type === RiderAssignment::TYPE_PICKUP
                ? ($sellerOrder?->sellerProfile?->businessAddress?->formatted() ?? $address?->formatted() ?? '')
                : ($address?->formatted() ?? ''),
            'amount' => (float) ($sellerOrder?->grand_total ?? 0),
            'items' => (int) ($sellerOrder?->items?->sum('quantity') ?? 0),
            'status' => $status,
            'status_label' => str($status)->replace('_', ' ')->headline()->toString(),
            'image_url' => $this->assignmentImage($assignment),
            'failure_reason' => $latestAttempt?->failure_reason,
            'delivery_latitude' => null,
            'delivery_longitude' => null,
        ];
    }

    private function assignmentImage(RiderAssignment $assignment): ?string
    {
        $images = $assignment->shipment?->sellerOrder?->items?->first()?->product?->images ?? collect();
        $path = $images->firstWhere('is_primary', true)?->file_path ?? $images->first()?->file_path;

        return $path ? Storage::url($path) : null;
    }

    private function perPage(Request $request): int
    {
        return min(max($request->integer('per_page', 20), 1), 100);
    }

    private function paginated(LengthAwarePaginator $paginator, callable $transform, array $extra = []): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => [
                'items' => $paginator->getCollection()->map($transform)->values(),
                ...$extra,
            ],
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'per_page' => $paginator->perPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }
}
