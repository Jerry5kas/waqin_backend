<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Marketing extends Model
{
    use HasFactory;

    protected $table = 'marketings'; // Specify table name if different

    protected $fillable = [
        'title',
        'subtitle',
        'description',
        'image',
        'offer_list',
        'summery',
        'location',
        'status',
        'is_deleted',
        'business_id',
    ];

    public function business()
    {
        return $this->belongsTo(BusinessCategory::class, 'business_id');
    }
}
