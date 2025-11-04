{
     strategy.matrix = {
       go-version = [ "stable" "oldstable" ];
       os = [ "ubuntu-latest" "macos-latest" "windows-latest" ];
     };
     runs-on = "\${{ matrix.os }}";
     steps = [
       {
         uses = "actions/setup-go@v4";
         "with".go-version = "\${{ matrix.go-version }}";
       }
       { uses = "actions/checkout@v3"; }
       { run = "go test -race ./..."; }
     ];
   }
