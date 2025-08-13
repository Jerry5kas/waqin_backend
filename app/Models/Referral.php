<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Referral extends Model
{
    use HasFactory;
    protected $fillable = [
        'cust_name',
        'cust_mobile',
        'cust_email',
        'referral_code',
        'partner_id',
    ];

    public function tenant()
{
    return $this->belongsTo(Tenant::class);
}

}
