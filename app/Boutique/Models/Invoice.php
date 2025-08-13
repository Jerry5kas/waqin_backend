<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Model;
use App\Models\Customer;
use App\Boutique\Models\OrderItem;

class Invoice extends Model
{

    protected $connection = 'tenant'; // <-- Add this line!


    protected $fillable = [
        'order_id',
        'invoice_no',
        'created_by',
    ];

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
}
