<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Illuminate\Http\Request;

class UsersController extends Controller
{

    public function EnrollCourses()
    {
        $courses = DB::table('courses')->get();
        // dd($courses);
        return view('user.courses', compact('courses'));
    }

    public function getCourseDetails($id)
    {
        // Get course details
        $data['course'] = DB::table('courses')
            ->select('courses.*')
            ->where('courses.id', $id)
            ->first();

        // Get chapters for the course
        $data['chapters'] = DB::table('chapters')
            ->join('courses', 'chapters.course_id', '=', 'courses.id')
            ->select('chapters.*')
            ->where('chapters.course_id', $id)
            ->get();

        return view('user.course-details', compact('data'));
    }



    public function onlineExam(Request $request)
    {
        $questionary = DB::table('chapter_question')
            ->where('id', 3)
            ->first();

        if (!$questionary) {
            return redirect()->back()->with('error', 'Chapter question not found.');
        }

        $data['id'] = $questionary->id;
        $data['course_id'] = $questionary->course_id;
        $data['chapter_id'] = $questionary->chapter_id;

        $decodeData = json_decode($questionary->questions, true);
        $questions = [];

        if ($decodeData === null) {
            return redirect()->back()->with('error', 'Invalid JSON data.');
        }
        foreach ($decodeData as $key => $value) {
            $questions[] = $value;
        }
        $data['questions'] = $questions;
        return view('user.exam', compact('data'));
    }
}
