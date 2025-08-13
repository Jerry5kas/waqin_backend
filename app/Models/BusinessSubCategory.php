<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BusinessSubCategory extends Model
{
    protected $fillable = ['business_id', 'sub_category_name'];
    
    public function businessCategory()
    {
        return $this->belongsTo(BusinessCategory::class);
    }
}

