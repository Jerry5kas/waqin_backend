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
        Schema::create('query_builder', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('business_id')->nullable(); // Nullable business_id
            $table->string('source_name'); // Table name
            $table->string('method_name'); // Method name (e.g., GET)
            $table->json('rule'); // JSON structure for the query rules
            $table->boolean('status')->default(1); // Status of the query (active/inactive)
            $table->timestamps(); // created_at and updated_at columns
            $table->boolean('is_deleted')->default(0); // Flag for deletion status
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('query_builder');
    }
};
