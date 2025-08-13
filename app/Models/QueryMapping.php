<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class QueryMapping extends Model
{
    use HasFactory;
    protected $table = 'query_mapping';
    
    protected $fillable = [
        'group_name',
        'method_name',
        'status',
        'is_deleted',
    ];
}
