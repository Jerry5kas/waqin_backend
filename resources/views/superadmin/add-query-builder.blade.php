<style>
  .query-builder .rules-group-body .rule-container {
    display: flex;
    align-items: center;
    gap: 15px;
    margin-bottom: 10px;
    margin-top: 10px;
}
.query-builder .rule-container select,
.query-builder .rule-container input {
    width: auto;
    max-width: 200px;
}
</style>
@extends('layouts.superadmin')

@section('content')
<div class="container">
    <div class="pagetitle">
        <h1>Query Builder</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Query Builder</li>
            </ol>
        </nav>
    </div>

    <div class="card">
        <div class="card-body">
            <form id="queryBuilderForm" action="{{ route('query.builder.store') }}" method="POST">
                @csrf
                <div class="col-md-4 mb-3">
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="target" value="Master" checked="">
                        <label class="form-check-label" for="gridRadios1">Master</label>
                    </div>
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="target" value="Tenant">
                        <label class="form-check-label" for="gridRadios2">Tenant</label>
                    </div>
                </div>
                
                <!-- Master Dropdown -->
                <div class="col-md-4 mb-3 source-name-container" id="masterDropdown">
                    <label for="source_name_master" class="form-label">Select Source Name</label>
                    <select id="source_name_master" name="source_name" class="form-control source_name" required>
                        <option value="" selected>Select Table</option>
                        @foreach($res['tableNames'] as $table)
                            <option value="{{ $table }}">{{ $table }}</option>
                        @endforeach
                    </select>
                </div>
                
                <!-- Tenant Dropdown -->
                <div class="col-md-4 mb-3 source-name-container" id="tenantDropdown" style="display: none;">
                    <label for="source_name_tenant" class="form-label">Select Source Name</label>
                    <select id="source_name_tenant" name="source_name" class="form-control source_name" required>
                        <option value="" selected>Select Table</option>
                        @foreach($res['TenantTables'] as $col)
                            <option value="{{ $col->name }}">{{ $col->name }}</option>
                        @endforeach
                    </select>
                </div>

                <!-- Multi-select dropdown for selecting specific columns -->
                <div class="col-md-4 mb-3" id="selectedColumnsContainer" style="display: none;">
                    <label for="selected_columns" class="form-label">Select Columns</label>
                    <select id="selected_columns" name="selected_columns[]" class="form-control" multiple>
                        <!-- Options will be dynamically populated -->
                    </select>
                </div>

                <div class="col-md-4 mb-3">
                    <label for="method_name" class="form-label">Method Name</label>
                    <input type="text" id="method_name" name="method_name" class="form-control" placeholder="Enter Method Name" required>
                </div>
                
                <!-- Query builder and selected columns dropdown will appear here after table selection -->
                <div id="query-builder-container" class="mb-3" style="display: none;">
                    <div id="builder"></div>
                </div>

                <div class="col-md-4 mb-3 item-last">
                    <button type="submit" class="btn btn-primary">Save Query</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection

@section('script')
<script src="https://cdnjs.cloudflare.com/ajax/libs/jQuery-QueryBuilder/2.6.0/js/query-builder.standalone.min.js"></script>

<script>
   $(document).ready(function () {
    // Toggle dropdowns and required attributes based on selected target
    $("input[name='target']").on('change', function () {
        if ($(this).val() === 'Master') {
            $('#masterDropdown').show();
            $('#tenantDropdown').hide();
            $('#source_name_master').attr('required', true);
            $('#source_name_tenant').removeAttr('required');
        } else {
            $('#masterDropdown').hide();
            $('#tenantDropdown').show();
            $('#source_name_master').removeAttr('required');
            $('#source_name_tenant').attr('required', true);
        }
    });

    $("input[name='target']:checked").trigger('change');

    // Handle source name change for dynamic query builder setup
    $('.source_name').on('change', function () {
        var table = $(this).val();
        var target = $("input[name='target']:checked").val();

        $('#query-builder-container').hide();
        $('#builder').queryBuilder('destroy');
        $('#selectedColumnsContainer').hide(); // Hide initially

        if (table) {
            // Fetch columns for the selected table
            $.ajax({
                url: '{{ route("query.builder.getColumns") }}',
                type: 'GET',
                data: { table: table, target: target },
                success: function (data) {
                    console.log('Response from server:', data);

                    if (data && data.columns) {
                        // Populate the selected_columns dropdown
                        $('#selected_columns').empty(); // Clear existing options
                        data.columns.forEach(function (col) {
                            $('#selected_columns').append(
                                $('<option>', {
                                    value: col,
                                    text: col
                                })
                            );
                        });
                        $('#selectedColumnsContainer').show(); // Show the dropdown after populating
                        
                        // Initialize the query builder with the fetched columns
                        $('#query-builder-container').show();
                        $('#builder').queryBuilder({
                            filters: data.columns.map(function (col) {
                                return {
                                    id: col,
                                    label: col,
                                    type: 'string'
                                };
                            })
                        });
                    } else {
                        alert('No columns found for the selected table.');
                    }
                },
                error: function (error) {
                    console.error('Error fetching columns:', error);
                }
            });
        } else {
            $('#query-builder-container').hide();
            $('#selectedColumnsContainer').hide();
        }
    });

    // Submit form with rules
    $('#queryBuilderForm').on('submit', function (e) {
    e.preventDefault();

    var rules = $('#builder').queryBuilder('getRules');
    if ($.isEmptyObject(rules)) {
        alert('Please define query rules.');
        return false;
    }

    var selectedColumns = $('#selected_columns').val(); // This can be empty

    // Add rules as hidden input
    $('<input>').attr({
        type: 'hidden',
        name: 'rules',
        value: JSON.stringify(rules)
    }).appendTo('#queryBuilderForm');

    // Add selected_columns as hidden input only if columns are selected
    if (selectedColumns && selectedColumns.length > 0) {
        $('<input>').attr({
            type: 'hidden',
            name: 'selected_columns',
            value: JSON.stringify(selectedColumns)
        }).appendTo('#queryBuilderForm');
    }

    this.submit();
    });
});

</script>
@endsection
