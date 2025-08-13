@extends('layouts.superadmin')

@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>ENT Form Builder</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">ENT Form Builder</li>
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
                <h5 class="card-title">ENT Form Builder</h5>
                <a class="btn btn-sm btn-primary" href="{{ route('add_ent_builder_form') }}">Add New ENT Form</a>
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
                                    href="{{ route('editentfrm') }}?frm={{ base64_encode(json_encode($form->id)) }}">
                                    <i class="bi bi-pencil-square"></i>
                                </a>
                                <button class="text-danger icon btn btn-link"
                                    onclick="deleteMasterData('ent_form_builder', {{ $form->id }})">
                                    <i class="bi bi-trash3-fill"></i>
                                </button>
                                @if ($form->status == 1)
                                <a class="icon ms-2" href="{{ route('entformbuilder.deactivate', $form->id) }}">
                                    <i class="bi bi-x-circle-fill" data-bs-toggle="tooltip" data-bs-placement="top"
                                        title="Deactivate"></i></a>
                                @else
                                <a class="icon ms-2" href="{{ route('entformbuilder.activate', $form->id) }}">
                                    <i class="bi bi-check2-circle" data-bs-toggle="tooltip" data-bs-placement="top"
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
    function deleteMasterData (tbl_name, id) {
        $.confirm({
            title: 'Confirm?',
            content: 'Are you sure you want to Delete..?',
            buttons: {
                confirm: function () {
                    $.post(
                        '{{ route("deleteMasterData") }}',
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
</script>
@endsection
