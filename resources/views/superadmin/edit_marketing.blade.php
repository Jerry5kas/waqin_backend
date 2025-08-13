@extends('layouts.superadmin')

@section('content')
<div class="container">
    <h2>Edit Marketing</h2>

    <form action="{{ route('admin.marketings.update', $marketingItem->id) }}" method="POST" enctype="multipart/form-data">
        @csrf

        <div class="form-group">
            <label for="business_id">Select Business</label>
            <select class="form-control" id="business_id" name="business_id[]" multiple>
                @foreach($businesses as $business)
                    <option value="{{ $business->id }}" 
                        {{ in_array($business->id, $marketingItem->business_ids) ? 'selected' : '' }}>
                        {{ $business->name }}
                    </option>
                @endforeach
            </select>
        </div>

        <div class="form-group">
            <label for="title">Title</label>
            <input type="text" class="form-control" id="title" name="title" value="{{ $marketingItem->title }}" required>
        </div>

        <div class="form-group">
            <label for="subtitle">Subtitle</label>
            <input type="text" class="form-control" id="subtitle" name="subtitle" value="{{ $marketingItem->subtitle }}" required>
        </div>

        <div class="form-group">
            <label for="description">Description</label>
            <textarea class="form-control" id="description" name="description" required>{{ $marketingItem->description }}</textarea>
        </div>

        <div class="form-group">
            <label for="image">Image</label>
            @if ($marketingItem->image)
                <img src="{{ asset('uploads/' . $marketingItem->image) }}" alt="Current Image" width="80" class="mb-2">
            @endif
            <input type="file" class="form-control" id="image" name="image">
        </div>

        <div class="form-group">
            <label for="offer_list">Offer List</label>
            <div id="offer-list-container">
                @foreach ($marketingItem->offer_list as $offer)
                    <div class="input-group mb-2">
                        <input type="text" class="form-control" name="offer_list[]" value="{{ $offer }}" placeholder="Enter offer item">
                    </div>
                @endforeach
                <div class="input-group mb-2">
                    <input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">
                </div>
            </div>
            <div class="text-end">
                <button type="button" class="icon btn btn-sm" id="add-more-offer"><i class="bi bi-plus-lg"></i> Add More</button>
            </div>
        </div>

        <div class="form-group">
            <label for="summary">Summary</label>
            <textarea class="form-control" id="summary" name="summary">{{ $marketingItem->summary }}</textarea>
        </div>

        <div class="form-group">
            <label for="location">Location</label>
            <input type="text" class="form-control" id="location" name="location" value="{{ $marketingItem->location }}" required>
        </div>

        <button type="submit" class="mt-2 btn btn-primary">Submit</button>
        <a href="{{ route('admin.marketings.index') }}" class="btn btn-secondary mt-2">Cancel</a>
    </form>
</div>
@endsection
@section('script')
<script>
    document.getElementById('add-more-offer').addEventListener('click', function() {
        const container = document.getElementById('offer-list-container');
        const inputGroup = document.createElement('div');
        inputGroup.className = 'input-group mb-2';
        inputGroup.innerHTML = '<input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">';
        container.appendChild(inputGroup);
    });
</script>

@endsection
