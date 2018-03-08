{
  name = "static-darkhttpd";

  machine.imports = [ ../../../../tests/common/eatmydata.nix ];
  machine.nixcloud.reverse-proxy.enable = true;
  machine.nixcloud.reverse-proxy.extendEtcHosts = true;
  machine.nixcloud.webservices.static-darkhttpd = {
    foo.enable = true;
    foo.proxyOptions.TLS = "none";
    foo.proxyOptions.domain = "example.com";
    foo.proxyOptions.http.mode = "on";
    foo.proxyOptions.https.mode = "off";
    foo.proxyOptions.port = 8080;

    bar.enable = true;
    bar.proxyOptions.TLS = "none";
    bar.proxyOptions.domain = "example.org";
    bar.proxyOptions.http.mode = "on";
    bar.proxyOptions.https.mode = "off";
    bar.proxyOptions.port = 8081;
  };

  testScript = let
    searchFor = "works";
  in ''
    $machine->waitForUnit('multi-user.target');
    $machine->waitForOpenPort(80);
    $machine->succeed('echo "works" > /var/lib/nixcloud/webservices/static-darkhttpd-foo/index.html');
    $machine->succeed('echo "works" > /var/lib/nixcloud/webservices/static-darkhttpd-bar/index.html');
    $machine->succeed('curl -L http://example.com/index.html | grep -qF "${searchFor}"');
    $machine->succeed('curl -L http://example.org/index.html | grep -qF "${searchFor}"');
  '';
}
