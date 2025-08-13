<?php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

class ChannelPartner extends Authenticatable implements JWTSubject
{
    use HasFactory, Notifiable;

    protected $table = 'channel_partners';

    protected $fillable = [
    'full_name',
    'email', 
    'mobile', 
    'password', 
    'status', 
    'is_deleted',
    'created_by',
    'cp_id',
    'is_strategic_cp',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    public function getJWTCustomClaims()
    {
        return [];
    }
}
