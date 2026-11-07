@props(['kicker' => null, 'title' => '', 'subtitle' => null])
<div class="lk-page-title">
    <div>
        @if($kicker)<span class="lk-kicker">{{ $kicker }}</span>@endif
        <h1>{{ $title }}</h1>
        @if($subtitle)<p>{{ $subtitle }}</p>@endif
    </div>
    @if($slot->isNotEmpty())
        <div class="lk-page-title-actions">{{ $slot }}</div>
    @endif
</div>
