<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItemDesignArea extends Model
{
    protected $fillable = [
        'order_item_id',
        'name',
        'area_price',
        'area_name',
        'area_option_id', // New field for area option ID
    ];
}
