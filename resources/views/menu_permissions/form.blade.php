@extends('layouts.superadmin')
@section('content')

<style>
    /* Floating Save Button */
    .floating-save-btn {
        position: fixed;
        bottom: 60px;
        right: 16px;
        z-index: 9999;
    }
</style>

<div class="container">
    <div class="pagetitle">
        <h1>Edit Permissions for {{ $user->name }}</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item"><a href="{{ route('menu-permissions.index') }}">Users</a></li>
                <li class="breadcrumb-item active">Edit Permissions</li>
            </ol>
        </nav>
    </div>

    <div class="row"> 
        <div class="col-12">
            <div class="dashboard">
                <div class="card recent-sales overflow-auto">
                    <div class="card-body">
                        <h5 class="card-title">Manage Menu Permissions</h5>

                        <form id="permissions-form" action="{{ route('menu-permissions.update', $user->id) }}" method="POST">
                            @csrf
                            @method('PUT')

                            @foreach($menus as $menu => $submenus)
                                <div class="mb-4 border-bottom pb-2">
                                    <h6 class="text-primary fw-bold">{{ $menu }}</h6>

                                    <div class="row">
                                        @if(is_array($submenus))
                                            @foreach($submenus as $submenu => $value)
                                                <div class="col-md-3 mb-2">
                                                    <div class="form-check">
                                                        <input class="form-check-input" type="checkbox"
                                                               name="permissions[{{ $menu }}][{{ $submenu }}]"
                                                               id="{{ $menu . '_' . $submenu }}"
                                                               {{ $permissions[$menu][$submenu] ?? false ? 'checked' : '' }}>
                                                        <label class="form-check-label" for="{{ $menu . '_' . $submenu }}">
                                                            {{ $submenu }}
                                                        </label>
                                                    </div>
                                                </div>
                                            @endforeach
                                        @else
                                            <div class="col-md-3 mb-2">
                                                <div class="form-check">
                                                    <input class="form-check-input" type="checkbox"
                                                           name="permissions[{{ $menu }}]"
                                                           id="{{ $menu }}"
                                                           {{ $permissions[$menu] ?? false ? 'checked' : '' }}>
                                                    <label class="form-check-label" for="{{ $menu }}">
                                                        {{ $menu }}
                                                    </label>
                                                </div>
                                            </div>
                                        @endif
                                    </div>
                                </div>
                            @endforeach
                        </form>

                    </div>
                </div>
            </div>
        </div>
    </div>  
</div>

<!-- Floating Save Button -->
<button type="submit" form="permissions-form" class="btn btn-success floating-save-btn">
    💾 Save Permissions
</button>

@endsection
