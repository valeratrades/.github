# Generate install steps for jobs that depend on load_nix workflow
# These steps restore the nix cache populated by load_nix
# Also supports legacy apt (deprecated)
# packages: list of nixpkgs attribute name strings
{ packages ? [], apt ? [], linuxOnly ? true, debug ? false }:
let
  # Always include openssl.out (runtime libs) and openssl.dev (headers)
  # because "openssl" alone resolves to openssl-bin which has no libraries
  allPackages = packages ++ [ "openssl.out" "openssl.dev" ];

  pkgList = builtins.concatStringsSep " " allPackages;

  # Build debug script that prints extensive environment info
  debugScript = ''
    echo "=== NIX ENVIRONMENT DEBUG ==="
    echo ""
    echo "1. Which nix:"
    which nix || echo "nix not found in PATH"
    echo ""
    echo "2. Nix version:"
    nix --version || echo "failed"
    echo ""
    echo "3. Current PATH:"
    echo "$PATH" | tr ':' '\n'
    echo ""
    echo "4. LD_LIBRARY_PATH (before nix-shell):"
    echo "$LD_LIBRARY_PATH"
    echo ""
    echo "5. NIX_PROFILES:"
    echo "$NIX_PROFILES"
    echo ""
    echo "6. Package store paths:"
    ${builtins.concatStringsSep "\n" (map (pkg: ''
    echo "  ${pkg}: $(nix-build '<nixpkgs>' -A ${pkg} --no-out-link 2>/dev/null || echo 'FAILED')"
    '') allPackages)}
    echo ""
    echo "7. libssl.so locations in nix store:"
    find /nix/store -name 'libssl.so*' 2>/dev/null | head -20 || echo "none found"
    echo ""
    echo "8. libgbm.so locations in nix store:"
    find /nix/store -name 'libgbm.so*' 2>/dev/null | head -20 || echo "none found"
    echo ""
    echo "9. Contents of openssl lib dir:"
    ls -la "$(nix-build '<nixpkgs>' -A openssl --no-out-link)/lib/" 2>/dev/null || echo "failed"
    echo ""
    echo "10. Contents of openssl.dev lib dir:"
    ls -la "$(nix-build '<nixpkgs>' -A openssl.dev --no-out-link)/lib/" 2>/dev/null || echo "failed"
    echo ""
    echo "11. ldd on a test binary (if exists):"
    if [ -f target/debug/todo ]; then
      ldd target/debug/todo 2>&1 || echo "ldd failed"
    else
      echo "binary not built yet"
    fi
    echo ""
    echo "12. System LD_LIBRARY_PATH search dirs:"
    cat /etc/ld.so.conf 2>/dev/null || echo "no ld.so.conf"
    ldconfig -p 2>/dev/null | grep -E "libssl|libgbm" | head -10 || echo "ldconfig failed or no matches"
    echo ""
    echo "13. Test nix-shell environment:"
    nix-shell -p ${pkgList} --run 'echo "Inside nix-shell LD_LIBRARY_PATH: $LD_LIBRARY_PATH"'
    echo ""
    echo "14. Test nix-shell with manual LD_LIBRARY_PATH:"
    nix-shell -p ${pkgList} --command 'export LD_LIBRARY_PATH="$(nix-build "<nixpkgs>" -A openssl --no-out-link)/lib''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH" && echo "Manual LD_LIBRARY_PATH: $LD_LIBRARY_PATH"'
    echo ""
    echo "15. Check if openssl lib has libssl.so.3:"
    OPENSSL_PATH=$(nix-build '<nixpkgs>' -A openssl --no-out-link 2>/dev/null)
    if [ -n "$OPENSSL_PATH" ]; then
      ls -la "$OPENSSL_PATH/lib/" | grep ssl || echo "no ssl libs in openssl"
    fi
    echo ""
    echo "16. Check openssl.out (runtime output):"
    nix-build '<nixpkgs>' -A openssl.out --no-out-link 2>/dev/null && ls -la "$(nix-build '<nixpkgs>' -A openssl.out --no-out-link)/lib/" | grep ssl || echo "openssl.out failed"
    echo ""
    echo "17. Env vars in nix-shell:"
    nix-shell -p openssl --run 'env | grep -E "^(LD_|NIX_|PATH=)" | sort'
    echo ""
    echo "18. Test subprocess inheritance:"
    nix-shell -p ${pkgList} --command 'export LD_LIBRARY_PATH="$(nix-build "<nixpkgs>" -A openssl --no-out-link)/lib:$LD_LIBRARY_PATH" && bash -c "echo subprocess sees: \$LD_LIBRARY_PATH"'
    echo ""
    echo "19. All openssl-related packages:"
    nix-env -qaP 'openssl.*' 2>/dev/null | head -20 || echo "query failed"
    echo ""
    echo "20. System libssl:"
    ldconfig -p 2>/dev/null | grep libssl || echo "no system libssl"
    echo ""
    echo "=== END DEBUG ==="
  '';

  # Nix restore steps - restore from cache, then make packages available
  nixSteps = if packages != [] then [
    {
      name = "Install Nix";
      uses = "DeterminateSystems/nix-installer-action@main";
    }
    {
      name = "Restore Nix cache";
      uses = "DeterminateSystems/magic-nix-cache-action@main";
    }
  ] ++ (if debug then [{
    name = "Debug nix environment";
    run = debugScript;
  }] else [])
  else [];

  #DEPRECATE: apt-based installation
  _ = if apt != [] then builtins.trace "WARNING: install.apt is deprecated, use install.packages instead" null else null;
  baseAptStep = {
    name = "Install dependencies (apt)";
    run = ''
      sudo apt-get update
      sudo apt-get install -y ${builtins.concatStringsSep " " apt}
    '';
  };
  aptSteps = if apt != [] then [
    (if linuxOnly then baseAptStep // { "if" = "runner.os == 'Linux'"; } else baseAptStep)
  ] else [];
in
nixSteps ++ aptSteps
