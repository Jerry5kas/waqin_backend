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
        Schema::create('transaction_history', function (Blueprint $table) {
            $table->id();
            $table->uuid('transaction_id')->unique();
            $table->string('tenant_schema');
            $table->string('name');
            $table->string('mobile_number');
            $table->unsignedBigInteger('package_id');
            $table->unsignedBigInteger('duration_id');
            $table->integer('amount');
            $table->string('payment_status')->default('INITIATED'); 
            $table->integer('status')->default(1); 
            $table->json('payload');
            $table->json('gateway_response')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('transaction_history');
    }
};
