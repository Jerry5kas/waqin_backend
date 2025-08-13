@extends('layouts.app')

@section('content')
<div class="container">
    <h2>Enter Password to Download</h2>

    @if(session('error'))
        <div class="alert alert-danger">{{ session('error') }}</div>
    @endif

    <form action="{{ route('apks.download', $apk->id) }}" method="POST">
        @csrf
        <div class="mb-3">
            <label for="password" class="form-label">Password</label>
            <input type="text" class="form-control" id="password" name="password" required>
        </div>

        <button type="submit" class="btn btn-primary">Download</button>
    </form>
</div>
@endsection
