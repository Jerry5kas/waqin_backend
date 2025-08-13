<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Tymon\JWTAuth\Contracts\JWTSubject;

class Tenant extends Authenticatable implements JWTSubject
{
    use Notifiable;
    
    protected $table = 'tenants';
    /**
     * The attributes that are mass assignable.
     *
     * @var array
     */
    protected $fillable = [
        'image',
        'adhaar',
        'longitude',
        'refferal_code',
        'user_type',
        'latitude',
        'full_address',
        'first_name', 
        'last_name',
        'device_id',
        'mobile', 
        'mobile_verify', 
        'otp',
        'password', 
        'gender',
        'email', 
        'dob', 
        'age', 
        'business_id',
      	'sub_category_id',
        'business_description',
        'company_name', 
        'gst', 
        'pan',
        'tenant_schema',
        'fcm_token',
        'is_deleted'
        
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the identifier that will be stored in the JWT.
     *
     * @return mixed
     */
    public function getJWTIdentifier()
    {
        return $this->getKey();
    }

    /**
     * Return a key value array, containing any custom claims to be added to the JWT.
     *
     * @return array
     */
    public function getJWTCustomClaims()
    {
        return [];
    }
}

