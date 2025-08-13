<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Model;
use App\Boutique\Models\OrderItemDesignArea;
use App\Boutique\Models\OrderItemAddOn;

class OrderItem extends Model
{
    protected $fillable = [
        'order_id',
        'item_id',
        'to_whom',
        'pattern',
        'measurements',
        'quantity',
        'total_price',
        'employee_id',
        'note'
    ];

    protected $casts = [
        'measurements' => 'array'
    ];

    public function designAreas()
    {
        return $this->hasMany(OrderItemDesignArea::class);
    }

    public function addOns()
    {
        return $this->hasMany(OrderItemAddOn::class);
    }
}
