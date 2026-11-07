@props([
    'label',
    'value',
    'change' => null,
    'direction' => 'up',
    'icon' => 'chart',
])

@php
    $icons = [
        'sales' => '<path d="M3 7h18v13H3z"/><path d="M3 10h18"/><path d="M7 16h4"/>',
        'orders' => '<path d="M6 3h12l2 4v14H4V7z"/><path d="M4 7h16"/><path d="M9 12h6"/><path d="M9 16h4"/>',
        'revenue' => '<path d="M12 2v20"/><path d="M17 6H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>',
        'finance' => '<path d="M4 6h16v12H4z"/><path d="M7 10h4"/><path d="M7 14h2"/><path d="M15 10h2"/><path d="M15 14h2"/>',
        'products' => '<path d="M4 7.5 12 3l8 4.5v9L12 21l-8-4.5z"/><path d="M4 7.5l8 4.5 8-4.5"/><path d="M12 12v9"/>',
        'inventory' => '<path d="M4 5h16v4H4z"/><path d="M6 9v10h12V9"/><path d="M9 13h6"/><path d="M9 16h4"/>',
        'shipping' => '<path d="M3 6h11v11H3z"/><path d="M14 10h4l3 3v4h-7z"/><circle cx="7" cy="19" r="2"/><circle cx="18" cy="19" r="2"/>',
        'chart' => '<path d="M4 19V9"/><path d="M10 19V5"/><path d="M16 19v-7"/><path d="M22 19H2"/>',
    ];

    $iconPath = $icons[$icon] ?? $icons['chart'];
    $isDown = $direction === 'down';
@endphp

<article class="sl-stat-card" aria-label="{{ $label }}: {{ $value }}">
    <div class="sl-stat-top">
        <span class="sl-stat-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" focusable="false">{!! $iconPath !!}</svg>
        </span>
        @if ($change)
            <span class="sl-stat-change {{ $isDown ? 'is-down' : 'is-up' }}">
                {{ $isDown ? '↓' : '↑' }} {{ $change }}
            </span>
        @endif
    </div>
    <div class="sl-stat-body">
        <p class="sl-stat-label">{{ $label }}</p>
        <strong class="sl-stat-value">{{ $value }}</strong>
    </div>
</article>
