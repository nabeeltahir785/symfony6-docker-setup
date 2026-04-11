<?php

declare(strict_types=1);

namespace App\Tests\Unit\Message;

use App\Message\ExampleNotification;
use PHPUnit\Framework\TestCase;

class ExampleNotificationTest extends TestCase
{
    public function testMessageHoldsData(): void
    {
        $message = new ExampleNotification('test@example.com', 'Hello World');

        self::assertSame('test@example.com', $message->getRecipientEmail());
        self::assertSame('Hello World', $message->getSubject());
    }
}
