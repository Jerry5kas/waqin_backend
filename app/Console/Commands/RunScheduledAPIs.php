<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class RunScheduledAPIs extends Command
{
    protected $signature = 'run:scheduled-api {jobId}';
    protected $description = 'Execute a scheduled API request';

    public function handle()
    {
        $jobId = $this->argument('jobId');
        $job = DB::table('cron_jobs')->where('id', $jobId)->first();

        if (!$job) {
            $this->error("Job ID {$jobId} not found.");
            return;
        }

        $url = env('APP_URL') . $job->url; // Ensure APP_URL is used
        try {
            $response = Http::get($url);
            $this->info("Executed API: {$url}, Status: " . $response->status());
        } catch (\Exception $e) {
            $this->error("Failed to execute API: {$url}, Error: " . $e->getMessage());
        }
    }
}