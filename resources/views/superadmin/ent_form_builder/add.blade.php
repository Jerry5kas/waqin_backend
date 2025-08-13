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

    <div class="card">
        <div class="card-body">
            <div class="mb-3">
                <label class="form-label">Form Name</label>
                <input type="text" class="form-control" name="FormName" placeholder="Form Name">
            </div>

            <div class="mb-3">
                <label class="form-label">Select Business</label>
                <select class="js-example-basic-multiple form-control w-100" onchange="getstatusbybusiness()" id="Bussiness" name="Bussiness[]" multiple="multiple">
                    <option value="">Select Business</option>
                    @foreach($result['bussiness'] as $B)
                        <option value="{{ $B->id }}">{{ $B->name }}</option>
                    @endforeach
                </select>
            </div>

            <div class="mb-3">
                <label class="form-label">Select Status</label>
                <select class="js-example-basic-multiple form-control w-100" id="Status" name="status_master">
                    <option value="">Select Status</option>
                    <option value="">Not Applicable</option>
                </select>
            </div>

            <div class="mb-3">
                <label class="form-label">Drag & Drop the required fields from rightside menu</label>
                <div id="build-wrap"></div>
                <div class="d-flex justify-content-end mt-3">
                    <button type="button" id="saveData" class="btn btn-primary">Submit</button>
                </div>
            </div>
        </div>
    </div>
</div>
@endsection

@section('script')
<script>
function getstatusbybusiness() {
    const selectElement = document.getElementById('Bussiness');
    const selectedBusinessId = Array.from(selectElement.selectedOptions).map(option => option.value);

    $.post(
        '{{ url("api/getstatus") }}',
        {
            business_id: selectedBusinessId,
            _token: $('meta[name="csrf-token"]').attr('content')
        },
        function (data) {
            if (data && Array.isArray(data.data)) {
                $('#Status').empty().append('<option value="">Select Status</option><option value="">Not Applicable</option>');
                $.each(data.data, function (key, val) {
                    $('#Status').append('<option value="' + val.id + '">' + val.name + '</option>');
                });
            } else {
                console.error("Unexpected data format:", data);
            }
        }
    ).fail(function (jqXHR, textStatus, errorThrown) {
        console.error('Error:', textStatus, errorThrown);
    });
}

$(document).ready(function () {
    $('.js-example-basic-multiple').select2();

    const fieldTypes = ['text', 'textarea', 'select', 'number', 'file', 'date', 'checkbox-group', 'radio-group', 'autocomplete', 'button', 'hidden', 'paragraph', 'header'];
    const phpArray = @json($result['rules']);
    let selectOptions = {};
    phpArray.forEach(value => {
        selectOptions[value] = value;
    });

    let customFieldAttributes = {};
    fieldTypes.forEach(type => {
        customFieldAttributes[type] = {
            DataType: {
                label: 'DataType',
                value: '',
                placeholder: 'Enter Data Type'
            },
            QueryRule: {
                label: 'Select Query Rule',
                type: 'select',
                options: { '': 'Select Query Rule', ...selectOptions },
                value: ''
            }
        };
    });

    const formBuilder = $('#build-wrap').formBuilder({ typeUserAttrs: customFieldAttributes });

    document.getElementById('saveData').addEventListener('click', () => {
        const result = formBuilder.actions.save();
        const FormName = $('input[name="FormName"]').val();
        const Bussiness = $('#Bussiness').val();
        const status_master = $('#Status').val();

        $.post(
            '{{ route("saveentformbuilder") }}',
            {
                FormName: FormName,
                Bussiness: Bussiness,
                status_master: status_master,
                FormData: JSON.stringify(result),
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function (data) {
                alert(data.msg);
                if (data.success) {
                    location.reload();
                }
            },
            'json'
        );
    });
});
</script>
@endsection
