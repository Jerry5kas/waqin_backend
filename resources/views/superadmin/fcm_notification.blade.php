@extends('layouts.superadmin')

@section('content')
<div class="container">
    <h2>Send FCM Notification</h2>

    <form action="{{ route('send.notification') }}" method="POST">
        @csrf

        <div class="form-group mt-3">
            <label for="title">Title</label>
            <input type="text" name="title" class="form-control" required>
        </div>

        <div class="form-group mt-3">
            <label for="message">Message</label>
            <textarea name="message" class="form-control" required></textarea>
        </div>

        <div class="form-group mt-3">
            <label for="icon">Icon URL (optional)</label>
            <input type="text" name="image" class="form-control">
        </div>

        <div class="form-group mt-3">
            <label for="tenants">Select Tenants</label>
            <select id="tenants" name="tenants[]" class="form-control select2" multiple>
                <option value="all">Select All</option>
                @foreach($tenants as $tenant)
                    <option value="{{ $tenant->id }}">{{ $tenant->name }}</option>
                @endforeach
            </select>
        </div>

        <div class="form-group mt-3">
            <label for="route">Select Route</label>
            <select name="route_name" class="form-control">
            <option value="" selected disabled>Select Route</option>
                @foreach($routes as $route)
                    <option value="{{ $route->route_name }}">{{ $route->page_name }}</option>
                @endforeach
            </select>
        </div>

        <button type="submit" class="btn btn-primary mt-3">Send Notification</button>
    </form>
</div>
@endsection
@section('script')
<script>
    $(document).ready(function() {
        $('#tenants').select2({
            placeholder: 'Select Tenants',
            allowClear: true
        });
   
    $('#tenants').on('change', function () {
            let values = $(this).val();
            if (values && values.includes('all')) {
                $(this).find('option').prop('selected', true);
                $(this).trigger('change');
            }
        });
    });
</script>
@endsection
