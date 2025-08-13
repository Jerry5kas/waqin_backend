@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Manage Channel Partners</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Manage Channel Partners</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Channel Partners</h5>

          <form class="row g-3" method="POST" action="{{ url('add') }}">
                @csrf

                <!-- Full Name -->
                <div class="col-12">
                    <label class="form-label">Full Name</label>
                    <input type="text" class="form-control" name="full_name" required>
                </div>

                <!-- Email -->
                <div class="col-12">
                    <label class="form-label">E-mail</label>
                    <input type="email" class="form-control" name="email" required>
                </div>

                <!-- Mobile -->
                <div class="col-12">
                    <label class="form-label">Mobile</label>
                    <input type="number" class="form-control" name="mobile" required>
                </div>

                <!-- Password -->
                <div class="col-12">
                    <label class="form-label">4-Digit PIN</label>
                    <input type="password" class="form-control" name="password"
                        required minlength="4" maxlength="4" autocomplete="new-password"
                        onfocus="this.removeAttribute('readonly');" readonly>
                </div>

                <!-- Select Strategic Channel Partner -->
                <div class="col-12">
                    <label class="form-label">Select Strategic Channel Partner</label>
                    <select name="cp_id" class="form-select">
                        <option value="">-- None --</option>
                        @foreach($strategicPartners as $partner)
                            <option value="{{ $partner->id }}">{{ $partner->full_name }}</option>
                        @endforeach
                    </select>
                </div>

                <!-- Strategic CP Checkbox -->
                <div class="col-12">
                    <div class="form-check">
                        <input class="form-check-input" type="checkbox" name="is_strategic_cp" value="1" id="isStrategic">
                        <label class="form-check-label" for="isStrategic">
                            Is Strategic Channel Partner
                        </label>
                    </div>
                </div>

                <!-- Submit + Reset -->
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
                    <h5 class="card-title">Channel Partners</h5>
                </div>
                <table class="table table-bordered table-striped datatable">
                    <thead>
                        <tr>
                            <th scope="col">#</th>
                            <th scope="col">Full Name</th>
                            <th scope="col">E Mail</th>
                            <th scope="col">Number</th>
                            <th scope="col">Created By</th>
                            <th scope="col">Status</th>
                            <th scope="col">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($partners as $index => $data)
                        <tr>
                            <td>{{$index + 1}}</td>
                            <td>{{ $data->full_name }}</td>
                            <td>{{ $data->email }}</td>
                            <td>{{ $data->mobile }}</td>
                            <td>{{ $data->created_by }}</td>
                            @if ($data->status == 1)
                            <td> <span class="badge bg-success">Active</span> </td>
                            @else
                            <td> <span class="badge bg-danger">Inactive</span> </td>
                            @endif
                            <td>
                                <div class="d-flex justify-content-center align-items-center">
                                    <a class="icon edit-icon m-2" href="#" data-id="{{ $data->id }}" data-action="edit" title="Edit">
                                        <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                    </a>
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('partner.destroy', $data->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>
                                    @if ($data->status == 1)
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                            onclick="confirmAction('deactivate', '{{ route('partner.deactivate', $data->id) }}', 'GET')">
                                        <i class="text-danger bi bi-x-circle-fill"></i>
                                    </button>
                                    @else
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                            onclick="confirmAction('activate', '{{ route('partner.activate', $data->id) }}', 'GET')">
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
