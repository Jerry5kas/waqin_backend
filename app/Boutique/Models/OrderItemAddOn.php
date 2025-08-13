<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Model;

class OrderItemAddOn extends Model
{
    protected $fillable = [
        'order_item_id',
        'name',
        'price',
    ];
}
