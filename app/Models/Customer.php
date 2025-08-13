<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Customer extends Model
{
    use HasFactory;
    protected $fillable = [
        'phone_account_id',
        'name',
        'email',
        'mobile',
        'another_mobile',
        'company',
        'gst',
        'profile_pic',
        'location',
        'group',
        'dob',
        'status',
        'contact_status',
        'created_at',
        'updated_at',
        'is_deleted',
    ];
}
