<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Proposal {{ $document->serial_number }}</title>
  <style>@import url('https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css');</style>
</head>
<body class="p-4 text-gray-800">
  <div class="max-w-md mx-auto">
    <header class="mb-6">
      <h1 class="text-2xl font-bold">Proposal</h1>
      <p class="text-sm text-gray-600">#{{ $document->serial_number }}</p>
    </header>

    <section class="mb-4 text-sm">
      <p>{{ $document->description }}</p>
    </section>

    <!-- Similar structure to invoice for items and summary -->
    @include('pdf.invoice')
  </div>
</body>
</html>
