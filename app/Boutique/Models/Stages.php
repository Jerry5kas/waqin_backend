<?php

namespace App\Boutique\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Stages extends Model
{
    protected $connection = 'tenant';
    protected $fillable = ['name', 'type', 'status'];
}
