<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MyQrModel extends Model
{
    use HasFactory;

    protected $table = 'qr_codes'; // explicitly define table name

    protected $fillable = [
        'link',
        'qr_code_path',
    ];
}
