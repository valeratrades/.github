{ pkgs, entries }:
let
  excalidrawAppHtml = ./excalidraw-app.html;
  excalidrawServerScript = ./excalidraw-server.rs;
  exToMdScript = ./ex-to-md.rs;

  mdToExScript = pkgs.writeText "md-to-ex.mjs" ''
    import { readFileSync, writeFileSync } from 'fs';
    import { join } from 'path';
    import { JSDOM } from 'jsdom';

    const dom = new JSDOM('<!DOCTYPE html><html><body></body></html>');
    global.window   = dom.window;
    global.document = dom.window.document;
    global.DOMParser = dom.window.DOMParser;
    Object.defineProperty(global, 'navigator', { value: dom.window.navigator, writable: true, configurable: true });
    if (dom.window.SVGElement) {
      dom.window.SVGElement.prototype.getBBox = function() {
        return { x: 0, y: 0, width: 100, height: 50 };
      };
    }

    const { parseMermaidToExcalidraw } = await import('@excalidraw/mermaid-to-excalidraw');

    const excalidrawPath = process.argv[2];
    if (!excalidrawPath) {
      console.error('Usage: md-to-ex.mjs <path.excalidraw>');
      process.exit(1);
    }

    const inlineFpath = process.env.EX_INLINE_FPATH || "";
    const inlineNum = parseInt(process.env.EX_INLINE_NUM || "0", 10);

    let mermaidSrc;
    if (inlineFpath) {
      const src = readFileSync(inlineFpath, 'utf8');
      const re = /```mermaid\n([\s\S]*?)```/g;
      let match;
      let i = 0;
      while ((match = re.exec(src)) !== null) {
        i++;
        if (i === inlineNum) {
          mermaidSrc = match[1].trim();
          break;
        }
      }
      if (!mermaidSrc) {
        console.error('Mermaid block #' + inlineNum + ' not found in ' + inlineFpath + ' (found ' + i + ' blocks). Place the block first.');
        process.exit(1);
      }
    } else {
      const mdPath = excalidrawPath.replace(/\.excalidraw$/, '.md');
      const src = readFileSync(mdPath, 'utf8');
      const match = src.match(/```mermaid\n([\s\S]*?)```/);
      if (!match) {
        console.error('No mermaid code block found in ' + mdPath);
        process.exit(1);
      }
      mermaidSrc = match[1].trim();
    }

    console.log('Parsing mermaid...');

    const result = await parseMermaidToExcalidraw(mermaidSrc);

    const excalidraw = {
      type: 'excalidraw',
      version: 2,
      source: 'mermaid-to-excalidraw',
      elements: result.elements || [],
      appState: {
        gridSize: null,
        gridStep: 5,
        viewBackgroundColor: '#ffffff'
      },
      files: result.files || {}
    };

    writeFileSync(excalidrawPath, JSON.stringify(excalidraw, null, 2));
    console.log('Written: ' + excalidrawPath);
  '';

  npmCacheSetup = ''
    _ex_npm_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/excalidraw-tools"
    if [ ! -d "$_ex_npm_cache/node_modules/@excalidraw" ]; then
      echo "excalidraw tools: installing npm deps..."
      mkdir -p "$_ex_npm_cache"
      cat > "$_ex_npm_cache/package.json" << 'EXEOF'
    {"name":"excalidraw-tools","version":"1.0.0","type":"module","private":true,"dependencies":{"@excalidraw/mermaid-to-excalidraw":"*","jsdom":"*"}}
    EXEOF
      ${pkgs.nodejs}/bin/npm install --prefix "$_ex_npm_cache" 2>&1 | tail -3
    fi
  '';

  # Generate the loop body for ex-to-md / md-to-ex across all configured entries.
  # Each entry: key = relative path to .excalidraw, value = { standalone = true; } or { inline = { fpath, num }; }
  entryNames = builtins.attrNames entries;

  mkExToMdInvocation = relPath:
    let
      cfg = entries.${relPath};
      isInline = cfg ? inline;
      inlineEnv = if isInline then ''
        export EX_INLINE_FPATH="$_ex_root/${cfg.inline.fpath}"
        export EX_INLINE_NUM="${toString cfg.inline.num}"
      '' else ''
        unset EX_INLINE_FPATH EX_INLINE_NUM 2>/dev/null || true
      '';
    in ''
      ${inlineEnv}
      cargo -Zscript -q ${exToMdScript} "$_ex_root/${relPath}"
    '';

  mkMdToExInvocation = relPath:
    let
      cfg = entries.${relPath};
      isInline = cfg ? inline;
      inlineEnv = if isInline then ''
        export EX_INLINE_FPATH="$_ex_root/${cfg.inline.fpath}"
        export EX_INLINE_NUM="${toString cfg.inline.num}"
      '' else ''
        unset EX_INLINE_FPATH EX_INLINE_NUM 2>/dev/null || true
      '';
    in ''
      ${inlineEnv}
      ${pkgs.nodejs}/bin/node "$_ex_cache/md-to-ex.mjs" "$_ex_root/${relPath}"
    '';

  exCmd = pkgs.writeShellScriptBin "ex" ''
    set -euo pipefail
    export EX_HTML_PATH="${excalidrawAppHtml}"
    exec cargo -Zscript -q ${excalidrawServerScript} "$@"
  '';

  exToMdCmd = pkgs.writeShellScriptBin "ex-to-md" ''
    set -euo pipefail
    _ex_root="$(git rev-parse --show-toplevel)"
    ${builtins.concatStringsSep "\n" (map mkExToMdInvocation entryNames)}
  '';

  mdToExCmd = pkgs.writeShellScriptBin "md-to-ex" ''
    set -euo pipefail
    _ex_root="$(git rev-parse --show-toplevel)"
    _ex_cache="''${XDG_CACHE_HOME:-$HOME/.cache}/excalidraw-tools"
    rm -f "$_ex_cache/md-to-ex.mjs"
    cp ${mdToExScript} "$_ex_cache/md-to-ex.mjs"
    ${builtins.concatStringsSep "\n" (map mkMdToExInvocation entryNames)}
  '';
in
{
  shellHook = npmCacheSetup;
  enabledPackages = [ pkgs.nodejs exCmd exToMdCmd mdToExCmd ];
}
