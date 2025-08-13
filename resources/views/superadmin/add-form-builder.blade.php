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
    <div class="card">
        <div class="card-body">
            <div class="mb-3">
                <label for="exampleFormControlInput1" class="form-label">Form Name</label>
                <input type="text" class="form-control" name="FormName" id="exampleFormControlInput1"
                    placeholder="Form Name">
            </div>
            <div class="mb-3">
                <label for="" class="form-label">Select Bussiness</label>
                <select class="js-example-basic-multiple form-control w-100" onchange="getstatusbybusiness()" id="Bussiness" name="Bussiness[]"
                    multiple="multiple">
                    <option value="">Select Business</option>
                    @foreach($result['bussiness'] as $B)
                    <option value="{{$B->id}}">{{$B->name}}</option>
                    @endforeach
                </select>
            </div>
            <div class="mb-3">
                <label for="" class="form-label">Select Status</label>
                <select class="js-example-basic-multiple form-control w-100" id="Status" name="status_master">
                    <option value="">Select Status</option>
                    <option value="">Not Applicable</option>
                </select>
            </div>
            <div class="mb-3">
                <label for="" class="form-label">Drag & Drop the required fields from rightside menu</label>
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
    function getstatusbybusiness(){
        //debugger;
    const selectElement = document.getElementById('Bussiness');
    const selectedBusinessId = Array.from(selectElement.selectedOptions).map(option => option.value);
    $.post(
            'api/getstatus',
            {
                business_id: selectedBusinessId,
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function(data) {
                console.log("Data received:", data); // Log the received data
                
                // Check if data is an object and has a data key
                if (data && Array.isArray(data.data)) {
                    // Clear previous form elements
                    $('#Status').empty();
                    // Call the function to append form elements
                    $.each(data.data , function(key,val){
console.log(key);
$('#Status').append('<option value="'+val.id+'">'+val.name+'</option>','<option value="">Not Applicable</option>');

                    })
                } else {
                    console.error("Unexpected data format:", data); // Log an error if the data format is unexpected
                }
            }
        ).fail(function(jqXHR, textStatus, errorThrown) {
            console.error('Error:', textStatus, errorThrown); // Log any errors
        });
    

}
    $(document).ready(function () {

    $('.js-example-basic-multiple').select2();
    var fieldTypes = [
    'text', 'textarea', 'select', 'number', 'file', 'date', 'checkbox-group',
    'radio-group', 'autocomplete', 'button', 'hidden', 'paragraph', 'header'
    // Add more field types if needed
  ];
 
  var customFieldAttributes = {};
  
  var phpArray = <?php echo json_encode($result['rules']); ?>;
  // Convert the PHP array into options for the select field
  var selectOptions = {};
  phpArray.forEach(function(value, index) {
    selectOptions[value] = value; // Dynamically create options from PHP array
  });
  // Loop through each field type and add the custom attribute
  fieldTypes.forEach(function(type) {
  customFieldAttributes[type] = {
    // Text input for DataType
    DataType: {
      label: 'DataType',  // Label for the text input
      value: '',  // Default value
      placeholder: 'Enter Data Type'  // Placeholder text
    },
    // Select dropdown for Custom Select Attribute
    QueryRule: {
      label: 'Select Query Rule',  // Label for the select dropdown
      type: 'select',  // Type of input (select dropdown)
      options: {  // Options for the dropdown
        '': 'Select Query Rule',  // Empty value to show the placeholder
        ...selectOptions  // Spread existing options
      },
      value: ''  // Set default value to empty
    }
  };
});
 
  // Initialize the form builder with the custom field attributes for all field types
  var options = {
    typeUserAttrs: customFieldAttributes
  };
  
 
  var formBuilder = $('#build-wrap').formBuilder(options);

    document.getElementById('saveData').addEventListener('click', () => {
        const result = formBuilder.actions.save();
        const FormName = $('input[name="FormName"]').val();
        const Bussiness = $('#Bussiness').val();
        const status_master = $('#Status').val();

        $.post(
            'saveformbuilder',
            {
                FormName: FormName,
                Bussiness: Bussiness,                               
                status_master: status_master,                               
                FormData: JSON.stringify(result),
                _token: $('meta[name="csrf-token"]').attr('content')
            },
            function (data) {
                if (data.success == true) {
                    alert(data.msg)
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
    });
});
</script>
@endsection