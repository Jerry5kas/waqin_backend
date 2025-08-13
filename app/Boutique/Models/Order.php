<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Customer;
use App\Boutique\Models\OrderItem;

class Order extends Model
{
    protected $fillable = [
        'order_type',
        'customer_id',
        'order_no',
        'delivery_time',
        'employee_id',
        'function_date',
        'trial_date',
        'urgent_status',
        'quantity',
        'subtotal',
        'discount',
        'final_total',
        'status',
        'stage',
        'created_by',
        'updated_by'
    ];

//    protected $connection = 'tenant'; // or dynamically set via QueryHelper
    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
}
