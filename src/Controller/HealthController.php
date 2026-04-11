<?php

declare(strict_types=1);

namespace App\Controller;

use Doctrine\DBAL\Connection;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * Lightweight health endpoint for load balancers, Kubernetes probes,
 * and monitoring systems. Returns JSON with service connectivity status.
 */
class HealthController extends AbstractController
{
    #[Route('/healthz', name: 'app_health', methods: ['GET'])]
    public function __invoke(Connection $connection): JsonResponse
    {
        $status = Response::HTTP_OK;
        $checks = [
            'status' => 'ok',
            'php' => \PHP_VERSION,
        ];

        // Database check
        try {
            $connection->executeQuery('SELECT 1');
            $checks['database'] = true;
        } catch (\Throwable) {
            $checks['database'] = false;
            $checks['status'] = 'degraded';
            $status = Response::HTTP_SERVICE_UNAVAILABLE;
        }

        // Redis check
        try {
            $redisUrl = $this->getParameter('app.redis_url');
            $parts = parse_url((string) $redisUrl);
            $redis = new \Redis();
            $redis->connect($parts['host'] ?? 'redis', $parts['port'] ?? 6379, 2);

            if (isset($parts['pass'])) {
                $redis->auth($parts['pass']);
            }

            $checks['redis'] = (bool) $redis->ping();
            $redis->close();
        } catch (\Throwable) {
            $checks['redis'] = false;
            $checks['status'] = 'degraded';
            $status = Response::HTTP_SERVICE_UNAVAILABLE;
        }

        return $this->json($checks, $status);
    }
}
