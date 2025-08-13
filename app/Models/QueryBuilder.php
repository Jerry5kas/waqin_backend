<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;

class QueryBuilder extends Model
{
    use HasFactory;

    protected $table = 'query_builder';

    protected $fillable = [
        'business_id',
        'source_name',
        'method_name',
        'selected_columns',
        'target',
        'rule',
        'status',
        'is_deleted'
    ];

}
