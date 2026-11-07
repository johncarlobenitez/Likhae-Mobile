<footer class="sl-footer">
    <p>&copy; {{ date('Y') }} LIKHAE Marketplace &middot; Seller Center</p>
    <nav aria-label="Seller footer links">
        <a href="{{ route('seller.messages') }}">Seller Support</a>
        <a href="{{ route('seller.store', ['tab' => 'settings']) }}">Store Settings</a>
        <a href="{{ route('seller.account', ['tab' => 'security']) }}">Security</a>
    </nav>
</footer>
