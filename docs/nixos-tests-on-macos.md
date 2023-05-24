# NixOS tests on macOS
@author Tobias Bergqvist

This guide goes through how to run NixOS tests on macOS without needing to resort to nested virtualization (which causes a fallback to emulation which is 20x slower)

Made possible by:

- https://github.com/NixOS/nixpkgs/pull/193336 - **Run `nixosTests` on darwin** (draft/unmerged as of 2023-05-12)

---

1. Ensure that your `/etc/nix/nix.conf` (local M1/M2 macbook) contains the following:
    
    ```toml
    # Needed for the darwin linux builder (aarch64-linux)
    build-users-group = nixbld
    extra-trusted-users = <REPLACE_WITH_YOUR_MACOS_USERNAME>
    builders = ssh-ng://builder@localhost aarch64-linux /etc/nix/builder_ed25519 10 - - - c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=
    builders-use-substitutes = true
    
    # Needed for NixOS tests
    extra-system-features = hvf
    ```
    
2. After modifying the config, you need to restart the nix daemon:
    
    ```bash
    sudo launchctl kickstart -k system/org.nixos.nix-daemon
    ```
    

1. Start a Linux-builder on darwin, so that you can build the packages for your guest system. Note that the directory you start the builder in is relevant, as the disk image will be dumped here. Keep this process running in a separate terminal in the bakground
    
    ```bash
    # Start darwin builder with 8GB of RAM
    QEMU_OPTS="-m 8192" nix-shell -p darwin.builder --run "create-builder"
    ```
    

1. Write the following super-simple example to a file named `test.nix`:
    
    ```nix
    { pkgsHost ? import (fetchTarball {
        url = "https://github.com/hercules-ci/nixpkgs/archive/e39a5efc4504099194032dfabdf60a0c4c78f181.tar.gz";
        sha256 = "1qf76qpf82889q1kfjmgjm5i7wasd4w7z77gw377x4x4jkk8fbda";
      }) {}
    , pkgsGuest ? import (fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/b68bd2ee52051aaf983a268494cb4fc6c485b646.tar.gz";
        sha256 = "0q0kkrccrx99l0v1lvqz2kvq1p0xq4szciqrvmanjw1yk30m6i47";
      }) { system = "${builtins.head (builtins.split "-" builtins.currentSystem)}-linux"; }
    }:
    pkgsHost.nixosTest {
      name = "my-nixos-test";
      nodes.my_node.nixpkgs.pkgs = pkgsGuest;
      nodes.my_node.virtualisation.host.pkgs = pkgsHost;
      testScript = ''
        my_node.start()
        my_node.wait_for_unit('network.target') 
      '';
    }
    ```
    
2. Run the test:
    
    ```bash
    nix-build test.nix
    ```
    
    *Note that this test should be runnable using the following architectures: x86_64-linux, aarch64-linux, aarch64-darwin (and possibly x86_64-darwin).*
    

1. (Optional) More complex example with webserver/compilation/systemd:
    
    ```nix
    { pkgsHost ? import (fetchTarball {
        url = "https://github.com/hercules-ci/nixpkgs/archive/e39a5efc4504099194032dfabdf60a0c4c78f181.tar.gz";
        sha256 = "1qf76qpf82889q1kfjmgjm5i7wasd4w7z77gw377x4x4jkk8fbda";
      }) {}
    , pkgsGuest ? import (fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/b68bd2ee52051aaf983a268494cb4fc6c485b646.tar.gz";
        sha256 = "0q0kkrccrx99l0v1lvqz2kvq1p0xq4szciqrvmanjw1yk30m6i47";
      }) { system = "${builtins.head (builtins.split "-" builtins.currentSystem)}-linux"; }
    }:
    let
      webserver = pkgsGuest.runCommandCC "webserver" {} ''
        mkdir -p $out/bin
        cc -o $out/bin/webserver -Wall -Wextra ${
          pkgsGuest.writeText "server.c" ''
            #include <stdio.h>
            #include <stdlib.h>
            #include <unistd.h>
            #include <arpa/inet.h>
            #define assert_ok(e) ({int x = (e); if (x < 0) { printf("%s:%d: ", __FILE__, __LINE__); fflush(stdout); perror(#e); abort(); } x;})
    
            int main() {
              char *host = "127.0.0.1";
              uint16_t port = 8000;
              int reuseaddr = 1;
              int listen_backlog = 10;
              struct sockaddr_in server_address = {
                .sin_port = htons(port),
                .sin_addr.s_addr = inet_addr(host),
                .sin_family = AF_INET
              };
              int sock = assert_ok(socket(AF_INET, SOCK_STREAM, IPPROTO_IP));
              assert_ok(setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuseaddr, sizeof reuseaddr));
              assert_ok(bind(sock, (struct sockaddr*)&server_address, sizeof server_address));
              assert_ok(listen(sock, listen_backlog));
              printf("Listening on http://%s:%hu\n", host, port);
              while (1) {
                  int accepted_sock = accept(sock, NULL, NULL);
                  write(accepted_sock, "HTTP/1.1 200 OK\nContent-Length: 26\n\n{\"message\":\"Hello world\"}\n", 62);
                  close(accepted_sock);
              }
            }
          ''
        }
      '';
    in
    pkgsHost.nixosTest {
      name = "my-nixos-test";
      nodes.my_node.nixpkgs.pkgs = pkgsGuest;
      nodes.my_node.virtualisation.host.pkgs = pkgsHost;
      nodes.my_node.systemd.services.hello-world = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        description = "Simple web server written in C";
        serviceConfig.ExecStart = "${webserver}/bin/webserver";
      };
      testScript = ''
        import json
        my_node.start()
        my_node.wait_for_open_port(8000)
        response = json.loads(my_node.succeed("${pkgsGuest.curl}/bin/curl http://127.0.0.1:8000"))
        assert response == {"message": "Hello world"}
      '';
    }
    ```