@props(['application','href'=>null])
@php
    $status = strtolower((string) data_get($application, 'status', ''));
    $type = data_get($application, 'type');
    $name = data_get($application, 'name');
    $id = data_get($application, 'id');
@endphp
<article class="ad-application-card" data-filter-item>
    <div class="ad-application-main"><span class="ad-avatar is-soft">{{ $name ? mb_strtoupper(mb_substr($name,0,1)) : '?' }}</span><div><div class="ad-inline-title"><strong>{{ $name ?: 'Unknown applicant' }}</strong>@if($status)<span class="ad-status is-{{ $status }}">{{ str($status)->headline() }}</span>@endif</div>@if($id || $type)<p>{{ $id }}{{ $id && $type ? ' · ' : '' }}{{ $type }}</p>@endif</div></div>
    @if($href)<div class="ad-card-actions"><a class="ad-btn ad-btn-secondary ad-btn-sm" href="{{ $href }}">Review</a></div>@endif
</article>
