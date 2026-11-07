<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class RegistrationEmailVerificationCode extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public readonly string $code,
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(subject: 'Verify your LIKHAE email address');
    }

    public function content(): Content
    {
        return new Content(view: 'auth.emails.registration-email-verification-code');
    }
}
