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
        Schema::create('marketings', function (Blueprint $table) {
            $table->id();
            $table->string('business_id', 255);
            $table->string('title');
            $table->string('subtitle');
            $table->text('description');
            $table->string('image')->nullable();
            $table->text('offer_list')->nullable();
            $table->text('summary')->nullable();
            $table->string('location');
            $table->boolean('status')->default(1);
            $table->timestamps();
            $table->boolean('is_deleted')->default(0);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('marketings');
    }
};
