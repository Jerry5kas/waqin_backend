<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateOrdersModuleTables extends Migration
{
    public function up()
    {
        // Orders Table
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_no')->unique()->nullable();
            $table->string('order_type');
            $table->unsignedBigInteger('customer_id');
            $table->dateTime('delivery_time');
            $table->unsignedBigInteger('employee_id')->nullable();
            $table->dateTime('function_date')->nullable();
            $table->dateTime('trial_date')->nullable();
            $table->string('urgent_status')->nullable();
            $table->integer('quantity');
            $table->decimal('subtotal', 10, 2);
            $table->decimal('discount', 10, 2)->default(0);
            $table->decimal('final_total', 10, 2);
            $table->string('stage')->nullable();
            $table->string('status')->default('Pending');
            $table->unsignedBigInteger('created_by')->nullable();
            $table->unsignedBigInteger('updated_by')->nullable();
            $table->timestamps();
        });

        // Order Items Table
        Schema::create('order_items', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('order_id');
            $table->unsignedBigInteger('item_id');
            $table->string('to_whom')->nullable();
            $table->unsignedBigInteger('pattern_id')->nullable();
            $table->json('pattern')->nullable();
            $table->json('measurements')->nullable();
            $table->integer('quantity')->default(1);
            $table->decimal('total_price', 10, 2);
            $table->unsignedBigInteger('employee_id')->nullable();
            $table->text('note')->nullable();
            $table->timestamps();

            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
            
        });

        // Order Item Design Areas
        Schema::create('order_item_design_areas', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('order_item_id');
            $table->string('name');
            $table->decimal('area_price', 10, 2);
            $table->string('area_name');
            $table->unsignedBigInteger('area_option_id');
            $table->timestamps();

            $table->foreign('order_item_id')->references('id')->on('order_items')->onDelete('cascade');
        });

        // Order Item Add-ons
        Schema::create('order_item_add_ons', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('order_item_id');
            $table->string('name');
            $table->decimal('price', 10, 2);
            $table->timestamps();

            $table->foreign('order_item_id')->references('id')->on('order_items')->onDelete('cascade');
        });

        // Employees Orders Table
        Schema::create('employees_orders', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('emp_id');
            $table->unsignedBigInteger('order_id');
            $table->unsignedBigInteger('item_id')->nullable();
            $table->string('stage')->default('cutting');
            $table->string('status')->default('0');
            $table->decimal('priceCommision', 10, 2)->nullable();
            $table->timestamp('created_at')->useCurrent();
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        Schema::table('employees_orders', function (Blueprint $table) {
            $table->foreign('emp_id')->references('id')->on('employees')->onDelete('cascade');
            $table->foreign('order_id')->references('id')->on('orders')->onDelete('cascade');
            $table->foreign('item_id')->references('id')->on('order_items')->onDelete('set null');
        });
    }

    public function down()
    {
        Schema::dropIfExists('employees_orders');
        Schema::dropIfExists('order_item_add_ons');
        Schema::dropIfExists('order_item_design_areas');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
    }
}
