<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Boutique\Models\Status;

class StatusSeeder extends Seeder
{
    public function run()
    {
        $statuses = ['Pending', 'In Process', 'Dispatched', 'Delivered', 'Cancelled','Held'];
        
        foreach ($statuses as $Status) {
            Status::firstOrCreate(['name' => $Status]);
        }
    }
}
