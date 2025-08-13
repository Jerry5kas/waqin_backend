@extends('layouts.app')
@section('content')
<div class="container-fluid">
    <div class="row justify-content-center">
        <div class="col-lg-4 col-12 d-flex flex-column align-items-center justify-content-center">
             <div class="d-flex justify-content-center py-2">
                    <img style="width:12rem;" src="{{ asset('img/logo.png')}}" alt="">
            </div>
            <div class="card bg-white">
                <div class="card-body">
                    <div class="pb-2">
                        <h5 class="card-title text-center pb-0 fs-4">Add User</h5>
                        <p class="text-center small">Enter User Details</p>
                    </div>
                    <form method="POST" class="row g-1 needs-validation" action="{{ route('register') }}">
                        @csrf
                        <div class="col-12">
                            <label for="yourUsername" class="form-label">{{ __('Name') }}</label>
                            <input id="name" type="text" class="form-control @error('name') is-invalid @enderror" name="name" value="{{ old('name') }}" required autocomplete="name" autofocus>
                            @error('name')
                            <span class="invalid-feedback" role="alert">
                                <strong>{{ $message }}</strong>
                            </span>
                            @enderror
                        </div>
                        <div class="col-12">
                            <label for="yourUsername" class="form-label">{{ __('Email Address') }}</label>
                            <input id="email" type="email" class="form-control @error('email') is-invalid @enderror" name="email" value="{{ old('email') }}" required autocomplete="email">
                            @error('email')
                            <span class="invalid-feedback" role="alert">
                                <strong>{{ $message }}</strong>
                            </span>
                            @enderror
                        </div>
                        <div class="col-12">
                            <label for="yourUsername" class="form-label">{{ __('Password') }}</label>
                            <input id="password" type="password" class="form-control @error('password') is-invalid @enderror" name="password" required autocomplete="new-password">
                            @error('password')
                            <span class="invalid-feedback" role="alert">
                                <strong>{{ $message }}</strong>
                            </span>
                            @enderror
                        </div>
                        <div class="col-12">
                            <label for="yourUsername" class="form-label">{{ __('Confirm Password') }}</label>
                            <input id="password-confirm" type="password" class="form-control" name="password_confirmation" required autocomplete="new-password">
                        </div>
                        <div class="col-12">
                            <label for="role" class="form-label">{{ __('User Type') }}</label>
                            <select id="role" class="form-control @error('role') is-invalid @enderror" name="role" required>
                                <option value="">Select User Type</option>
                                <option value="0" {{ old('role') == '0' ? 'selected' : '' }}>Admin</option>
                                <option value="1" {{ old('role') == '1' ? 'selected' : '' }}>Tenant</option>
                            </select>
                            @error('role')
                            <span class="invalid-feedback" role="alert">
                                <strong>{{ $message }}</strong>
                            </span>
                            @enderror
                        </div>
                        <div class="row mb-0 mt-3">
                            <div class="col-12 offset-md-4">
                                <button type="submit" class="btn btn-primary">
                                    {{ __('Register') }}
                                </button>
                            </div>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection