@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Countries</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Countries</li>
            </ol>
        </nav>
    </div>

    <div class="row">
        {{-- <div class="col-12">
            <div class="card">
                <div class="card-body">
                    <h5 class="card-title">Add Country</h5>

                    <form class="row g-3" method="POST" action="{{ route('countries.store') }}">
                        @csrf
                        <div class="col-3">
                            <label for="countryCode" class="form-label">Country Code</label>
                            <input type="text" class="form-control" name="country_code" id="countryCode" required>
                        </div>
                        <div class="col-3">
                            <label for="countryName" class="form-label">Country Name</label>
                            <input type="text" class="form-control" name="country_name" id="countryName" required>
                        </div>
                        <div class="col-3">
                            <label for="timeZone" class="form-label">Time Zone</label>
                            <input type="text" class="form-control" name="time_zone" id="timeZone" required>
                        </div>
                        <div class="col-3">
                            <label for="standardTimeZone" class="form-label">Standard Time Zone</label>
                            <input type="text" class="form-control" name="standard_time_zone" id="standardTimeZone" required>
                        </div>
                        <div class="text-end">
                            <button type="submit" class="btn btn-primary">Submit</button>
                            <button type="reset" class="btn btn-secondary">Reset</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>   --}}
        <div class="col-12 mt-3">
            <div class="dashboard">
                <div class="card recent-sales overflow-auto">
                    <div class="card-body">
                        <div class="d-flex justify-content-between my-2">
                            <h5 class="card-title">Countries</h5>
                        </div>
                        <table class="table table-bordered table-striped datatable">
                            <thead>
                                <tr>
                                    <th scope="col">#</th>
                                    <th scope="col">Country Code</th>
                                    <th scope="col">Country Name</th>
                                    <th scope="col">Time Zone</th>
                                    <th scope="col">Standard Time Zone</th>
                                    <th scope="col">Status</th>
                                    <th scope="col">Action</th>
                                </tr>
                            </thead>
                            <tbody>
                                @foreach ($countries as $index => $country)
                                <tr>
                                    <td>{{ $index + 1 }}</td>
                                    <td>
                                        <span class="country-code" id="country-code-{{ $country->id }}">{{ $country->country_code }}</span>
                                        <input type="text" class="form-control edit-country-code d-none" id="edit-country-code-{{ $country->id }}" value="{{ $country->country_code }}">
                                    </td>
                                    <td>
                                        <span class="country-name" id="country-name-{{ $country->id }}">{{ $country->country_name }}</span>
                                        <input type="text" class="form-control edit-country-name d-none" id="edit-country-name-{{ $country->id }}" value="{{ $country->country_name }}">
                                    </td>
                                    <td>
                                        <span class="time-zone" id="time-zone-{{ $country->id }}">{{ $country->time_zone }}</span>
                                        <input type="text" class="form-control edit-time-zone d-none" id="edit-time-zone-{{ $country->id }}" value="{{ $country->time_zone }}">
                                    </td>
                                    <td>
                                        <span class="standard-time-zone" id="standard-time-zone-{{ $country->id }}">{{ $country->standard_time_zone }}</span>
                                        <input type="text" class="form-control edit-standard-time-zone d-none" id="edit-standard-time-zone-{{ $country->id }}" value="{{ $country->standard_time_zone }}">
                                        <button class="btn btn-primary d-none save-btn mt-1" data-id="{{ $country->id }}">Save</button>
                                        <button class="btn btn-secondary d-none cancel-btn mt-1" data-id="{{ $country->id }}">Cancel</button>
                                    </td>
                                    @if ($country->status == 1)
                                    <td><span class="badge bg-success">Active</span></td>
                                    @else
                                    <td><span class="badge bg-danger">Inactive</span></td>
                                    @endif
                                    <td>
                                    
                                        <div class="d-flex justify-content-center align-items-center">
                                            <a class="icon edit-icon m-2" href="#" data-id="{{ $country->id }}" data-action="edit" title="Edit">
                                                <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                            </a>
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                                    onclick="confirmAction('delete', '{{ route('countries.destroy', $country->id) }}', 'POST')">
                                                <i class="text-danger bi bi-trash3-fill"></i>
                                            </button>
                                            @if ($country->status == 1)
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                                    onclick="confirmAction('deactivate', '{{ route('countries.deactivate', $country->id) }}', 'GET')">
                                                <i class="text-danger bi bi-x-circle-fill"></i>
                                            </button>
                                            @else
                                            <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                                    onclick="confirmAction('activate', '{{ route('countries.activate', $country->id) }}', 'GET')">
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
            document.getElementById(`country-code-${id}`).classList.add('d-none');
            document.getElementById(`edit-country-code-${id}`).classList.remove('d-none');
            document.getElementById(`country-name-${id}`).classList.add('d-none');
            document.getElementById(`edit-country-name-${id}`).classList.remove('d-none');
            document.getElementById(`time-zone-${id}`).classList.add('d-none');
            document.getElementById(`edit-time-zone-${id}`).classList.remove('d-none');
            document.getElementById(`standard-time-zone-${id}`).classList.add('d-none');
            document.getElementById(`edit-standard-time-zone-${id}`).classList.remove('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.remove('d-none');
            document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.remove('d-none');
            this.classList.add('d-none');
        });
    });

    document.querySelectorAll('.save-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            const countryCode = document.getElementById(`edit-country-code-${id}`).value;
            const countryName = document.getElementById(`edit-country-name-${id}`).value;
            const timeZone = document.getElementById(`edit-time-zone-${id}`).value;
            const standardTimeZone = document.getElementById(`edit-standard-time-zone-${id}`).value;

            fetch(`/countries/${id}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-TOKEN': '{{ csrf_token() }}'
                },
                body: JSON.stringify({
                    country_code: countryCode,
                    country_name: countryName,
                    time_zone: timeZone,
                    standard_time_zone: standardTimeZone
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    document.getElementById(`country-code-${id}`).textContent = countryCode;
                    document.getElementById(`country-name-${id}`).textContent = countryName;
                    document.getElementById(`time-zone-${id}`).textContent = timeZone;
                    document.getElementById(`standard-time-zone-${id}`).textContent = standardTimeZone;
                    document.getElementById(`country-code-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-country-code-${id}`).classList.add('d-none');
                    document.getElementById(`country-name-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-country-name-${id}`).classList.add('d-none');
                    document.getElementById(`time-zone-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-time-zone-${id}`).classList.add('d-none');
                    document.getElementById(`standard-time-zone-${id}`).classList.remove('d-none');
                    document.getElementById(`edit-standard-time-zone-${id}`).classList.add('d-none');
                    document.querySelector(`.save-btn[data-id="${id}"]`).classList.add('d-none');
                    document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.add('d-none');
                    document.querySelector(`.edit-icon[data-id="${id}"]`).classList.remove('d-none');
                } else {
                    document.getElementById('message-container').textContent = data.message;
                    document.getElementById('message-container').classList.add('alert-danger');
                    document.getElementById('message-container').style.display = 'block';
                }
            })
            .catch(error => {
                console.error('Error:', error);
                document.getElementById('message-container').textContent = 'An error occurred while updating the country.';
                document.getElementById('message-container').classList.add('alert-danger');
                document.getElementById('message-container').style.display = 'block';
            });
        });
    });

    document.querySelectorAll('.cancel-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const id = this.getAttribute('data-id');
            document.getElementById(`country-code-${id}`).classList.remove('d-none');
            document.getElementById(`edit-country-code-${id}`).classList.add('d-none');
            document.getElementById(`country-name-${id}`).classList.remove('d-none');
            document.getElementById(`edit-country-name-${id}`).classList.add('d-none');
            document.getElementById(`time-zone-${id}`).classList.remove('d-none');
            document.getElementById(`edit-time-zone-${id}`).classList.add('d-none');
            document.getElementById(`standard-time-zone-${id}`).classList.remove('d-none');
            document.getElementById(`edit-standard-time-zone-${id}`).classList.add('d-none');
            document.querySelector(`.save-btn[data-id="${id}"]`).classList.add('d-none');
            document.querySelector(`.cancel-btn[data-id="${id}"]`).classList.add('d-none');
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
                            Are you sure you want to ${action} this country?
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
