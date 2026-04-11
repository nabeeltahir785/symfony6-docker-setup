<?php

declare(strict_types=1);

namespace App\Message;

/**
 * Example async message. Dispatched to the 'async' transport and processed
 * by the Messenger worker container.
 *
 * Usage:
 *   $bus->dispatch(new ExampleNotification('user@example.com', 'Hello!'));
 */
final readonly class ExampleNotification
{
    public function __construct(
        private string $recipientEmail,
        private string $subject,
    ) {
    }

    public function getRecipientEmail(): string
    {
        return $this->recipientEmail;
    }

    public function getSubject(): string
    {
        return $this->subject;
    }
}
