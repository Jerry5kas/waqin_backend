use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CreateCustomersTableIfNotExists extends Migration
{
    public function up()
    {
        if (!Schema::hasTable('customers')) {
            DB::statement("
                CREATE TABLE customers (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255),
                    email VARCHAR(255) UNIQUE,
                    mobile VARCHAR(15),
                    another_mobile VARCHAR(15) NULL,
                    company VARCHAR(255) NULL,
                    gst VARCHAR(50) NULL,
                    profile_pic VARCHAR(255) NULL,
                    location VARCHAR(255) NULL,
                    dob DATE NULL,
                    status VARCHAR(50) DEFAULT 'active',
                    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    is_deleted TINYINT(1) DEFAULT 0
                )
            ");
        }
    }

    public function down()
    {
        Schema::dropIfExists('customers');
    }
}
