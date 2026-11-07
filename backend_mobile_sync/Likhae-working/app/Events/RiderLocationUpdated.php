<?php

namespace App\Events;

use App\Models\Rider\RiderAssignmentLocation;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RiderLocationUpdated implements ShouldBroadcast
{
    use Dispatchable, SerializesModels;

    // Do not make the Rider GPS HTTP request wait on a Reverb connection.
    public string $connection = 'background';

    public function __construct(public RiderAssignmentLocation $location)
    {
        $this->location->loadMissing('riderAssignment.shipment');
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel('shipments.'.($this->location->riderAssignment?->shipment_id ?? 'unknown'))];
    }

    public function broadcastAs(): string
    {
        return 'rider.location.updated';
    }

    public function broadcastWith(): array
    {
        $assignment = $this->location->riderAssignment;
        $shipment = $assignment?->shipment;

        return [
            'shipment_id' => $shipment?->id,
            'assignment_id' => $assignment?->id,
            'assignment_type' => $assignment?->assignment_type,
            'assignment_status' => $assignment?->status,
            'current_status' => $shipment?->current_status,
            'latitude' => (float) $this->location->latitude,
            'longitude' => (float) $this->location->longitude,
            'recorded_at' => $this->location->recorded_at?->toIso8601String(),
        ];
    }
}
