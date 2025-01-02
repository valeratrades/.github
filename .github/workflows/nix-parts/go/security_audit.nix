{...}: {
     runs-on = "ubuntu-latest";
     steps = [
       {
         uses = "golang/govulncheck-action@v1";
         "with" = {
           go-version-input = "stable";
           check-latest = true;
         };
       }
     ];
   }
