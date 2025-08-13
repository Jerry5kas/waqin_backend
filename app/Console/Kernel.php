<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\DB;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    /**
     * Define the application's command schedule.
     */
    protected function schedule(Schedule $schedule): void
    {
        $jobs = DB::table('cron_jobs')->where('status', 1)->get();
    
        \Log::info("Scheduled Jobs: " . $jobs->count());
    
        foreach ($jobs as $job) {
            \Log::info("Scheduling Job ID: {$job->id} - {$job->schedule}");
    
            $schedule->command("run:scheduled-api {$job->id}")
                     ->cron($job->schedule); // Apply cron expression directly
        }
    }

    /**
     * Register the commands for the application.
     */
    protected function commands(): void
    {
        $this->load(__DIR__.'/Commands');

        require base_path('routes/console.php');
    }
}
