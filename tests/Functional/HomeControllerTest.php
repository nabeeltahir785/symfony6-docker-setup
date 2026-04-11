<?php

declare(strict_types=1);

namespace App\Tests\Functional;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class HomeControllerTest extends WebTestCase
{
    public function testHomepageReturnsSuccessfully(): void
    {
        $client = static::createClient();
        $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorTextContains('h1', 'Symfony Docker');
    }

    public function testHomepageDisplaysPhpVersion(): void
    {
        $client = static::createClient();
        $crawler = $client->request('GET', '/');

        self::assertResponseIsSuccessful();
        self::assertSelectorExists('.info-card');
        self::assertStringContainsString(\PHP_MAJOR_VERSION . '.' . \PHP_MINOR_VERSION, $crawler->filter('.info-card .value')->first()->text());
    }
}
