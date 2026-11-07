<?php

namespace App\Notifications;

use App\Models\Auth\RegistrationApplication;
use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

class RegistrationDecisionNotification extends Notification
{
    use Queueable;

    public function __construct(
        public RegistrationApplication $application,
    ) {
    }

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $approved = $this->application->status === RegistrationApplication::STATUS_APPROVED;
        $type = strtoupper((string) $this->application->user?->account_type);
        $label = match ($type) {
            User::TYPE_SELLER => 'Seller',
            User::TYPE_LOGISTICS => 'Logistics',
            User::TYPE_RIDER => 'Rider',
            default => 'Buyer',
        };

        $loginRoute = in_array($type, [User::TYPE_LOGISTICS, User::TYPE_RIDER], true)
            ? 'logistics.login'
            : 'login';

        $mail = (new MailMessage)
            ->subject('LIKHAE '.$label.' Registration '.($approved ? 'Approved' : 'Decision'))
            ->greeting('Hello '.$notifiable->first_name.',');

        if ($approved) {
            return $mail
                ->line('Your '.$label.' registration has been approved.')
                ->line('Your LIKHAE account is now active.')
                ->action('Sign in to LIKHAE', route($loginRoute));
        }

        return $mail
            ->line('Your '.$label.' registration was not approved.')
            ->line($this->application->rejection_reason ?: 'Please contact LIKHAE support if you need more information.')
            ->action('Return to LIKHAE', route($loginRoute));
    }

    public function toArray(object $notifiable): array
    {
        return [
            'application_id' => $this->application->id,
            'status' => $this->application->status,
        ];
    }
}
