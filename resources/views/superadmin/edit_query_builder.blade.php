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
        <h1>Edit Query Builder</h1>
        <nav>
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="#">Home</a></li>
                <li class="breadcrumb-item active">Edit Query Builder</li>
            </ol>
        </nav>
    </div>

    <div class="card">
        <div class="card-body">
            <form id="queryBuilderForm" action="{{ route('query.builder.update', $query->id) }}" method="POST">
                @csrf
                <!-- Target Radio Buttons -->
                <div class="col-md-4 mb-3">
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="target" value="Master" {{ $query->target == 'Master' ? 'checked' : '' }}>
                        <label class="form-check-label">Master</label>
                    </div>
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="target" value="Tenant" {{ $query->target == 'Tenant' ? 'checked' : '' }}>
                        <label class="form-check-label">Tenant</label>
                    </div>
                </div>

                <!-- Source Name Dropdown -->
                <div class="col-md-4 mb-3">
                    <label for="source_name" class="form-label">Select Source Name</label>
                    <select id="source_name" name="source_name" class="form-control" required>
                        <option value="">Select Table</option>
                        @foreach($res['tableNames'] as $table)
                            <option value="{{ $table }}" {{ $table == $query->source_name ? 'selected' : '' }}>{{ $table }}</option>
                        @endforeach
                    </select>
                </div>

                <!-- Method Name Input -->
                <div class="col-md-4 mb-3">
                    <label for="method_name" class="form-label">Method Name</label>
                    <input type="text" id="method_name" name="method_name" class="form-control" value="{{ $query->method_name }}" required>
                </div>

                <!-- Query Builder -->
                <div id="query-builder-container" class="mb-3" style="display: none;">
                    <div id="builder"></div>
                </div>

                <!-- Submit Button -->
                <div class="col-md-4 mb-3">
                    <button type="submit" class="btn btn-primary">Update Query</button>
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
        // Load existing rules from the server for editing
        const existingRules = {!! json_encode(json_decode($query->rule)) !!};
        const existingTable = "{{ $query->source_name }}";
        const target = "{{ $query->target }}";

        // Function to initialize the query builder with filters and rules
        function loadQueryBuilder(filters, rules) {
            $('#builder').queryBuilder({
                filters: filters,
                rules: rules
            });
            $('#query-builder-container').show();
        }

        // Fetch columns for the selected table and load query builder with existing rules
        function fetchColumnsAndInitialize() {
            if (existingTable) {
                $.ajax({
                    url: '{{ route("query.builder.getColumns") }}',
                    type: 'GET',
                    data: { table: existingTable, target: target },
                    success: function (data) {
                        if (data && data.columns) {
                            const filters = data.columns.map(col => ({
                                id: col,
                                label: col,
                                type: 'string'
                            }));
                            loadQueryBuilder(filters, existingRules); // Initialize with filters and rules
                        } else {
                            alert('No columns found for the selected table.');
                        }
                    },
                    error: function (error) {
                        console.error('Error fetching columns:', error);
                    }
                });
            }
        }

        // Initialize query builder on load if table and target are set
        if (existingTable && target) {
            fetchColumnsAndInitialize();
        }

        // On form submission, capture and send the updated rules
        $('#queryBuilderForm').on('submit', function (e) {
            e.preventDefault();
            const rules = $('#builder').queryBuilder('getRules');
            
            if ($.isEmptyObject(rules)) {
                alert('Please define query rules.');
                return false;
            }

            $('<input>').attr({
                type: 'hidden',
                name: 'rules',
                value: JSON.stringify(rules)
            }).appendTo('#queryBuilderForm');

            this.submit();
        });
    });
</script>
@endsection
