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
        Schema::create('status', function (Blueprint $table) {
            $table->id();
            $table->foreignId('business_id')->constrained('business_categories')->onDelete('cascade');
            $table->string('name');
            $table->tinyInteger('status')->default(1);
            $table->timestamps(); 
            $table->boolean('is_deleted')->default(0);
        });
    }

    public function down()
    {
        Schema::dropIfExists('status');
    }
};
