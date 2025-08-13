<?php

namespace App\Jobs;

use App\Services\FCMService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendPushNotification implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected array $tokens;
    protected string $title;
    protected string $message;
    protected array $data;
    protected string $image;

    public function __construct(array $tokens, string $title, string $message, string $image = '', array $data = [])
    {
        $this->tokens = $tokens;
        $this->title = $title;
        $this->message = $message;
        $this->image = $image ?? '';
        $this->data = $data;
    }

    public function handle()
    {
        $fcmService = new FCMService();
        $success = $fcmService->sendNotification($this->tokens, $this->title, $this->message, $this->image, $this->data);

        if (!$success) {
            Log::error('SendPushNotification: FCM Notification failed.');
        }
    }
}