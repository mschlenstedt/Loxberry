package LoxBerry::WebLogin::Apache;

use strict;
use warnings;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Access ();
use Apache2::Connection ();
use Apache2::URI ();
use Apache2::Log ();
use APR::Table ();
use Apache2::Const -compile => qw(OK DECLINED HTTP_SEE_OTHER HTTP_UNAUTHORIZED HTTP_FORBIDDEN HTTP_BAD_REQUEST HTTP_METHOD_NOT_ALLOWED HTTP_SERVICE_UNAVAILABLE);
use JSON::PP qw(decode_json);
use URI::Escape qw(uri_escape uri_unescape);
use LoxBerry::WebLogin;

use constant COOKIE => '__Host-LBSession';

sub settings {
    my ($r) = @_;
    my $home = $r->dir_config('WebLoginHome');
    my $origin = $r->dir_config('WebLoginOrigin') || '';
    die 'WebLoginHome and a canonical HTTPS WebLoginOrigin are required'
        unless $home && $origin =~ m{\Ahttps://(?:[a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\])(?::[0-9]{1,5})?\z};
    return ($home, $origin);
}

sub store {
    my ($r) = @_;
    my ($home) = settings($r);
    return LoxBerry::WebLogin->new(
        state => "$home/data/system/weblogin", users => "$home/config/system/htusers.dat",
        htpasswd => $r->dir_config('WebLoginHtpasswd') || '/usr/bin/htpasswd');
}

sub cookie {
    my ($r) = @_;
    my @tokens = ($r->headers_in->get('Cookie') || '') =~ /(?:\A|;\s*)__Host-LBSession=([^;]*)/g;
    return unless @tokens == 1 && $tokens[0] =~ /\A[0-9a-f]{64}\z/;
    return $tokens[0];
}

sub has_cookie { return ($_[0]->headers_in->get('Cookie') || '') =~ /(?:\A|;\s*)__Host-LBSession=/ }

sub secure {
    # construct_url obtains the scheme from Apache/mod_ssl, not X-Forwarded-Proto.
    # TLS termination at an untrusted forward proxy is deliberately unsupported.
    return $_[0]->construct_url('/') =~ m{\Ahttps://};
}

sub no_cache {
    my ($r) = @_;
    $r->err_headers_out->set('Cache-Control' => 'no-store');
    $r->err_headers_out->set('Pragma' => 'no-cache');
    $r->err_headers_out->set('Referrer-Policy' => 'no-referrer');
}

sub set_cookie {
    my ($r, $token) = @_;
    $r->err_headers_out->set('Set-Cookie' => COOKIE . '=' . ($token || '') .
        '; Path=/; Secure; HttpOnly; SameSite=Strict' . ($token ? '' : '; Max-Age=0'));
}

sub redirect {
    my ($r, $url) = @_;
    no_cache($r);
    $r->err_headers_out->set(Location => $url);
    return Apache2::Const::HTTP_SEE_OTHER;
}

sub browser_navigation {
    my ($r) = @_;
    return 0 unless $r->method eq 'GET' || $r->method eq 'HEAD';
    my $mode = $r->headers_in->get('Sec-Fetch-Mode');
    # Accept: text/html is also used by legacy machines. Only browser-generated
    # Fetch Metadata selects the redirect; all other clients retain a challenge.
    return defined($mode) && $mode eq 'navigate';
}

sub same_origin {
    my ($r, $origin) = @_;
    my $fetch = $r->headers_in->get('Sec-Fetch-Site') || '';
    return 0 if $fetch eq 'cross-site' || $fetch eq 'same-site';
    my $sent = $r->headers_in->get('Origin');
    return $sent eq $origin if defined $sent;
    my $ref = $r->headers_in->get('Referer') || '';
    return index($ref, "$origin/") == 0;
}

sub access {
    my ($r) = @_;
    my $status = eval { _access($r) };
    return $status unless $@;
    # Never fall back to unauthenticated/Basic access when the session store fails.
    $r->log_error('LoxBerry WebLogin: session access failed');
    return Apache2::Const::HTTP_SERVICE_UNAVAILABLE;
}

sub _access {
    my ($r) = @_;
    # Preserve preemptive AND challenge/retry Basic Auth for existing clients.
    # Apache's original provider, htaccess, authorization, and request body remain.
    return Apache2::Const::DECLINED if defined $r->headers_in->get('Authorization');
    my (undef, $origin) = settings($r);
    my $s;
    if (has_cookie($r) && secure($r)) {
        $s = store($r)->session(cookie($r));
    }
    if ($s && $s->{user} ne '') {
        if ($r->method !~ /\A(?:GET|HEAD|OPTIONS)\z/ && !same_origin($r, $origin)) {
            return Apache2::Const::HTTP_FORBIDDEN;
        }
        return Apache2::Const::HTTP_FORBIDDEN
            if ($r->headers_in->get('Sec-Fetch-Site') || '') eq 'cross-site';
        $r->pnotes('lb_session_user' => $s->{user});
        $r->user($s->{user});
        $r->ap_auth_type('LoxBerrySession');
        no_cache($r);
        return Apache2::Const::OK;
    }
    if (browser_navigation($r)) {
        my $destination = LoxBerry::WebLogin::safe_return($r->unparsed_uri);
        return redirect($r, "$origin/login?return=" . uri_escape($destination));
    }
    # An expired/forged cookie must not inherit the local-request exemption.
    if (has_cookie($r)) {
        no_cache($r);
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }
    return Apache2::Const::DECLINED;
}

sub authenticate {
    my ($r) = @_;
    return Apache2::Const::DECLINED unless ($r->auth_type || '') eq 'LoxBerrySession';
    return Apache2::Const::DECLINED if defined $r->headers_in->get('Authorization');
    my $user = $r->pnotes('lb_session_user');
    return Apache2::Const::HTTP_UNAUTHORIZED unless $user;
    $r->user($user);
    $r->ap_auth_type('LoxBerrySession');
    return Apache2::Const::OK;
}

sub parse_form {
    my ($body) = @_;
    die 'Oversized form' if length($body) > 4096;
    my %form;
    for my $pair (split /&/, $body) {
        my ($key, $value) = split /=/, $pair, 2;
        $value //= '';
        for ($key, $value) {
            die 'Invalid form encoding' if /%(?![0-9a-fA-F]{2})/;
            tr/+/ /;
            $_ = uri_unescape($_);
        }
        die 'Duplicate form field' if exists $form{$key};
        $form{$key} = $value;
    }
    return \%form;
}

sub escape_html {
    my ($s) = @_;
    $s //= '';
    $s =~ s/&/&amp;/g; $s =~ s/</&lt;/g; $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g; $s =~ s/'/&#39;/g;
    return $s;
}

sub slurp {
    open my $fh, '<:raw', $_[0] or die 'Cannot read WebLogin resource';
    local $/; return <$fh>;
}

sub render {
    my ($r, %vars) = @_;
    my ($home) = settings($r);
    my $lang = 'en';
    my $config = eval { decode_json(slurp("$home/config/system/general.json")) };
    $lang = $config->{Base}{Lang} if $config && ($config->{Base}{Lang} || '') =~ /\A(?:en|de|nl)\z/;
    my $words = decode_json(slurp("$home/templates/system/weblogin/$lang.json"));
    my $html = slurp("$home/templates/system/weblogin/login.html");
    # Encode JSON Unicode for the byte-oriented Apache output; template placeholders
    # are escaped by default. Only these locally constructed HTML fragments are raw.
    require Encode;
    my %values = (map { $_ => Encode::encode('UTF-8', $words->{$_}) } keys %$words);
    @values{keys %vars} = values %vars;
    $values{lang} = $lang;
    $values{message} = $vars{message_key} ? $values{$vars{message_key}} : '';
    my $form;
    if ($vars{signed_in}) {
        $form = '<p class="session-user">' . escape_html($vars{user}) . '</p>' .
            '<a class="primary" href="' . escape_html($vars{return}) . '">' . escape_html($values{continue}) . '</a>' .
            '<form method="post" action="/login/logout"><input type="hidden" name="csrf" value="' . escape_html($vars{csrf}) . '">' .
            '<button class="secondary" type="submit">' . escape_html($values{logout}) . '</button></form>';
        $values{title} = $values{signed_in_title};
        $values{intro} = $values{signed_in_intro};
    } else {
        $form = '<form method="post" action="/login" autocomplete="on">' .
            '<input type="hidden" name="csrf" value="' . escape_html($vars{csrf}) . '">' .
            '<input type="hidden" name="return" value="' . escape_html($vars{return}) . '">' .
            '<label for="username">' . escape_html($values{username}) . '</label>' .
            '<input id="username" name="username" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" required maxlength="20" value="' . escape_html($vars{user}) . '">' .
            '<label for="password">' . escape_html($values{password}) . '</label>' .
            '<div class="password-field"><input id="password" name="password" type="password" autocomplete="current-password" required maxlength="1024">' .
            '<button id="toggle-password" class="reveal" type="button" aria-controls="password" aria-pressed="false" data-show="' . escape_html($values{show}) . '" data-hide="' . escape_html($values{hide}) . '" hidden>' . escape_html($values{show}) . '</button></div>' .
            '<button class="primary" type="submit">' . escape_html($values{login}) . '<span aria-hidden="true"> &rarr;</span></button></form>';
    }
    $html =~ s/\{\{([a-z_]+)\}\}/$1 eq 'form' ? $form : escape_html($values{$1})/ge;
    no_cache($r);
    $r->headers_out->set('Content-Security-Policy' => "default-src 'none'; style-src 'self'; img-src 'self'; script-src 'self'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'");
    $r->headers_out->set('X-Content-Type-Options' => 'nosniff');
    $r->headers_out->set('X-Frame-Options' => 'DENY');
    $r->content_type('text/html; charset=utf-8');
    $r->print($html) unless $r->header_only;
    return Apache2::Const::OK;
}

sub page {
    my ($r) = @_;
    my $status = eval { _page($r) };
    return $status unless $@;
    $r->log_error('LoxBerry WebLogin: login service failed');
    no_cache($r);
    return Apache2::Const::HTTP_SERVICE_UNAVAILABLE;
}

sub _page {
    my ($r) = @_;
    no_cache($r);
    my (undef, $origin) = settings($r);
    return Apache2::Const::HTTP_METHOD_NOT_ALLOWED unless $r->method =~ /\A(?:GET|HEAD|POST)\z/;
    # The original landing page is only a meta refresh. In opt-in mode it sends
    # visitors directly to the HTTPS form, including browsers navigating via HTTP
    # that do not send Fetch Metadata on an insecure origin.
    if ($r->uri eq '/' || $r->uri eq '/index.html') {
        return Apache2::Const::HTTP_METHOD_NOT_ALLOWED if $r->method eq 'POST';
        return redirect($r, "$origin/login");
    }
    # Only a configured HTTPS origin can issue sessions. Never infer a trusted
    # origin from Host, Forwarded, or X-Forwarded-* headers.
    unless (secure($r) && $r->construct_url('/') eq "$origin/") {
        return Apache2::Const::HTTP_FORBIDDEN if $r->method eq 'POST';
        return redirect($r, "$origin/login");
    }
    my $db = store($r);
    my $token = cookie($r);
    my $session = $db->session($token);
    my $query = eval { parse_form($r->args || '') };
    return Apache2::Const::HTTP_BAD_REQUEST unless $query;
    my $return = LoxBerry::WebLogin::safe_return($query->{return});
    my $error = '';
    my $user = '';
    if ($r->method eq 'POST') {
        return Apache2::Const::HTTP_FORBIDDEN unless same_origin($r, $origin);
        return Apache2::Const::HTTP_BAD_REQUEST unless
            ($r->headers_in->get('Content-Type') || '') =~ m{\Aapplication/x-www-form-urlencoded(?:;|\z)}i;
        my $body = '';
        while (1) {
            my $n = $r->read(my $part, 4097 - length($body));
            die 'Cannot read login request' unless defined($n) && $n >= 0;
            last if $n == 0;
            $body .= $part;
            return Apache2::Const::HTTP_BAD_REQUEST if length($body) > 4096;
        }
        my $form = eval { parse_form($body) };
        return Apache2::Const::HTTP_BAD_REQUEST unless $form;
        if ($r->uri eq '/login/logout') {
            return Apache2::Const::HTTP_FORBIDDEN unless $session && $session->{user} ne '' &&
                LoxBerry::WebLogin::constant_equal($session->{csrf}, $form->{csrf});
            $db->revoke($token);
            set_cookie($r, undef);
            return redirect($r, '/login');
        }
        return Apache2::Const::HTTP_FORBIDDEN unless $db->consume_login($token, $form->{csrf});
        $return = LoxBerry::WebLogin::safe_return($form->{return});
        $user = $form->{username} || '';
        if (!$db->allow_attempt($r->useragent_ip, $user)) {
            $error = 'rate_error';
            $r->status(429);
            $r->headers_out->set('Retry-After' => 300);
        } else {
            my $verified = $db->verify_password($user, $form->{password});
            if ($verified) {
                my ($new_token) = $db->create_session($user, $verified);
                set_cookie($r, $new_token);
                return redirect($r, $return);
            }
            $error = 'login_error';
        }
        $session = undef;
    }
    if ($session && $session->{user} ne '') {
        return render($r, signed_in => 1, csrf => $session->{csrf}, user => $session->{user}, return => $return);
    }
    unless ($session) {
        ($token, $session) = $db->create_session('');
        set_cookie($r, $token);
    }
    return render($r, csrf => $session->{csrf}, user => $user, return => $return, message_key => $error);
}

1;
