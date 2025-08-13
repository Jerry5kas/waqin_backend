<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Status extends Model
{
    protected $connection = 'tenant';
    protected $fillable = ['name'];
}
