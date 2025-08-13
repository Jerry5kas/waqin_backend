<?php

namespace App\Services;

use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\Middleware\AuthTokenMiddleware;
use Google\Auth\OAuth2;
use Google\Client;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FCMService
{
    private function getAccessToken()
    {
        $credentialsPath = base_path(env('FIREBASE_CREDENTIALS'));

        $client = new Client();
        $client->setAuthConfig($credentialsPath);
        $client->setScopes(['https://www.googleapis.com/auth/firebase.messaging']);
        $client->refreshTokenWithAssertion();
        return $client->getAccessToken()['access_token'];
    }

    public function sendNotification(array $tokens, string $title, string $message, string $image = '', array $data = [])
    {
        if (empty($tokens)) {
            Log::error('FCMService: No FCM tokens provided.');
            return false;
        }

        $accessToken = $this->getAccessToken();
        $projectId = env('FIREBASE_PROJECT_ID');
        $url = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

        foreach ($tokens as $token) {
            $payload = [
                'message' => [
                    'token' => $token,
                    'notification' => [
                        'title' => $title,
                        'body'  => $message,
                        'image' => $image,
                    ],
                    'data' => array_merge($data, ['click_action' => $data['route'] ?? '']) // Ensure route is included
                ]
            ];
    
            $response = Http::withToken($accessToken)
                ->withHeaders(['Content-Type' => 'application/json'])
                ->post($url, $payload);
    
            Log::info("FCM Response for token {$token}: " . $response);
        }

        return true;
    }
}