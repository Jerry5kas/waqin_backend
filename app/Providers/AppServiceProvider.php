<?php

namespace App\Providers;
use Illuminate\Support\Facades\URL;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\View;
use Illuminate\Support\Facades\Auth;
use App\Models\MenuPermission;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        if (env('APP_ENV') === 'production') {
            URL::forceScheme('https');
        } 

        View::composer('*', function ($view) {
            $permissions = [];
    
            if (Auth::check() && Auth::user()->role != 2) {
                $menuPermission = MenuPermission::where('user_id', Auth::id())->first();
                $permissions = $menuPermission ? $menuPermission->permissions : [];
            }
    
            $view->with('menuPermissions', $permissions);
        });
    }
}

