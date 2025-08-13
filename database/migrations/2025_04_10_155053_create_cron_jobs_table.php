<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('cron_jobs', function (Blueprint $table) {
            $table->id();
            $table->string('name'); // API Name
            $table->string('url'); // API Endpoint URL
            $table->string('schedule'); // Cron schedule (e.g., "everyFiveMinutes", "dailyAt:08:00")
            $table->boolean('status')->default(1); // 1 = Active, 0 = Inactive
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('cron_jobs');
    }
};
