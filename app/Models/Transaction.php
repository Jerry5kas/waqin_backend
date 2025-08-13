<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;
    protected $table = 'transaction_history';
    protected $fillable = [
        'transaction_id', 'tenant_schema', 'name', 'mobile_number',
        'package_id', 'duration_id', 'amount', 'payment_status',
        'payload', 'gateway_response', 'status', 'created_at', 'updated_at', 'phonepe_transaction_id', 'order_id', 'duration'
        ];

    protected $casts = [
        'payload' => 'array',
        'gateway_response' => 'array',
        ];
}


