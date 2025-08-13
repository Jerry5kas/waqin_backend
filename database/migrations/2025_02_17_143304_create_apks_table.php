<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('apks', function (Blueprint $table) {
            $table->id();
            $table->string('version');
            $table->string('type');
            $table->string('file_path')->nullable();
            $table->text('message');
            $table->boolean('force_update')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('apks');
    }
};
