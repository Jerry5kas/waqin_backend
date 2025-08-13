<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use PhpOffice\PhpSpreadsheet\Cell\DataValidation;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use PhpOffice\PhpSpreadsheet\IOFactory;
use PhpOffice\PhpSpreadsheet\Cell\Coordinate;
use PhpOffice\PhpSpreadsheet\NamedRange;
use PhpOffice\PhpSpreadsheet\Worksheet\Worksheet;
use Illuminate\Support\Facades\Response;

class LeadsController extends Controller
{
    //
    public function index()
{
    $leads = DB::table('leads_master')->where('is_deleted', 0)->get(); 
    return view('superadmin.leads-master', compact('leads'));
}

    public function downloadTemplate()
    {
        // 1. Get column list from leads_master
        $columns = Schema::getColumnListing('leads_master');
    
        // 2. Remove unwanted columns
        $excluded = ['id', 'status', 'is_deleted', 'created_at', 'updated_at'];
        $columns = array_values(array_diff($columns, $excluded));
    
        // 3. Get dropdown values from sales_and_services
        $services = DB::table('sales_and_services')
            ->whereNotNull('service')
            ->pluck('service')
            ->toArray();
    
        $products = DB::table('sales_and_services')
            ->whereNotNull('product_category')
            ->pluck('product_category')
            ->toArray();
    
        $dropdownOptions = array_unique(array_merge($services, $products));
        $dropdownOptions = array_values($dropdownOptions); // reset keys
    
        // 4. Create new spreadsheet
        $spreadsheet = new Spreadsheet();
        $mainSheet = $spreadsheet->getActiveSheet();
        $mainSheet->setTitle('Lead Template');
    
        // 5. Add headers dynamically
        foreach ($columns as $index => $column) {
            $columnLetter = Coordinate::stringFromColumnIndex($index + 1);
            $mainSheet->setCellValue($columnLetter . '1', $column);
        }
    
        // 6. Create hidden dropdown sheet
        $dropdownSheet = new Worksheet($spreadsheet, 'DropdownOptions');
        $spreadsheet->addSheet($dropdownSheet);
        foreach ($dropdownOptions as $rowIndex => $value) {
            $dropdownSheet->setCellValue('A' . ($rowIndex + 1), $value);
        }
    
        // 7. Add named range
        $namedRange = new NamedRange(
            'DropdownList',
            $dropdownSheet,
            '$A$1:$A$' . count($dropdownOptions)
        );
        $spreadsheet->addNamedRange($namedRange);
    
        // 8. Hide dropdown sheet
        $dropdownSheet->setSheetState(Worksheet::SHEETSTATE_HIDDEN);
    
        // 9. Find index of 'looking_for' header
        $lookingForIndex = array_search('looking_for', $columns);
            if ($lookingForIndex !== false) {
                $colLetter = Coordinate::stringFromColumnIndex($lookingForIndex + 1);

                // Apply dropdown validation to rows 2–100
                for ($row = 2; $row <= 100; $row++) {
                    $cell = $mainSheet->getCell($colLetter . $row);
                    $validation = $mainSheet->getCell($colLetter . $row)->getDataValidation();
                    $validation->setType(DataValidation::TYPE_LIST);
                    $validation->setErrorStyle(DataValidation::STYLE_STOP);
                    $validation->setAllowBlank(true);
                    $validation->setShowInputMessage(true);
                    $validation->setShowErrorMessage(true);
                    $validation->setShowDropDown(true); // 👈 REQUIRED to show the dropdown arrow!
                    $validation->setFormula1('=DropdownList');
                    $cell->setDataValidation($validation);
                }
            }
    
        // 10. Save and return the file
        $fileName = 'lead_template.xlsx';
        $filePath = storage_path($fileName);
        $writer = new Xlsx($spreadsheet);
        $writer->save($filePath);
    
        return response()->download($filePath)->deleteFileAfterSend(true);
    }

public function uploadExcel(Request $request)
{
    $request->validate([
        'excel_file' => 'required|mimes:xlsx,xls'
    ]);

    $file = $request->file('excel_file');
    $spreadsheet = IOFactory::load($file->getRealPath());
    $sheet = $spreadsheet->getActiveSheet();
    $rows = $sheet->toArray(null, true, true, true);

    // 1) Extract headers (kept as [ 'A'=>'name', 'B'=>'email', ... ])
    $headers = array_map('strtolower', array_map('trim', $rows[1]));
    unset($rows[1]);

    // 2) Ensure required columns exist
    $required = ['name','mobile','looking_for'];
    $missing = array_diff($required, $headers);
    if ($missing) {
        return back()->withErrors(['error' => 'Missing columns: '.implode(', ',$missing)]);
    }

    $toInsert = [];
    $errors   = [];

    foreach ($rows as $rowNum => $row) {
        // 3) Map letter-indexed row → header-indexed rowData
        $rowData = [];
        foreach ($headers as $colLetter => $field) {
            $rowData[$field] = trim($row[$colLetter] ?? '');
        }

        // 4) Skip completely empty rows
        if (empty($rowData['name']) 
         && empty($rowData['mobile']) 
         && empty($rowData['looking_for'])
        ) {
            continue;
        }

        // 5) Validate required on rowData
        $missingInRow = [];
        foreach ($required as $f) {
            if (empty($rowData[$f])) {
                $missingInRow[] = $f;
            }
        }
        if ($missingInRow) {
            // Redirect back *with* the errors
            return redirect()
                ->back()
                ->withInput()
                ->withErrors(['row_error' => "Row {$rowNum}: missing ".implode(', ', $missingInRow)]);
        }

        // 6) Set defaults and queue for insert
        $rowData['status']     = 1;
        $rowData['is_deleted'] = 0;
        $rowData['created_at'] = now();
        $rowData['updated_at'] = now();
        $toInsert[] = $rowData;
    }

    // 7) If any errors, show them
    if ($errors) {
        return back()->withErrors(['error' => implode('<br>',$errors)]);
    }

    // 8) Bulk insert
    if ($toInsert) {
        DB::table('leads_master')->insert($toInsert);
        return back()->with('success','Leads uploaded successfully.');
    }

    return back()->withErrors(['error'=>'No data to insert.']);
}

public function activate($id)
{
    DB::table('leads_master')->where('id', $id)->update(['status' => 1]);
    return redirect()->back()->with('success', 'Lead activated successfully.');
}

public function deactivate($id)
{
    DB::table('leads_master')->where('id', $id)->update(['status' => 0]);
    return redirect()->back()->with('success', 'Lead deactivated successfully.');
}

public function destroy($id)
{
    DB::table('leads_master')->where('id', $id)->update(['is_deleted' => 1]);
    return redirect()->back()->with('success', 'Lead deleted successfully.');
}

}
