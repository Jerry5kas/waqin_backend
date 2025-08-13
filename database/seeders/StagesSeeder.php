<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Boutique\Models\Stages;

class StagesSeeder extends Seeder
{
    public function run()
    {
        $designStages = ['Stitching', 'Cutting', 'Finishing'];
        $patternStages = ['Embroidery'];

        foreach ($designStages as $stage) {
            Stages::firstOrCreate(['name' => $stage, 'type' => 'design']);
        }

        foreach ($patternStages as $stage) {
            Stages::firstOrCreate(['name' => $stage, 'type' => 'pattern']);
        }
    }
}
