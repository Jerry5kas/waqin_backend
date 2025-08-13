<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class MigrateOldtoNewController extends Controller
{
    public function migrateAllData(Request $request)
    {
        DB::beginTransaction();

        try {
            // Migrate invoice_or_proposals → documents & bill_items
            $oldInvoices = DB::table('invoice_or_proposals')->get();

            foreach ($oldInvoices as $invoice) {
                // Insert into documents
                $documentId = DB::table('documents')->insertGetId([
                    'type'                  => $invoice->type,
                    'serial_number'         => $invoice->uid,
                    'customer_id'           => $invoice->customer_id,
                    'employee_id'           => $invoice->emp_id,
                    'ref_invoice'           => $invoice->ref_invoice ?? null,
                    'ref_order_no'          => null,
                    'description'           => $invoice->description,
                    'total_amount'          => $invoice->totalamt ?? $invoice->Amt ?? 0,
                    'net_amount'            => $invoice->totalamt ?? 0,
                    'pending_amount'        => $invoice->pending_amt ?? 0,
                    'discount'              => is_numeric($invoice->discount) ? $invoice->discount : 0,
                    'advance'               => is_numeric($invoice->advance) ? $invoice->advance : 0,
                    'delivery_date'         => $invoice->delivery_date,
                    'discount_precentage'   => is_numeric($invoice->discountpercentage) ? $invoice->discountpercentage : 0,
                    'payment_mode'          => $invoice->paymentmode,
                    'discount_type'         => null,
                    'total_items'           => 1,
                    'total_qty'             => is_numeric($invoice->Qty) ? $invoice->Qty : 0,
                    'total_gst'             => 0,
                    'discount_amount'       => 0,
                    'created_at'            => $invoice->created_at,
                    'updated_at'            => $invoice->updated_at,
                ]);

                // Insert into bill_items (basic mapping, assumes single item per invoice)
                DB::table('bill_items')->insert([
                    'document_id'       => $documentId,
                    'item_name'         => $invoice->itemname ?? $invoice->item,
                    'qty'               => is_numeric($invoice->Qty) ? $invoice->Qty : 1,
                    'mrp'               => is_numeric($invoice->Mrp) ? $invoice->Mrp : 0,
                    'offer'             => is_numeric($invoice->offers) ? $invoice->offers : 0,
                    'amount'            => is_numeric($invoice->Amt) ? $invoice->Amt : 0,
                    'total_amount'      => is_numeric($invoice->totalamt) ? $invoice->totalamt : 0,
                    'employee_percentage' => null,
                    'product_id'        => is_numeric($invoice->product_id) ? $invoice->product_id : null,
                    'service_id'        => is_numeric($invoice->service_id) ? $invoice->service_id : null,
                    'created_at'        => $invoice->created_at,
                    'updated_at'        => $invoice->updated_at,
                ]);
            }

            // Migrate tax → tax_details
            $oldTaxes = DB::table('tax')->get();

            foreach ($oldTaxes as $tax) {
                // Find document by serial_number (old uid)
                $document = DB::table('documents')->where('serial_number', $tax->uid)->first();

                DB::table('tax_details')->insert([
                    'document_id'    => $document->id ?? null,
                    'item_name'      => $tax->itemname ?? $tax->item,
                    'taxable_value'  => is_numeric($tax->taxable_value) ? $tax->taxable_value : 0,
                    'cgst'           => is_numeric($tax->cgst) ? $tax->cgst : 0,
                    'cgst_percent'   => is_numeric($tax->cgstAmt_percent) ? $tax->cgstAmt_percent : 0,
                    'sgst'           => is_numeric($tax->sgst) ? $tax->sgst : 0,
                    'sgst_percent'   => is_numeric($tax->sgstamt) ? $tax->sgstamt : 0,
                    'total_gst'      => is_numeric($tax->totalgst) ? $tax->totalgst : 0,
                    'product_id'     => is_numeric($tax->product_id) ? $tax->product_id : null,
                    'service_id'     => is_numeric($tax->service_id) ? $tax->service_id : null,
                    'created_at'     => $tax->created_at,
                    'updated_at'     => $tax->updated_at,
                ]);
            }

            // Migrate attachments (old) → attachments (new), match serial_number
            $oldAttachments = DB::table('attachments')->get();

            foreach ($oldAttachments as $attachment) {
                // Find document by serial_number
                $document = DB::table('documents')->where('serial_number', $attachment->uid)->first();

                DB::table('attachments')->insert([
                    'document_id' => $document->id ?? null,
                    'customer_id' => $attachment->customer_id,
                    'path'        => $attachment->path,
                    'status'      => $attachment->status,
                    'created_at'  => $attachment->created_at,
                    'updated_at'  => $attachment->updated_at,
                ]);
            }

            DB::commit();
            return response()->json(['message' => 'Migration completed successfully!'], 200);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }
}
