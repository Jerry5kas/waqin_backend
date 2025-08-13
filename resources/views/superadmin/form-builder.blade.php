@extends('layouts.superadmin')
@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Form Builder</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Form Builder</li>
            </ol>
        </nav>
    </div>
    <!-- Success Message -->
    @if(session('success'))
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        {{ session('success') }}
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
    @endif

    <!-- Error Message -->
    @if(session('error'))
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        {{ session('error') }}
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
    @endif
    <div class="card">
        <div class="card-body">
            <div class="d-flex justify-content-between my-2">
                <h5 class="card-title">Form Builder</h5>
                <a class="btn btn-sm btn-primary" href="{{ route('add_builder_form') }}">Add New Form Builder</a>
            </div>
            <table class="table table-bordered formBuilder">
                <thead>
                    <tr>
                        <th>No</th>
                        <th>Form Name</th>
                        <th>Businesses</th>
                        <th>Status</th>
                        <th>Created Date</th>
                        <th>Action</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach($result['forms'] as $index => $form)
                    <tr>
                        <td>{{ $index + 1 }}</td>
                        <td>{{ $form->name }}</td>
                        <td>{{ $form->BussinessName }}</td>
                        <td>
                            @if ($form->status == 0)
                            <span class="badge bg-warning text-white fw-bold">Inactive</span>
                            @elseif ($form->status == 1)
                            <span class="badge bg-success text-white fw-bold">Active</span>
                            @else
                            Unknown Status
                            @endif
                        </td>
                        <td>{{ $form->created_on }}</td>
                        <td>
                            <div class="d-flex justify-content-center align-items-center">
                                <a class="fs-6 text-decoration-none ms-2"
                                    href="editfrm?frm={{base64_encode(json_encode($form->id))}}">
                                    <i class="bi bi-pencil-square"></i>
                                </a>
                                <button class="text-danger icon btn btn-link"
                                    onclick="deleteMasterData('form_builder', {{$form->id }})">
                                    <i class="bi bi-trash3-fill"></i>
                                </button>
                                @if ($form->status == 1)
                                <a class="icon ms-2" href="{{ route('formbuilder.deactivate', $form->id) }}"><i
                                        class="bi bi-x-circle-fill" data-bs-toggle="tooltip" data-bs-placement="top"
                                        title="Deactivate"></i></a>
                                @else
                                <a class="icon ms-2" href="{{ route('formbuilder.activate', $form->id) }}"><i
                                        class="bi bi-check2-circle" data-bs-toggle="tooltip" data-bs-placement="top"
                                        title="Activate"></i></a>
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
@endsection

@section('script')
<script type="text/javascript">
    function editMasterData (tbl_name, id) {
    $.post(
        'editMasterData',
        {
            tbl_name: tbl_name,
            id: id,
            _token: $('meta[name="csrf-token"]').attr('content')
        },
        function (data) {
            if (data.success == true) {
                window.location.href = './master_bussiness_edit/'
            }
        }
    )
}

function deleteMasterData (tbl_name, id) {
    //debugger;
    $.confirm({
        title: 'Confirm?',
        content: 'Are you sure you want to Delete..?',
        buttons: {
            confirm: function () {
                $.post(
                    'deleteMasterData',
                    {
                        tbl_name: tbl_name,
                        id: id,
                        _token: $('meta[name="csrf-token"]').attr('content')
                    },
                    function (data) {
                        if (data.success == true) {
                            alert(data.msg)
                        } else if (data.table) {
                            DependedDataConfirmtoDelete(data)
                        } else {
                            alert(data.msg)
                        }
                    },
                    'json'
                ).done(function () {
                    setTimeout(function () {
                        $('#overlay').fadeOut(300)
                    }, 500)
                    location.reload()
                })
            },
            cancel: function () {
                $.alert('Canceled!')
            }
        }
    })
}

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
                            Are you sure you want to ${action} this form?
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