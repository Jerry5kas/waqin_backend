<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Apk extends Model
{
    use HasFactory;

    protected $fillable = ['version', 'type', 'message', 'force_update', 'file_path', 'download_password', 'status'];
}
