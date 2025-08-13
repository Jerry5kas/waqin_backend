<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up()
    {
        Schema::create('sync_requests', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('tenant_id');
            $table->string('tenant_schema');
            $table->boolean('contact')->default(0);
            $table->boolean('call_history')->default(0);
            $table->boolean('status')->default(1);
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('sync_requests');
    }
};
