{...}: {
     runs-on = "ubuntu-latest";
     steps = [
       { uses = "actions/setup-go@v4"; }
       { uses = "actions/checkout@v3"; }
       {
         run = ''
           go install github.com/go-critic/go-critic/cmd/gocritic@latest
           gocritic check .
         '';
       }
     ];
   }
