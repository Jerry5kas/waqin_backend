@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Cities</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Cities</li>
            </ol>
        </nav>
    </div>

    <div class="row">
        <div class="col-4">
            <div class="card">
                <div class="card-body">
                    <h5 class="card-title">Add City</h5>

                    <form class="row g-3" method="POST" action="{{ route('cities.store') }}">
                        @csrf
                        <div class="col-12">
                            <label for="countryId" class="form-label">Select Country</label>
                            <select class="form-select" name="country_id" id="countryId" required>
                                <option value="" disabled selected>Select a Country</option>
                                @foreach($countries as $country)
                                    <option value="{{ $country->id }}">{{ $country->country_name }}</option>
                                @endforeach
                            </select>
                        </div>
                        <div class="col-12">
                            <label for="stateId" class="form-label">Select State</label>
                            <select class="form-select" name="state_id" id="stateId" required>
                                <option value="" disabled selected>Select a State</option>
                            </select>
                        </div>
                        <div class="col-12">
                            <label for="cityName" class="form-label">City Name</label>
                            <input type="text" class="form-control" name="city_name" id="cityName" required>
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
                            <h5 class="card-title">Cities</h5>
                        </div>
                        <table class="table table-bordered table-striped datatable">
                            <thead>
                                <tr>
                                    <th scope="col">#</th>
                                    <th scope="col">City Name</th>
                                    <th scope="col">State</th>
                                    <th scope="col">Country</th>
                                    <th scope="col">Status</th>
                                    <th scope="col">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($cities as $index => $data)
                                <tr>
                                    <td>{{ $index + 1 }}</td>
                                    <td>
                                        <span class="city-name" id="city-name-{{ $data->id }}">{{ $data->city_name }}</span>
                                        <input type="text" class="form-control edit-city-name d-none" id="edit-city-name-{{ $data->id }}" value="{{ $data->city_name }}">
                                        <button class="btn btn-primary d-none save-btn mt-1" data-id="{{ $data->id }}">Save</button>
                                        <button class="btn btn-secondary d-none cancel-btn mt-1" data-id="{{ $data->id }}">Cancel</button>
                                    </td>
                                    <td>
                                        @foreach($states as $state)
                                            @if($data->state_id == $state->id)
                                                {{ $state->state_name }}
                                            @endif
                                        @endforeach
                                    </td>
                                    <td>
                                        @foreach($countries as $country)
                                            @if($data->country_id == $country->id)
                                                {{ $country->country_name }}
                                            @endif
                                        @endforeach
                                    </td>
                                    @if ($data->status == 1)
                                    <td><span class="badge bg-success">Active</span></td>
                                    @else
                                    <td><span class="badge bg-danger">Inactive</span></td>
                                    @endif
                                    <td>
                                        <div class="d-flex justify-content-center align-items-center">
                                            <a class="icon edit-icon m-2" href="#" data-id="{{ $data->id }}" data-action="edit" title="Edit">
                                                <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                            </a>
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                                    onclick="confirmAction('delete', '{{ route('cities.destroy', $data->id) }}', 'POST')">
                                                <i class="text-danger bi bi-trash3-fill"></i>
                                            </button>
                                            @if ($data->status == 1)
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                    onclick="confirmAction('deactivate', '{{ route('cities.deactivate', $data->id) }}', 'GET')">
                                                <i class="text-danger bi bi-x-circle-fill"></i>
                                            </button>
                                            @else
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                    onclick="confirmAction('activate', '{{ route('cities.activate', $data->id) }}', 'GET')">
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
    document.querySelectorAll('.edit-icon').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            document.getElementById(`city-name-${id}`).classList.add('d-none');
            document.getElementById(`edit-city-name-${id}`).classList.remove('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.remove('d-none');
            document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.remove('d-none');
        });
    });

    document.querySelectorAll('.cancel-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            document.getElementById(`city-name-${id}`).classList.remove('d-none');
            document.getElementById(`edit-city-name-${id}`).classList.add('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.add('d-none');
            document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.add('d-none');
        });
    });
    
    document.querySelectorAll('.save-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            const newCityName = document.getElementById(`edit-city-name-${id}`).value;

            fetch(`/cities/${id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': '{{ csrf_token() }}',
                },
                body: JSON.stringify({
                    city_name: newCityName,
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById(`city-name-${id}`).textContent = newCityName;
                    document.getElementById(`city-name-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-city-name-${id}`).classList.add('d-none');
                    document.querySelector(`.save-btn[data-id="${id}"]`).classList.add('d-none');
                    document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.add('d-none');
                    showMessage('success', 'City updated successfully.');
                }
            })
            .catch(error => {
                console.error('Error:', error);
                showMessage('error', 'Error updating city.');
            });
        });
    });

});

// state selection by country script
document.addEventListener('DOMContentLoaded', function () {
    const countrySelect = document.getElementById('countryId');
    const stateSelect = document.getElementById('stateId');

    countrySelect.addEventListener('change', function () {
        const countryId = this.value;

        // Clear existing states
        stateSelect.innerHTML = '<option value="" disabled selected>Select a State</option>';

        if (countryId) {
            fetch(`/states/${countryId}`)
                .then(response => response.json())
                .then(states => {
                    states.forEach(state => {
                        const option = document.createElement('option');
                        option.value = state.id;
                        option.textContent = state.state_name;
                        stateSelect.appendChild(option);
                    });
                })
                .catch(error => console.error('Error fetching states:', error));
        }
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
                            Are you sure you want to ${action} this city?
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
