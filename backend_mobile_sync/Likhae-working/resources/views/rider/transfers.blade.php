@extends('layouts.rider.app')
@section('title', 'Inter-Hub Transfers - LIKHAE')
@section('content')
<div class="space-y-6">
    <header>
        <h1 class="text-2xl font-bold text-ink">Inter-hub transfers</h1>
        <p class="mt-2 text-sm text-muted">Only manifests assigned to your approved inter-logistics vehicle appear here. The origin hub scans each parcel before release, and the destination hub scans each parcel on arrival.</p>
    </header>
    @if(session('status'))<div class="border border-green-200 bg-green-50 p-4 text-sm font-semibold text-green-700">{{ session('status') }}</div>@endif
    @error('tracking')<div class="border border-red-200 bg-red-50 p-4 text-sm font-semibold text-red-700">{{ $message }}</div>@enderror
    @if(!$ready)
        <div class="border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">Inter-hub transport is not activated until Step 3/4 custody migrations are approved and installed.</div>
    @else
        <form method="GET" action="{{ route('rider.transfers') }}" class="grid gap-3 border border-line bg-surface p-4 sm:grid-cols-4 sm:items-end">
            <label class="text-xs font-semibold text-ink">Show
                <select name="view" class="mt-1 block min-h-10 w-full rounded-lg border border-line bg-page px-3 text-sm">
                    <option value="all" @selected($filters['view'] === 'all')>All transfers</option>
                    <option value="active" @selected($filters['view'] === 'active')>Active transfers</option>
                    <option value="history" @selected($filters['view'] === 'history')>History</option>
                </select>
            </label>
            <label class="text-xs font-semibold text-ink">From
                <input type="date" name="from" value="{{ $filters['from'] }}" class="mt-1 block min-h-10 w-full rounded-lg border border-line bg-page px-3 text-sm">
            </label>
            <label class="text-xs font-semibold text-ink">To
                <input type="date" name="to" value="{{ $filters['to'] }}" class="mt-1 block min-h-10 w-full rounded-lg border border-line bg-page px-3 text-sm">
            </label>
            <button class="min-h-10 rounded-lg bg-primary px-4 text-sm font-semibold text-white">Apply filters</button>
        </form>
        <div class="grid gap-3">
            @forelse($manifests as $manifest)
                <a class="border border-line bg-surface p-4" href="{{ route('rider.transfers.show', $manifest->id) }}">
                    <div class="flex justify-between"><strong>{{ $manifest->manifest_number }}</strong><span>{{ str($manifest->status)->headline() }}</span></div>
                    <p class="mt-2 text-sm text-muted">{{ $manifest->originLogisticsCenter?->business_name }} &rarr; {{ $manifest->destinationLogisticsCenter?->business_name }}</p>
                </a>
            @empty
                <div class="border border-dashed border-line p-8 text-center text-muted">No assigned transfer manifests.</div>
            @endforelse
        </div>
        {{ $manifests->links() }}
    @endif
</div>
@endsection
