
@extends('layouts.superadmin')

@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Marketings</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Marketings</li>
            </ol>
        </nav>
    </div>

    <div class="row">
        <div class="col-4">
          <div class="dashboard">
              <div class="card recent-sales overflow-auto">
                  <div class="card-body">
                      <div class="d-flex justify-content-between my-2">
                          <h5 class="card-title">Marketings</h5>
                      </div>
                   <div>
    <!-- Here you can add a form for adding new marketing entries -->
    <form action="{{ route('marketing.store') }}" method="POST" enctype="multipart/form-data">
        @csrf
        <div class="form-group">
            <label for="business_id">Select Business</label>
            <select class="form-control" id="business_id" name="business_id[]" multiple>
                @foreach($businesses as $business)
                    <option value="{{ $business->id }}">{{ $business->name }}</option>
                @endforeach
            </select>
        </div>
        <div class="form-group">
            <label for="title">Title</label>
            <input type="text" class="form-control" id="title" name="title" required>
        </div>
        <div class="form-group">
            <label for="subtitle">Subtitle</label>
            <input type="text" class="form-control" id="subtitle" name="subtitle" required>
        </div>
        <div class="form-group">
            <label for="description">Description</label>
            <textarea class="form-control" id="description" name="description" required></textarea>
        </div>
        <div class="form-group">
            <label for="image">Image</label>
            <input type="file" class="form-control" id="image" name="image">
        </div>
        <div class="form-group">
            <label for="offer_list">Offer List</label>
            <div id="offer-list-container">
                <div class="input-group mb-2">
                    <input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">
                </div>
            </div>
            <div class="text-end">
            <button type="button" class="icon btn btn-sm" id="add-more-offer"><i class="bi bi-plus-lg">Add More</i></button>
           </div>
        </div>       
        <div class="form-group">
            <label for="summary">Summary</label>
            <textarea class="form-control" id="summary" name="summary"></textarea>
        </div>
        <div class="form-group">
            <label for="location">Location</label>
            <input type="text" class="form-control" id="location" name="location" required>
        </div>
        <button type="submit" class="mt-2 btn btn-primary">Submit</button>
    </form>
</div>
                      
                  </div>
              </div>
          </div>
        </div>
      
        <div class="col-8">
          <div class="dashboard">
              <div class="card recent-sales overflow-auto">
                  <div class="card-body">
                      <div class="d-flex justify-content-between my-2">
                          <h5 class="card-title">Marketings</h5>
                      </div>
                      <table class="table table-bordered table-striped datatable">
                          <thead>
                              <tr>
                                  <th>#</th>
                                  <th>Business</th>
                                  <th>Title</th>
                                  <th>Subtitle</th>
                                  <th>Description</th>
                                  <th>Image</th>
                                  <th>Offer List</th>
                                  <th>Summary</th>
                                  <th>Location</th>
                                  <th>Status</th>
                                  <th>Actions</th>
                              </tr>
                          </thead>
                          <tbody>
                              @foreach ($marketings as $index => $data)
                              <tr>
                                  <td>{{$index + 1}}</td>
                                  <td>
                                    @php
                                        // Split the business_id string into an array of IDs
                                        $businessIds = explode(',', $data->business_id);
                                    @endphp
                                
                                    @foreach($businesses as $business)
                                        @if(in_array($business->id, $businessIds))
                                            {{ $business->name }}@if(!$loop->last), @endif
                                        @endif
                                    @endforeach
                                </td>
                                  <td>{{ $data->title }}</td>
                                  <td>{{ $data->subtitle }}</td>
                                  <td>{{ $data->description }}</td>
                                  <td style="position: relative;">
                                        <!-- Clickable image to open modal -->
                                        <a href="#" data-bs-toggle="modal" data-bs-target="#imageModal_{{ $data->id }}">
                                            <img src="{{ asset($data->image) }}" alt="{{ $data->title }}" width="80" height="30" class="img-thumbnail">
                                        </a>

                                        <!-- Edit icon -->
                                        <span class="position-absolute top-0 end-0 p-1" data-bs-toggle="modal" data-bs-target="#imageModal_{{ $data->id }}" style="cursor: pointer;">
                                            <i class="bi bi-pencil-square fs-5 text-primary"></i>
                                        </span>

                                        <!-- Image Upload Modal -->
                                        <div class="modal fade" id="imageModal_{{ $data->id }}" tabindex="-1" aria-labelledby="imageModalLabel_{{ $data->id }}" aria-hidden="true">
                                            <div class="modal-dialog">
                                                <div class="modal-content">
                                                    <div class="modal-header">
                                                        <h5 class="modal-title" id="imageModalLabel_{{ $data->id }}">Edit Image</h5>
                                                        <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                                    </div>
                                                    <div class="modal-body text-center">
                                                        <!-- Enlarged Image Preview -->
                                                        <img src="{{ asset($data->image) }}" alt="{{ $data->title }}" class="img-fluid mb-3" style="max-height: 50vh; width: auto; object-fit: contain;">
                                                        
                                                        <!-- Upload Form -->
                                                        <form action="{{ route('admin.update.image', $data->id) }}" method="POST" enctype="multipart/form-data">
                                                            @csrf
                                                            <input type="file" class="form-control" name="image" required>
                                                            <button type="submit" class="btn btn-primary mt-3">Upload</button>
                                                        </form>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </td>
                                  <td>{{ $data->offer_list }}</td>
                                  <td>{{ $data->summary }}</td>
                                  <td>{{ $data->location }}</td>
                                  @if ($data->status == 1)
                                  <td> <span class="badge bg-success">Active</span> </td>
                                  @else
                                  <td> <span class="badge bg-danger">Inactive</span> </td>
                                  @endif
                                  <td>
                                      <div class="d-flex justify-content-center align-items-center">
                                            <a href="javascript:void(0);" class="icon edit-marketing m-2" 
                                            data-id="{{ $data->id }}" 
                                            data-bs-toggle="modal" 
                                            data-bs-target="#editMarketingModal" 
                                            onclick="loadMarketingData({{ $data->id }})">
                                                <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                            </a>
                                           <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                                  onclick="confirmAction('delete', '{{ route('businessCategories.destroy', $data->id) }}', 'POST')">
                                              <i class="text-danger bi bi-trash3-fill"></i>
                                          </button>
                                          @if ($data->status == 1)
                                          <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                  onclick="confirmAction('deactivate', '{{ route('businessCategories.deactivate', $data->id) }}', 'GET')">
                                              <i class="text-danger bi bi-x-circle-fill"></i>
                                          </button>
                                          @else
                                          <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                  onclick="confirmAction('activate', '{{ route('businessCategories.activate', $data->id) }}', 'GET')">
                                              <i class="text-success bi bi-check2-circle"></i>
                                          </button>
                                          @endif
                                      </div>
                                  </td>                                                        
                              </tr>
                              @endforeach
                          </tbody>
                      </table>
                  </div>
              </div>
          </div>
        </div>
      
</div> 

<!-- Edit Marketing Modal -->
<div class="modal fade" id="editMarketingModal" tabindex="-1" aria-labelledby="editMarketingModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editMarketingModalLabel">Edit Marketing Item</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <form id="editMarketingForm">
                    @csrf
                    <input type="hidden" id="edit_marketing_id">

                    <div class="mb-3">
                        <label for="edit_business_id" class="form-label">Select Business</label>
                        <select class="form-control" id="edit_business_id" name="business_id[]" multiple>
                            @foreach($businesses as $business)
                                <option value="{{ $business->id }}">{{ $business->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    
                    <div class="mb-3">
                        <label for="edit_title" class="form-label">Title</label>
                        <input type="text" class="form-control" id="edit_title" name="title" required>
                    </div>

                    <div class="mb-3">
                        <label for="edit_subtitle" class="form-label">Subtitle</label>
                        <input type="text" class="form-control" id="edit_subtitle" name="subtitle" required>
                    </div>

                    <div class="mb-3">
                        <label for="edit_description" class="form-label">Description</label>
                        <textarea class="form-control" id="edit_description" name="description" required></textarea>
                    </div>

                    <div class="mb-3">
                        <label for="edit_image" class="form-label">Upload Image</label>
                        <input type="file" class="form-control" id="edit_image" name="image">
                    </div>
                    
                    <div class="form-group">
                        <label for="edit_offer_list">Offer List</label>
                        <div id="edit-offer-list-container">
                            <!-- Existing offers will be loaded dynamically here -->
                        </div>
                        <div class="text-end">
                            <button type="button" class="icon btn btn-sm" id="edit-add-more-offer">
                                <i class="bi bi-plus-lg">Add More</i>
                            </button>
                        </div>
                    </div>

                    <div class="form-group">
                        <label for="edit_summary">Summary</label>
                        <textarea class="form-control" id="edit_summary" name="summary"></textarea>
                    </div>

                    <div class="mb-3">
                        <label for="edit_location" class="form-label">Location</label>
                        <input type="text" class="form-control" id="edit_location" name="location" required>
                    </div>

                    <button type="button" class="btn btn-primary" onclick="updateMarketing()">Update</button>
                </form>
            </div>
        </div>
    </div>
</div>

@endsection
@section('script')
<script>
   document.addEventListener('DOMContentLoaded', function () {
    const offerListContainer = document.getElementById('offer-list-container');
    const addMoreButton = document.getElementById('add-more-offer');

    // Add new input field
    addMoreButton.addEventListener('click', function () {
        const newInputGroup = document.createElement('div');
        newInputGroup.classList.add('input-group', 'mb-2');
        newInputGroup.innerHTML = `
            <input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">
            <div class="input-group-append">
                <button class="ms-1 btn btn-danger remove-offer" type="button"><i class="text-white bi bi-trash3-fill remove-offer"></i></button>
            </div>
        `;
        offerListContainer.appendChild(newInputGroup);
    });

    // Remove input field
    offerListContainer.addEventListener('click', function (e) {
        if (e.target.classList.contains('remove-offer')) {
            e.target.closest('.input-group').remove();
        }
    });

    $(document).on('click', '#edit-add-more-offer', function() {
        $('#edit-offer-list-container').append(`
            <div class="input-group mb-2">
                <input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">
                <button type="button" class="btn btn-danger remove-offer"><i class="bi bi-x-lg"></i></button>
            </div>
        `);
    });

    // Remove Offer Item
    $(document).on('click', '.remove-offer', function() {
        $(this).closest('.input-group').remove();
    });
});

</script>
<script>
function loadMarketingData(id) {
    $.ajax({
        url: "/marketing/" + id + "/edit",
        type: "GET",
        success: function(response) {
            $('#edit_marketing_id').val(response.id);
            $('#edit_title').val(response.title);
            $('#edit_subtitle').val(response.subtitle);
            $('#edit_description').val(response.description);
            $('#edit_location').val(response.location);
            $('#edit_summary').val(response.summary);

            let businessIds = response.business_id ? response.business_id.split(',') : [];
            $('#edit_business_id').val(businessIds).trigger('change');

            let offerListContainer = $('#edit-offer-list-container');
            offerListContainer.empty(); // Clear previous fields

            if (response.offer_list) {
                let offers = JSON.parse(response.offer_list);
                offers.forEach(function(offer) {
                    offerListContainer.append(`
                        <div class="input-group mb-2">
                            <input type="text" class="form-control" name="offer_list[]" value="${offer}">
                            <button type="button" class="btn btn-danger remove-offer"><i class="bi bi-x-lg"></i></button>
                        </div>
                    `);
                });
            } else {
                // If no offers exist, add an empty input
                offerListContainer.append(`
                    <div class="input-group mb-2">
                        <input type="text" class="form-control" name="offer_list[]" placeholder="Enter offer item">
                    </div>
                `);
            }

            $('#editMarketingModal').modal('show'); // Show the modal
        }
    });
}

function updateMarketing() {
    let formData = new FormData($('#editMarketingForm')[0]);
    let id = $('#edit_marketing_id').val();

    $.ajax({
        url: "/marketing/" + id,
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
        success: function(response) {
            location.reload();
        },
        error: function(response) {
            alert("Error updating marketing item");
        }
    });
}
</script>
<script>
    $(document).ready(function() {
        $('#business_id').select2({
            placeholder: 'Select Business',
            allowClear: true
        });
    });
</script>
<script>
    $(document).ready(function() {
    $('#edit_business_id').select2({
        placeholder: 'Select Business',
        allowClear: true,
        dropdownParent: $('#editMarketingModal')
    });
});
</script>
@endsection
