@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Contact Group</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Contact Group</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Contact Group</h5>

          <form class="row g-3" method="POST" action="{{ url('AddContactGroup') }}">
            @csrf
            <div class="col-12">
              <label for="inputNanme4" class="form-label">Add Contact Group</label>
              <select class="form-select" name="business_id" id="businessId" required>
                <option value="" disabled selected>Select a Business</option>
                @foreach($businessCategories as $business)
                    <option value="{{ $business->id }}">{{ $business->name }}</option>
                @endforeach
            </select>
            </div>
            <div class="col-12">
                <label for="statusName" class="form-label">Contact Group Name</label>
                <input type="text" class="form-control" name="name" id="contactGroupName" placeholder="Enter Contact Group name" required>
            </div>
            <div class="text-end">
              <button type="submit" class="btn btn-primary">Submit</button>
              <button type="reset" class="btn btn-secondary">Reset</button>
            </div>
          </form>

        </div>
    </div>
  </div>  
  <div class="col-8">
    <div class="dashboard">
        <div class="card recent-sales overflow-auto">
            <div class="card-body">
                <div class="d-flex justify-content-between my-2">
                    <h5 class="card-title">Contact Group</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th scope="col">#</th>
                            <th scope="col">Business</th>
                            <th scope="col">Contact Group Name</th>
                            <th scope="col">Status</th>
                            <th scope="col">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($contactGroup as $index => $contactGroup)
                        <tr>
                            <td>{{$index + 1}}</td>
                            <td>
                                @if($contactGroup->business_id == 'all')
                                    All Businesses
                                @else
                                    @foreach($businessCategories as $business)
                                        @if($contactGroup->business_id == $business->id)
                                            {{ $business->name }}
                                        @endif
                                    @endforeach
                                @endif
                            </td>
                            <td>
                                <span class="status-name" id="status-name-{{ $contactGroup->id }}">{{ $contactGroup->name }}</span>
                                <input type="text" class="form-control edit-status-name d-none" id="edit-status-name-{{ $contactGroup->id }}" value="{{ $contactGroup->name }}">
                                <button class="btn btn-primary btn-sm d-none save-btn mt-1" data-id="{{ $contactGroup->id }}">Save</button>
                            <button class="btn btn-secondary btn-sm d-none cancel-btn mt-1" data-id="{{ $contactGroup->id }}">Cancel</button>
                            </td>
                            @if ($contactGroup->status == 1)
                            <td> <span class="badge bg-success">Active</span> </td>
                            @else
                            <td> <span class="badge bg-danger">Inactive</span> </td>
                            @endif
                            <td>
                                <div class="d-flex justify-content-center align-items-center">
                                    <a class="icon edit-icon m-2" href="#" data-id="{{ $contactGroup->id }}" data-action="edit" title="Edit">
                                        <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                    </a>
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('contactGroup.destroy', $contactGroup->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>
                                    @if ($contactGroup->status == 1)
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                            onclick="confirmAction('deactivate', '{{ route('contactGroup.deactivate', $contactGroup->id) }}', 'GET')">
                                        <i class="text-danger bi bi-x-circle-fill"></i>
                                    </button>
                                    @else
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                            onclick="confirmAction('activate', '{{ route('contactGroup.activate', $contactGroup->id) }}', 'GET')">
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

</div>

<script>
    document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll('.edit-icon').forEach(icon => {
        icon.addEventListener('click', function(e) {
            e.preventDefault();
            const id = this.getAttribute('data-id');
            document.getElementById(`status-name-${id}`).classList.add('d-none');
            document.getElementById(`edit-status-name-${id}`).classList.remove('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.remove('d-none');
            document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.remove('d-none');
            this.classList.add('d-none');
        });
    });

    document.querySelectorAll('.save-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            const statusName = document.getElementById(`edit-status-name-${id}`).value;

            fetch(`/status/${id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
                },
                body: JSON.stringify({
                    name: statusName,
                }),
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById(`status-name-${id}`).textContent = statusName;
                    document.getElementById(`status-name-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-status-name-${id}`).classList.add('d-none');
                    this.classList.add('d-none');
                    document.querySelector(`.edit-icon[data-id="${id}"]`).classList.remove('d-none');
                    document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.add('d-none');
                    showMessage('success', data.success);
                } else if (data.error) {
                    showMessage('error', data.error);
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showMessage('error', 'An error occurred while updating the status.');
            });
        });
    });

    document.querySelectorAll('.cancel-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            document.getElementById(`status-name-${id}`).classList.remove('d-none');
            document.getElementById(`edit-status-name-${id}`).classList.add('d-none');
            this.classList.add('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.add('d-none');
            document.querySelector(`.edit-icon[data-id="${id}"]`).classList.remove('d-none');
        });
    });
});

    function confirmAction(action, url, method) {
        let actionButtonHtml = method === 'POST' ? 
            `<form action="${url}" method="POST" style="display:inline;">
                @csrf
                @method('DELETE')
                <button type="submit" class="btn btn-primary">${capitalizeFirstLetter(action)}</button>
            </form>` : 
            `<a href="${url}" class="btn btn-primary">${capitalizeFirstLetter(action)}</a>`;

        let modalHtml = `
            <div class="modal fade" id="actionConfirmationModal" tabindex="-1" aria-labelledby="actionConfirmationModalLabel" aria-hidden="true">
                <div class="modal-dialog">
                    <div class="modal-content">
                        <div class="modal-header">
                            <h5 class="modal-title" id="actionConfirmationModalLabel">${capitalizeFirstLetter(action)} Confirmation</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                        </div>
                        <div class="modal-body">
                            Are you sure you want to ${action} this business category?
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            ${actionButtonHtml}
                        </div>
                    </div>
                </div>
            </div>
        `;

        // Append the modal to the body
        document.body.insertAdjacentHTML('beforeend', modalHtml);

        // Show the modal
        var actionConfirmationModal = new bootstrap.Modal(document.getElementById('actionConfirmationModal'));
        actionConfirmationModal.show();

        // Remove the modal from the DOM after it is closed
        document.getElementById('actionConfirmationModal').addEventListener('hidden.bs.modal', function () {
            document.getElementById('actionConfirmationModal').remove();
        });
    }

    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

</script>
@endsection