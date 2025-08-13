@extends('layouts.superadmin')
@section('content')

<div class="container">
    <div class="pagetitle">
        <h1>Query Mapping</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Query Mapping</li>
            </ol>
        </nav>
    </div>

<div class="row">
  <div class="col-4">
    <div class="card">
        <div class="card-body">
          <h5 class="card-title">Add Query Mapping</h5>

            <form class="row g-3" method="POST" action="{{ route('query_mapping.store') }}">
                @csrf
                <div class="col-12">
                    <label for="groupName" class="form-label">Group Name</label>
                    <select class="form-select" name="group_name" id="groupName" required>
                        <option value="" disabled selected>Select Group Name</option>
                        @foreach($contactGroups as $contactGroup)
                            <option value="{{ $contactGroup->name }}">{{ $contactGroup->name }}</option>
                        @endforeach
                    </select>
                </div>
                <div class="col-12">
                    <label for="methodName" class="form-label">Method Name</label>
                    <select class="form-select" name="method_name" id="methodName" required>
                        <option value="" disabled selected>Select Method Name</option>
                        @foreach($methodNames as $methodName)
                            <option value="{{ $methodName->method_name }}">{{ $methodName->method_name }}</option>
                        @endforeach
                    </select>
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
                            <th scope="col">Group Name</th>
                            <th scope="col">Method Name</th>
                            <th scope="col">Status</th>
                            <th scope="col">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                    @foreach ($queryMappings as $index => $queryMapping)
                        <tr>
                            <td>{{$index + 1}}</td>
                            <td>{{$queryMapping->group_name}}</td>
                            <td>{{$queryMapping->method_name}}</td>
                            @if ($queryMapping->status == 1)
                            <td> <span class="badge bg-success">Active</span> </td>
                            @else
                            <td> <span class="badge bg-danger">Inactive</span> </td>
                            @endif   
                            
                            <td>
                                <div class="d-flex justify-content-center align-items-center">
                                    <a class="icon edit-icon m-2" href="#" data-id="{{ $queryMapping->id }}" data-action="edit" title="Edit">
                                        <i class="bi bi-pencil-square" data-bs-toggle="tooltip" data-bs-placement="top" title="Edit"></i>
                                    </a>
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Delete"
                                            onclick="confirmAction('delete', '{{ route('query_mapping.destroy', $queryMapping->id) }}', 'POST')">
                                        <i class="text-danger bi bi-trash3-fill"></i>
                                    </button>
                                    @if ($queryMapping->status == 1)
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Deactivate"
                                            onclick="confirmAction('deactivate', '{{ route('query_mapping.deactivate', $queryMapping->id) }}', 'GET')">
                                        <i class="text-danger bi bi-x-circle-fill"></i>
                                    </button>
                                    @else
                                    <button type="button" class="icon btn btn-link" data-bs-toggle="tooltip" data-bs-placement="top" title="Activate"
                                            onclick="confirmAction('activate', '{{ route('query_mapping.activate', $queryMapping->id) }}', 'GET')">
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

<div class="modal fade" id="editQueryMappingModal" tabindex="-1" aria-labelledby="editQueryMappingLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="editQueryMappingLabel">Edit Query Mapping</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <form id="editQueryMappingForm" method="POST" action="{{ route('query_mapping.update', ':id') }}">
                @csrf
                @method('PUT') <!-- Specify PUT method here -->
                <div class="modal-body">
                    <div class="mb-3">
                        <label for="editGroupName" class="form-label">Group Name</label>
                        <select class="form-select" name="group_name" id="editGroupName" required>
                            <option value="" disabled>Select Group Name</option>
                            @foreach($contactGroups as $contactGroup)
                                <option value="{{ $contactGroup->name }}">{{ $contactGroup->name }}</option>
                            @endforeach
                        </select>
                    </div>
                    <div class="mb-3">
                        <label for="editMethodName" class="form-label">Method Name</label>
                        <select class="form-select" name="method_name" id="editMethodName" required>
                            <option value="" disabled>Select Method Name</option>
                            @foreach($methodNames as $methodName)
                                <option value="{{ $methodName->method_name }}">{{ $methodName->method_name }}</option>
                            @endforeach
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection

@section('script')
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

// edit script
document.querySelectorAll('.edit-icon').forEach(function (editButton) {
    editButton.addEventListener('click', function () {
        const queryMappingId = this.getAttribute('data-id');
        const editUrl = `/query_mapping/${queryMappingId}`;

        // Fetch the data for the selected query mapping
        fetch(editUrl)
            .then(response => response.json())
            .then(data => {
                // Populate the modal fields
                document.getElementById('editGroupName').value = data.group_name;
                document.getElementById('editMethodName').value = data.method_name;

                // Set the form action URL
                document.getElementById('editQueryMappingForm').action = editUrl;

                // Show the modal
                const editModal = new bootstrap.Modal(document.getElementById('editQueryMappingModal'));
                editModal.show();
            })
            .catch(error => console.error('Error fetching query mapping data:', error));
    });
});

</script>
@endsection