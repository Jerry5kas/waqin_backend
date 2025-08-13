@extends('layouts.superadmin')
@section('content')
<?php
    $business_ids = explode(',', $result['FrmData']->bussiness_ids);
?>
<div class="card">
    <div class="card-body">
        <div class="row">
            <div class="mb-3">
                <label for="exampleFormControlInput1" class="form-label">Form Name</label>
                <input type="text" class="form-control" value="{{ $result['FrmData']->name }}" name="FormName"
                    id="exampleFormControlInput1" placeholder="ex: Basic Details">
            </div>

            <div class="mb-3">
                <label for="" class="form-label">Select Business</label>
                <select class="js-example-basic-multiple form-control" id="Business" name="Business[]"
                    multiple="multiple">
                    @foreach($result['bussiness'] as $B)
                        <option value="{{ $B->id }}" {{ in_array($B->id, $business_ids) ? 'selected' : '' }}>{{ $B->name }}</option>
                    @endforeach
                </select>
            </div>

            <div id="build-wrap_edit"></div>
            <div class="saveDataWrap d-flex justify-content-end mt-3">
                <button id="saveData" type="button" class="btn btn-primary">Save</button>
            </div>
        </div>
    </div>
</div>
@endsection

@section('script')
<script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.11.4/jquery-ui.min.js"></script>
<script src="https://formbuilder.online/assets/js/form-builder.min.js"></script>
<script src="https://formbuilder.online/assets/js/form-render.min.js"></script>
<script type="text/javascript">
    $(document).ready(function () {
        $('.js-example-basic-multiple').select2();
    });

    jQuery(function ($) {
        var $fbTemplate1 = $('#build-wrap_edit');
        var fieldTypes = [
            'text', 'textarea', 'select', 'number', 'file', 'date', 'checkbox-group',
            'radio-group', 'autocomplete', 'button', 'hidden', 'paragraph', 'header'
        ];

        var customFieldAttributes = {};

        // Convert PHP array to JavaScript array for select options
        var phpArray = @json($result['rules']);
        var selectOptions = {};
        phpArray.forEach(function(value) {
            selectOptions[value] = value;
        });

        fieldTypes.forEach(function(type) {
            customFieldAttributes[type] = {
                DataType: {
                    label: 'DataType',
                    value: '',
                    placeholder: 'Enter Data Type'
                },
                QueryRule: {
                    label: 'Select Query Rule',
                    type: 'select',
                    options: {
                        '': 'Select Query Rule',
                        ...selectOptions
                    },
                    value: ''
                }
            };
        });

        // Retrieve and parse formData
        var formData = @json($result['FrmData']->form);
        
        // Check if formData exists
        if (formData) {
            // Initialize formBuilder
            var formBuilder = $fbTemplate1.formBuilder({
                formData: formData,
                typeUserAttrs: customFieldAttributes
            });

            // Save form data on button click
            $('#saveData').click(function () {
                // Check if formBuilder instance exists
                if (formBuilder) {
                    const result = formBuilder.actions.getData();
                    const FormName = $('input[name="FormName"]').val();
                    const Business = $('#Business').val();

                    $.post("editformbuilder", {
                        FormName: FormName,
                        id: {{ $result['FrmData']->id }},
                        Business: Business,
                        FormData: JSON.stringify(result),
                        "_token": $('meta[name="csrf-token"]').attr('content')
                    }, function (data) {
                        alert(data.msg);
                        if (data.success) {
                            location.reload();
                        }
                    }, "json");
                } else {
                    console.error("FormBuilder instance is not initialized.");
                }
            });
        } else {
            console.error("Form data is undefined or invalid.");
        }
    });
</script>
@endsection
