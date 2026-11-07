@props([
    'label',
    'value',
    'detail' => null,
    'trend' => null,
    'icon' => 'chart',
    'tone' => 'blue',
    'href' => null,
])

@php
    $icons = [
        'users' => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
        'orders' => '<path d="M6 3h12l2 4v14H4V7z"/><path d="M4 7h16M9 11h6"/>',
        'flag' => '<path d="M5 21V4m0 0h11l-2 4 2 4H5"/>',
        'case' => '<path d="M4 7h16v13H4zM9 7V4h6v3M4 12h16"/>',
        'money' => '<circle cx="12" cy="12" r="9"/><path d="M16 8h-5a3 3 0 0 0 0 6h2a3 3 0 0 1 0 6H8M12 5v3m0 12v-3"/>',
        'truck' => '<path d="M3 6h11v11H3zM14 10h4l3 3v4h-7z"/><circle cx="7" cy="19" r="2"/><circle cx="18" cy="19" r="2"/>',
        'chart' => '<path d="M4 20V10m6 10V4m6 16v-7m4 7H2"/>',
    ];
    $tag = $href ? 'a' : 'article';
@endphp

<{{ $tag }} @if($href) href="{{ $href }}" @endif {{ $attributes->class(['ad-stat', 'is-'.$tone]) }}>
    <span class="ad-stat-icon"><svg viewBox="0 0 24 24" aria-hidden="true">{!! $icons[$icon] ?? $icons['chart'] !!}</svg></span>
    <span class="ad-stat-copy">
        <span class="ad-stat-label">{{ $label }}</span>
        <strong>{{ $value }}</strong>
        @if($detail || $trend)
            <small>@if($trend)<b>{{ $trend }}</b>@endif {{ $detail }}</small>
        @endif
    </span>
</{{ $tag }}>
