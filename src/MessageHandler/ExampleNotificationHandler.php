<?php

declare(strict_types=1);

namespace App\MessageHandler;

use App\Message\ExampleNotification;
use Psr\Log\LoggerInterface;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;
use Symfony\Component\Mime\Email;

/**
 * Handles ExampleNotification messages asynchronously.
 * Sends an email via the configured Mailer (Mailpit in dev).
 *
 * This handler demonstrates the full async pipeline:
 *   Controller → MessageBus → Redis Transport → Worker Container → Mailpit
 */
#[AsMessageHandler]
final readonly class ExampleNotificationHandler
{
    public function __construct(
        private MailerInterface $mailer,
        private LoggerInterface $logger,
    ) {
    }

    public function __invoke(ExampleNotification $message): void
    {
        $email = (new Email())
            ->from('noreply@symfony-docker.local')
            ->to($message->getRecipientEmail())
            ->subject($message->getSubject())
            ->text(sprintf(
                'This is an async email sent via Messenger + Mailpit. Subject: %s',
                $message->getSubject(),
            ));

        $this->mailer->send($email);

        $this->logger->info('ExampleNotification processed', [
            'recipient' => $message->getRecipientEmail(),
            'subject' => $message->getSubject(),
        ]);
    }
}
