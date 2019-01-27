
![nixcloud.email](logo/nixcloud.email.png)

`nixcloud.email` is a part of [nixcloud-webservices](https://github.com/nixcloud/nixcloud-webservices) and focuses on easily **operating a mailserver** or a **mail relay server**.

# Features:

* [x] IMAP support
* [x] POP3 support (optional)
* [x] Greylisting (optional)
* [x] Rspamd (optional)
     * We use this metric:

                score < 4  allow message
           4  < score < 6  greylist message
           6  < score < 15 add spam header
           15 < score       reject message
* [x] supports [nixcloud.TLS.md](nixcloud.TLS.md) (optional)
     * ACME TLS certificates
     * usersupplied certificates
     * selfsigned certifictes
* [x] Automatically extend `networking.firewall` with required ports
* [x] virtualMail user abstraction
     * define users/passwords declaratively using Nix
     * maildir folders
     * quota support
     * regular aliases
     * catchall aliases
* [x] DKIM Signing
* [x] Sieve
    * A simple standard script that moves spam
    * Allow user defined sieve scripts
* [x] SNI (https://en.wikipedia.org/wiki/Server_Name_Indication) support for dovecot2/postfix    
    * With SNI, when using IMAP/SMTP from Thunderbird, you can now configure the mailserver per domain as mail.example.com for bar@example.com and mail.example.org for foo@example.org and this works both for receiving and sending emails
* [x] meaningful mail server defaults for communication with gmail.com & similar
* [x] Mail relay abstraction
* [x] `nixcloud.email` scores 10/10 at https://www.mail-tester.com

See [implementation](../modules/services/email)

Upcoming features:

* Webmail support (Roundcube)
* Refactor `nixcloud.email.relay` into `nixcloud.email-relay`
* Advanced monitoring using https://github.com/nixcloud/nixcloud.monitoring
* Adding group aliases
* Rewrite sender mail address when forwarding (SRS) correctly
* Advanced logging

Thanks to the support of https://nlnet.nl!

# Limitations

* No support for shell users, only virtualUsers. This is by intention to reduce complexity in the backend.
* Using `nixcloud.email.enableTLS = true;` will not work with `services.nginx` out of the box, [see this](nixcloud.reverse-proxy.md#extramappings-examples).
* Managing users/passwords only possible by using the `nixcloud.email` abstraction, no shell tooling

# Configuration

## Basic example

    let
      ipAddress = "8.19.10.3";
      ipv6Address = "201:48:11:403::1:1";
    in {
      nixcloud.email= {
        enable = true;
        domains = [ "lastlog.de" "dune2.de" ];
        ipAddress = ipAddress;
        ip6Address = ipv6Address;
        fqdn = "mail.lastlog.de";
        users = [
          # see https://wiki.dovecot.org/Authentication/PasswordSchemes
          { name = "js"; domain = "lastlog.de"; password = "{SHA256-CRYPT}$<<<removed by qknight>>>"; }
          { name = "foo1"; domain = "dune2.de"; password = "{PLAIN}asdfasdfasdfasdf"; }
        ];
      };
      
    # If using the firewall
    # networking.firewall.allowedTCPPorts = [ 
    #   25 # enable smtp for other servers
    #   143 # Enable using imap
    #   587 # Enable smtp for users
    # ]
  ];

## DNS entries

In order to use `nixcloud.email` you need to setup your DNS server for your domain. Here is the example configuration for `mail.lastlog.de` mailserver.

### Reverse DNS entries

* 2a01:4f8:221:3744::1:30 mail.lastlog.de
* 88.198.101.30 mail.lastlog.de

### Forward DNS entries

DNS entries for lastlog.de

```
    $TTL 600
    @   IN SOA ns1.first-ns.de. postmaster.robot.first-ns.de. (
        2017121000   ; serial
        14400        ; refresh
        1800         ; retry
        600          ; expire
        86400 )      ; minimum

    @                        IN NS      ns1.first-ns.de.
    @                        IN NS      robotns2.second-ns.de.
    @                        IN NS      robotns3.second-ns.com.

    @                        IN A       78.47.100.188
    localhost                IN A       127.0.0.1
    mail                     IN A       88.198.101.30
    @                        IN AAAA    2a01:4f8:d15:2609::2
    mail                     IN AAAA    2a01:4f8:221:3744::1:30
    imap                     IN CNAME   mail
    pop                      IN CNAME   mail
    relay                    IN CNAME   mail
    smtp                     IN CNAME   mail
    webmail                  IN CNAME   mail
    @                        IN MX 10   mail
    mail                     IN MX 10   mail
    @                        IN TXT     "v=spf1 mx a ptr ip4:88.198.101.30 ip6:2a01:4f8:221:3744::1:30 ?all"
    mail._domainkey          IN TXT     "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeQIgtFVgJCI15VoBAvYEbLSn8wS7VWWC7j6fNp8tkrLsliL2zOJg6OZ/mFMXHLZZBQO3VvpK8ZVX9Pzfx4UKSS4AmIS/ZOFIq7PWdy1F3X1J55p6JYodcBKFPDa9akiJ/bx0ovSUY3bgABYNIlh1HTi9BotKb6r/hATZ7YlpFXwIDAQAB"
```

DNS entries for dune2.de
```
$TTL 600
@   IN SOA ns1.first-ns.de. postmaster.robot.first-ns.de. (
    2018102900   ; serial
    14400        ; refresh
    1800         ; retry
    600          ; expire
    86400 )      ; minimum
 
@                        IN NS      robotns3.second-ns.com.
@                        IN NS      robotns2.second-ns.de.
@                        IN NS      ns1.first-ns.de.
 
@                        IN A       78.47.100.188
localhost                IN A       127.0.0.1
mail                     IN A       88.198.101.30
www                      IN A       78.47.100.188
@                        IN AAAA    2a01:4f8:d15:2609::3
mail                     IN AAAA    2a01:4f8:221:3744::1:30
imap                     IN CNAME   mail
loopback                 IN CNAME   localhost
pop                      IN CNAME   mail
smtp                     IN CNAME   mail
webmail                  IN CNAME   mail
@                        IN MX 10   mail.lastlog.de.
mail                     IN MX 10   mail.lastlog.de.
@                        IN TXT     "v=spf1 mx a ptr ip4:88.198.101.30 ip6:2a01:4f8:221:3744::1:30 ?all"
mail._domainkey          IN TXT     "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeQIgtFVgJCI15VoBAvYEbLSn8wS7VWWC7j6fNp8tkrLsliL2zOJg6OZ/mFMXHLZZBQO3VvpK8ZVX9Pzfx4UKSS4AmIS/ZOFIq7PWdy1F3X1J55p6JYodcBKFPDa9akiJ/bx0ovSUY3bgABYNIlh1HTi9BotKb6r/hATZ7YlpFXwIDAQAB"

```

## DKIM setup

Since we are using `opendkim` to sign outgoing emails you need to set your DNS records properly.

Here is a setup example for two different mailservers, one running the domain `lastlog.de` and the other `status.lastlog.de`:

* `mail._domainkey` for your primary domain (mail._domainkey.lastlog.de for instance), needs to be set to a value found in `/var/lib/dkim/keys/mail.txt`. The file `/var/lib/dkim/keys/mail.txt` is created after the first boot before opendkim is started on the server 'lastlog.de'.
* `mail._domainkey.status` for (mail._domainkey.status.lastlog.de for instance), needs to be set to a value found in `/var/lib/dkim/keys/mail.txt`. The file `/var/lib/dkim/keys/mail.txt` is created after the first boot before opendkim is started on the server 'status.lastlog.de'.

You would require this extra DNS entry in the lastlog.de DNS:

    mail._domainkey.status   TXT 600    "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDUH6OEmpwj2gaLn9xgReLdQGUEomHZZF+7o6dzwUO1gAAPIFdy6VBt44rl8VIjhF3aZY9lPNzHsT1HNLrmIjtW9XXzfCHcfxEqCJ3Oeuioz3skLPSTH+J6729kp4NxkNyml8tvsLARGZKlOUba3mNCdy/RGWJUDpzaAKabFMyDwwIDAQAB"

We do not plan to support a single selector per domain but instead use one common selector for all domains handled per mailserver.

You can check/debug your setup using:

    dig mail._domainkey.lastlog.de TXT
    ...
    mail._domainkey.lastlog.de. 600 IN      TXT     "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDeQIgtFVgJCI15VoBAvYEbLSn8wS7VWWC7j6fNp8tkrLsliL2zOJg6OZ/mFMXHLZZBQO3VvpK8ZVX9Pzfx4UKSS4AmIS/ZOFIq7PWdy1F3X1J55p6JYodcBKFPDa9akiJ/bx0ovSUY3bgABYNIlh1HTi9BotKb6r/hATZ7YlpFXwIDAQAB"
    ...

Warning: Since the commit 3cf29b8f0b3587ae1054621fd33cee6266f17402 on `Thu Sep 27 21:46:10 2018 +0200` we had `config.nixcloud.email.fqdn` as a selector (instead of `mail`) which was wrongly commited and fixed when you see this remark in your local nixcloud-webservices checkout on your mailserver.


## Testing your setup

We tested our mail setup using https://www.mail-tester.com/ which is a really helpful service.

## Creating virtual users

Virtual users are given via the `nixcloud.email.users` option. You can provide a list of attributesets describing a user.

    nixcloud.email.users = [
      { name = "myuser"; domain = "mydomain.tld"; password = "{PLAIN}hello"; }
    ];

This creates a user `myuser@mydomain.tld` with the password `hello`. You should use encrypted passwords.

Passwords are generated using `doveadm`, details are listed at [PasswordSchemes](https://wiki.dovecot.org/Authentication/PasswordSchemes).

    doveadm pw -s SHA512-CRYPT

A valid entry would look like this:

    nixcloud.email.users = [
      { name = "myuser"; domain = "mydomain.tld"; password = {SHA256-CRYPT}$5$mqwiny3zLM2.a4hp$r/nWsyCrgKv31Xx4hQwsktOv4/tHKeqbDE6xvWV7TQ2"; }
    ];

You should create a user that has an alias for postmaster to follow [RFC822](https://www.ietf.org/rfc/rfc822.txt).

## Using catchall

You can set the `catchallFor` option for a user. Provided a list of domains this user will catch all incoming mails on this domain that are not catched by an alias or a user.

    { name = "joshi"; domain = "example.com"; password = "{PLAIN}linuxFTW"; catchallFor = [ "example.com" ]; }

In this example the user joshi will also get mails addressed to anything@example.com.

You should only use each domain for which you want to set up a catchall *once*.

## Quota

You can set a per user quota by using the `quota` option.

    { name = "eris"; domain = "antifa.gmbh"; password = "{PLAIN}discordia"; quota = "10G"; }

This gives eris a quota of 10 Gigabytes. If you just enter a number without a suffix this is the number of bytes.
The following suffixes can be used: `b` for bytes, `k` for kilobytes, `M` for megabytes, `G` for gigabytes and `T` for terrabytes.

## Rspamd

Rspamd is a spam filter that uses rules and machine learning to detect spam. It can be configured with the `services.rspamd` config.

Rspamd will be enabled and configured automatically. If you don't want rspamd you can use the `nixcloud.email.enableRspamd` option.

    nixcloud.email.enableRspamd = false;

## Greylisting

Greylisting prevents spam by first declining your mails requiring other mail servers to resend their emails after about 10 minutes. Most spammers don't do this and therefor greylisting helps protect you against spam.

Greylisting will be enabled automatically. If you don't want greylisting you can use the `nixcloud.email.enableGreylisting` option.

    nixcloud.email.enableGreylisting = false;

## Sieve filter setup

Tested with `sieve-0.2.11.xpi` from https://github.com/thsmi/sieve/releases

Settings are:

    Server Name: mail.lastlog.de
    Port: 4190
    Authentication: Use login from IMAP Account
    User Name: js@lastlog.de
    Secure Connection: True

### Spam sieve filter

We already provide a minimal sieve setup for rspamd, see: 

https://github.com/nixcloud/nixcloud-webservices/blob/3f9b07aecf4cb3ef088e19b9a62868c2bdb02b94/modules/services/email/nixcloud-email.nix#L454

Note: Link might be outdated soon, but the concept will be the same in newer releases.

Note: You can't edit this particular script from the Thuderbird plugin, but instead create additional hooks.

### Example user sieve filter

    require ["fileinto", "reject", "envelope", "mailbox", "reject"];

    if header :contains "List-ID" "NixOS/nixpkgs" {
      fileinto :create "nixpkgs"; 
      stop;
    }

    elsif header :contains "List-ID" "owncloud.github.com" {
      fileinto :create "owncloud"; 
      stop;
    }

    elsif header :contains "From" "info@frogsgorgeous.org" {
      reject "not interested";
      stop;
    }

    elsif header :contains "From" "abuse@actaculinaria.com" {
      reject "not interested";
      stop;
    }

    elsif header :contains "Sender" "root@www1.maemo.org" {
      reject "i don't have interest in futher emails from you. please unsubscribe";
      stop;
    }

    elsif header :contains "X-Hydra-Instance" "https://hydra.nixos.org" {
      fileinto :create "hydra-nixos"; 
      stop;
    }

    elsif header :contains "List-ID" "hillhackers.lists.hillhacks.in" {
      fileinto :create "hillhackers"; 
      stop;
    }
    
Note: You don't need to handle spam in your own sieve filter as it is done in the abstraction already.

Sieve is great, start using it!

## ACME Let's Encrypt

When using `nixcloud.email.enableTLS = true;`, which is a default we automatically acquires a let's encrypt TLS certificate for your mail server.

This is implemented by starting `nixcloud.reverse-proxy`  on port 80.

See [nixcloud.reverse-proxy.md](nixcloud.reverse-proxy.md) if you need to connect legacy webservices based on `services.nginx` or `services.httpd` and [nixcloud.webservices.md](nixcloud.webservices.md) if you want to use the nixcloud-webservices infrastructure.

## Configuring TLS using nixcloud.TLS

This section helps you to configure which TLS certificates are used. If you have `nixcloud.email.enableTLS = true;` (which is the default) then `nixcloud.TLS` is used (with ACME as a default).

Say you want to use a selfsigned certificate instead, then:

Assuming your `fqdn` is set as in the example to "mail.lastlog.de" then you can simply add this to configuration.nix

    nixcloud.TLS.certs = {
      "mail.lastlog.de" = {
        mode = "selfsigned";
      };
    };

If you already have your own certificates and you want to use them instead of ACME or selfsigned ones, then read the documentation [nixcloud.TLS.md](nixcloud.TLS.md) for more information.

### nixcloud.email and SNI

**nixcloud.email** supports SNI. SNI helps to use TLS from one IPv4/IPv6 address but still host several different domains as *dune2.de*, *lastlog.de* and *mail.nixcloud.io*. 

The TLS certificate, served by *nixcloud.TLS* and used by *postfix* and *dovecot2* uses *Subject Alternative Name*:

            X509v3 Subject Alternative Name:                
                DNS:mail.dune2.de, DNS:mail.lastlog.de, DNS:mail.nixcloud.io

Our default is to use the `mail.`-prefix for all domains the mailserver handles. Therefore each of the 3 domains must point to the same IPv4/IPv6 address where the `nixcloud.reverse-proxy` listens and then hands over ACME challanges to *lego*, our ACME client used in *nixcloud.TLS*.

In general you don't have to write any **nixcloud.TLS** configuration as **nixcloud.email** takes care of that for you. Just make sure that the DNS records are all correct and see the logs of the lego process which fetches the certificates using ACME.

## IMAP setup (thunderbird)

Since `nixcloud.email` support SNI, your users only need to prepend 'mail.' to their domain to get to the mailserver in charge.

### For js@lastlog.de

Incoming email:

    Server Name: mail.lastlog.de
    Port: 143
    User Name: js@lastlog.de

    Security Settings:
    Connection security: STARTTLS
    Authentication method: Normal password

Outgoing email:

    Server Name: mail.lastlog.de
    Port: 587
    User Name: js@lastlog.de
    Authentication method: Normal password
    Connection security: STARTTLS

### For js@dune2.de

Incoming email:

    Server Name: mail.dune2.de
    Port: 143
    User Name: js@dune2.de

    Security Settings:
    Connection security: STARTTLS
    Authentication method: Normal password

Outgoing email:

    Server Name: mail.dune2.de
    Port: 587
    User Name: js@dune2.de
    Authentication method: Normal password
    Connection security: STARTTLS

# Relay setup

`nixcloud.email` provides simple options to configure your mailserver as a relay client which is basically the same as a ssmtp setup but with a mail queue.

If the other mailserver is a mailserver with the default nixcloud email setup you
only need to provide `nixcloud.email.relay.host` and `nixcloud.email.relay.passwords`.

    nixcloud.email.relay = {
      host = "mail.myrelayhost.tld";
      port = 587;
      passwords = {
        "relayUser" = "this1sApla!ntextP4ssw0rd";
      };
    };

The Port 587 is the default port and can therefor be omitted. We strongly suggest
to use the submission port (587) to deliver your emails. The `nixcloud.email.relay.host`
is the host of your relay server.

If you use an open relay you can omit the `nixcloud.email.relay.passwords` option
but we highly suggest you to not use open relays. If your counterpart is a
`nixcloud.email` setup or any other sane mailserver setup that does not use
open relays you need to provide a set of passwords.

Usually one password will be sufficient but you can provide more than one.
In the `nixcloud.email.relay.passwords.<name>` option the name is the user name
and the provided value is the plaintext password.

# Migration

A simple, yet fast strategy is 'rsync+ssh' which is explained here. But you can always just use an IMAP client and copy the mails from your old account as well.

## Copy emails from previous .maildir using rsync (fast)

1. create the email user: js@lastlog.de in the abstraction and run `nixos-rebuild switch`

2. `rsync .maildir/* /var/lib/virtualMail/lastlog.de/users/js/mail/`

3. `chown virtualMail:virtualMail /var/lib/virtualMail/lastlog.de/users/js/mail -r`

# Backups

You should take care of these files:

* /etc/nixos/configuration.nix
* revision of `nixpkgs` and `nixcloud-webservices` you were using
* your DNS configuration

all files from:

* /var/lib/dkim/keys/
* /var/lib/virtualMail/
* /var/lib/nixcloud/TLS/

# Developing/Testing

When you change the `nixcloud.email` abstraction you can run our tests manually by:

    cd tests
    nix-build -A email

Keep in mind, when you run `nixos-rebuild switch` this test is also executed implicitly.

# Links

* [https://github.com/NixOS/nixpkgs/pull/29366](https://github.com/NixOS/nixpkgs/pull/29366)
* [https://github.com/r-raymond/nixos-mailserver/issues/13](https://github.com/r-raymond/nixos-mailserver/issues/13)
* [https://github.com/NixOS/nixpkgs/pull/29365](https://github.com/NixOS/nixpkgs/pull/29365)

# Alternative implementations

* https://gitlab.com/simple-nixos-mailserver/nixos-mailserver
